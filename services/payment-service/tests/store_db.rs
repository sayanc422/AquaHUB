//! The store against a real Postgres.
//!
//! These are the tests Phase 4 shipped without, and they cover exactly what a
//! unit test cannot reach: the CHECK constraints, the append-only trigger, and
//! the conditional update that decides which of two racing resolvers writes.
//! Every one of those lives in the database, and a mock that returns what the
//! test expects would prove the mock.
//!
//! They skip when `PAYMENTS_TEST_DSN` is unset, so `cargo test` still works on a
//! machine with no database — the same trade `order-service` makes, with the
//! same cost: a missing variable means silent skipping rather than a loud
//! failure.
//!
//! ```bash
//! createdb payments_test
//! PAYMENTS_TEST_DSN='postgres://postgres@127.0.0.1:5432/payments_test' cargo test
//! ```
//!
//! Each test works under its own idempotency keys, so the file can run against
//! one database without truncation between tests.

use payment_service::ledger::{Event, Payment, PaymentState};
use payment_service::money::{Currency, Money};
use payment_service::store::{Store, StoreError};
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use uuid::Uuid;

async fn pool() -> Option<PgPool> {
    let dsn = std::env::var("PAYMENTS_TEST_DSN").ok()?;
    let pool = PgPoolOptions::new()
        .max_connections(4)
        .connect(&dsn)
        .await
        .expect("connect to PAYMENTS_TEST_DSN");
    payment_service::store::MIGRATOR
        .run(&pool)
        .await
        .expect("migrations");
    Some(pool)
}

/// Every test begins with this. Returning early rather than failing is the
/// deliberate compromise described at the top of the file.
macro_rules! store_or_skip {
    () => {
        match pool().await {
            Some(p) => Store::new(p),
            None => {
                eprintln!("PAYMENTS_TEST_DSN is not set; skipping database tests");
                return;
            }
        }
    };
}

fn inr(n: i64) -> Money {
    Money::new(n, Currency::INR).unwrap()
}

fn key(name: &str) -> String {
    format!("{name}-{}", Uuid::new_v4())
}

// ------------------------------------------------------------ the intent

#[tokio::test]
async fn the_intent_is_written_before_anything_else_happens() {
    let store = store_or_skip!();
    let k = key("intent");

    let (stored, created) = store
        .begin_payment(&k, "AQ-INTENT", inr(50_000))
        .await
        .expect("begin");

    assert!(
        created,
        "the first call must report that it created the row"
    );
    assert_eq!(stored.payment.state, PaymentState::Pending);
    // A pending payment holds nothing. Every downstream decision reads this.
    assert_eq!(stored.payment.balance, inr(0));
    assert!(!stored.payment.state.holds_money());

    // Entry 1 is the intent itself -- written before the acquirer is called, so
    // a crash during the call still leaves the charge findable.
    let ledger = store.ledger(stored.id).await.expect("ledger");
    assert_eq!(ledger.len(), 1);
    assert_eq!(ledger[0].kind, "authorise");
    assert_eq!(ledger[0].amount_minor, 50_000);
    assert_eq!(ledger[0].balance_after, 0);
}

#[tokio::test]
async fn the_same_key_returns_the_same_payment_and_writes_nothing_new() {
    let store = store_or_skip!();
    let k = key("replay");

    let (first, created) = store.begin_payment(&k, "AQ-R", inr(1_000)).await.unwrap();
    assert!(created);
    let (second, created_again) = store.begin_payment(&k, "AQ-R", inr(1_000)).await.unwrap();

    assert!(!created_again, "a replay must not report as a creation");
    assert_eq!(first.id, second.id);
    // One intent entry, not two: the replay wrote nothing.
    assert_eq!(store.ledger(first.id).await.unwrap().len(), 1);
}

#[tokio::test]
async fn a_key_reused_for_a_different_amount_is_refused() {
    let store = store_or_skip!();
    let k = key("conflict");

    store.begin_payment(&k, "AQ-C", inr(1_000)).await.unwrap();
    let err = store
        .begin_payment(&k, "AQ-C", inr(2_000))
        .await
        .expect_err("a different amount under the same key must be refused");

    assert!(matches!(err, StoreError::IdempotencyConflict));
}

#[tokio::test]
async fn a_key_reused_for_a_different_order_is_refused() {
    let store = store_or_skip!();
    let k = key("conflict-order");

    store.begin_payment(&k, "AQ-ONE", inr(1_000)).await.unwrap();
    let err = store
        .begin_payment(&k, "AQ-TWO", inr(1_000))
        .await
        .expect_err("a different order under the same key must be refused");

    assert!(matches!(err, StoreError::IdempotencyConflict));
}

// ------------------------------------------------------- state and ledger

#[tokio::test]
async fn a_capture_moves_the_balance_and_appends_an_entry() {
    let store = store_or_skip!();
    let k = key("capture");
    let (stored, _) = store.begin_payment(&k, "AQ-CAP", inr(7_500)).await.unwrap();

    let transition = stored
        .payment
        .apply(Event::AcquirerCaptured { amount: inr(7_500) })
        .unwrap();
    let wrote = store
        .apply(
            stored.id,
            PaymentState::Pending,
            transition,
            Some("acq_test_0000000000"),
            "acquirer captured",
        )
        .await
        .unwrap();
    assert!(wrote);

    let after = store.get(stored.id).await.unwrap();
    assert_eq!(after.payment.state, PaymentState::Captured);
    assert_eq!(after.payment.balance, inr(7_500));
    assert!(after.payment.state.holds_money());
    assert_eq!(after.acquirer_ref.as_deref(), Some("acq_test_0000000000"));

    let ledger = store.ledger(stored.id).await.unwrap();
    assert_eq!(ledger.len(), 2);
    assert_eq!(ledger[1].kind, "capture");
    assert_eq!(ledger[1].balance_after, 7_500);
}

/// The race this design turns on. The caller retrying after a 504 and the
/// reconciler on its timer will both try to resolve the same pending payment;
/// the conditional update means the loser writes nothing rather than appending
/// a second capture for one charge.
#[tokio::test]
async fn only_one_of_two_racing_resolvers_writes() {
    let store = store_or_skip!();
    let k = key("race");
    let (stored, _) = store
        .begin_payment(&k, "AQ-RACE", inr(4_000))
        .await
        .unwrap();

    let transition = stored
        .payment
        .apply(Event::AcquirerCaptured { amount: inr(4_000) })
        .unwrap();

    let first = store
        .apply(
            stored.id,
            PaymentState::Pending,
            transition,
            None,
            "resolver A",
        )
        .await
        .unwrap();
    // The second still believes the payment is pending -- exactly what a
    // concurrent resolver holds in memory.
    let second = store
        .apply(
            stored.id,
            PaymentState::Pending,
            transition,
            None,
            "resolver B",
        )
        .await
        .unwrap();

    assert!(first, "the first resolver should have written");
    assert!(!second, "the second must write nothing");

    // One capture, not two. This is the assertion that matters: a second entry
    // here would be a second charge in the ledger for one charge at the bank.
    let ledger = store.ledger(stored.id).await.unwrap();
    assert_eq!(ledger.len(), 2, "ledger: {ledger:?}");
    assert_eq!(ledger[1].detail.as_deref(), Some("resolver A"));
}

#[tokio::test]
async fn refunds_accumulate_in_the_ledger_and_close_the_payment() {
    let store = store_or_skip!();
    let k = key("refund");
    let (stored, _) = store
        .begin_payment(&k, "AQ-REF", inr(10_000))
        .await
        .unwrap();

    let captured = capture(&store, &stored.id, inr(10_000)).await;

    let first = captured
        .apply(Event::Refund { amount: inr(4_000) })
        .unwrap();
    assert!(store
        .apply_refund(
            stored.id,
            PaymentState::Captured,
            first,
            &key("r1"),
            "partial"
        )
        .await
        .unwrap());

    let mid = store.get(stored.id).await.unwrap();
    assert_eq!(mid.payment.state, PaymentState::PartiallyRefunded);
    assert_eq!(mid.payment.balance, inr(6_000));

    let second = mid
        .payment
        .apply(Event::Refund { amount: inr(6_000) })
        .unwrap();
    assert!(store
        .apply_refund(
            stored.id,
            PaymentState::PartiallyRefunded,
            second,
            &key("r2"),
            "the rest"
        )
        .await
        .unwrap());

    let end = store.get(stored.id).await.unwrap();
    assert_eq!(end.payment.state, PaymentState::Refunded);
    assert_eq!(end.payment.balance, inr(0));
    assert!(!end.payment.state.holds_money());

    let ledger = store.ledger(stored.id).await.unwrap();
    assert_eq!(ledger.len(), 4);
    assert_eq!(ledger[3].balance_after, 0);
}

#[tokio::test]
async fn a_refund_key_is_remembered_so_a_retry_can_be_recognised() {
    let store = store_or_skip!();
    let k = key("refund-key");
    let (stored, _) = store.begin_payment(&k, "AQ-RK", inr(2_000)).await.unwrap();
    let captured = capture(&store, &stored.id, inr(2_000)).await;

    let refund_key = key("rk");
    assert_eq!(store.find_refund(&refund_key).await.unwrap(), None);

    let transition = captured.apply(Event::Refund { amount: inr(500) }).unwrap();
    store
        .apply_refund(
            stored.id,
            PaymentState::Captured,
            transition,
            &refund_key,
            "dead on arrival",
        )
        .await
        .unwrap();

    assert_eq!(
        store.find_refund(&refund_key).await.unwrap(),
        Some(stored.id),
        "a retried refund must be recognisable, or it pays out twice"
    );
}

// --------------------------------------------- what the database refuses

/// The ledger is append-only, and that is enforced rather than agreed. A
/// convention everyone follows until somebody writes a data fix is not a
/// guarantee.
#[tokio::test]
async fn the_ledger_refuses_updates_and_deletes() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("append-only");
    let (stored, _) = store.begin_payment(&k, "AQ-AO", inr(1_000)).await.unwrap();

    let update = sqlx::query("UPDATE ledger_entry SET amount_minor = 1 WHERE payment_id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;
    assert!(update.is_err(), "a ledger entry must not be editable");

    let delete = sqlx::query("DELETE FROM ledger_entry WHERE payment_id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;
    assert!(delete.is_err(), "a ledger entry must not be deletable");

    // And the entry is still there.
    assert_eq!(store.ledger(stored.id).await.unwrap().len(), 1);
}

/// `pending` means "we do not know whether the money was taken". A pending row
/// with a balance would make that claim false, and everything downstream reads
/// it.
#[tokio::test]
async fn a_pending_payment_cannot_hold_a_balance() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("pending-balance");
    let (stored, _) = store.begin_payment(&k, "AQ-PB", inr(1_000)).await.unwrap();

    let bad = sqlx::query("UPDATE payment SET balance_minor = 500 WHERE id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;

    assert!(
        bad.is_err(),
        "a pending payment must not be able to hold money"
    );
}

#[tokio::test]
async fn a_balance_can_never_go_negative() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("negative");
    let (stored, _) = store.begin_payment(&k, "AQ-NEG", inr(1_000)).await.unwrap();
    capture(&store, &stored.id, inr(1_000)).await;

    let bad = sqlx::query("UPDATE payment SET balance_minor = -1 WHERE id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;

    assert!(bad.is_err(), "the CHECK must refuse a negative balance");
}

#[tokio::test]
async fn a_settled_payment_cannot_keep_a_balance() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("settled");
    let (stored, _) = store.begin_payment(&k, "AQ-SET", inr(1_000)).await.unwrap();
    capture(&store, &stored.id, inr(1_000)).await;

    // Declared refunded while still holding money: the combination that would
    // make a reconciliation report quietly wrong.
    let bad = sqlx::query("UPDATE payment SET state = 'refunded' WHERE id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;

    assert!(bad.is_err(), "a refunded payment must hold nothing");
}

#[tokio::test]
async fn an_unknown_state_cannot_be_stored() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("badstate");
    let (stored, _) = store.begin_payment(&k, "AQ-BS", inr(1_000)).await.unwrap();

    let bad = sqlx::query("UPDATE payment SET state = 'nearly_paid' WHERE id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await;

    assert!(
        bad.is_err(),
        "the state CHECK and the enum must not drift apart"
    );
}

// ----------------------------------------------------------- reconciler

#[tokio::test]
async fn the_reconciler_sees_only_old_pending_payments() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();

    let fresh = key("fresh");
    store
        .begin_payment(&fresh, "AQ-FRESH", inr(100))
        .await
        .unwrap();

    let old = key("old");
    let (old_payment, _) = store.begin_payment(&old, "AQ-OLD", inr(100)).await.unwrap();
    sqlx::query("UPDATE payment SET created_at = now() - interval '10 minutes' WHERE id = $1")
        .bind(old_payment.id)
        .execute(&pool)
        .await
        .unwrap();

    let due = store.pending_since(60, 100).await.unwrap();
    let ids: Vec<Uuid> = due.iter().map(|p| p.id).collect();

    assert!(
        ids.contains(&old_payment.id),
        "an old pending payment must be picked up"
    );
    // A payment that has only just been attempted is not a problem yet; a
    // reconciler that grabbed it would race the request that created it.
    let fresh_id = store.get_by_key(&fresh).await.unwrap().id;
    assert!(
        !ids.contains(&fresh_id),
        "a fresh pending payment must be left alone"
    );
}

#[tokio::test]
async fn a_resolved_payment_stops_being_pending() {
    let store = store_or_skip!();
    let pool = pool().await.unwrap();
    let k = key("resolve-count");
    let (stored, _) = store.begin_payment(&k, "AQ-RC", inr(100)).await.unwrap();
    sqlx::query("UPDATE payment SET created_at = now() - interval '10 minutes' WHERE id = $1")
        .bind(stored.id)
        .execute(&pool)
        .await
        .unwrap();

    assert!(store
        .pending_since(60, 100)
        .await
        .unwrap()
        .iter()
        .any(|p| p.id == stored.id));

    capture(&store, &stored.id, inr(100)).await;

    assert!(
        !store
            .pending_since(60, 100)
            .await
            .unwrap()
            .iter()
            .any(|p| p.id == stored.id),
        "a resolved payment must leave the reconciler's queue"
    );
}

#[tokio::test]
async fn an_unknown_payment_is_not_found_rather_than_invented() {
    let store = store_or_skip!();
    assert!(matches!(
        store.get(Uuid::new_v4()).await,
        Err(StoreError::NotFound)
    ));
    assert!(matches!(
        store.get_by_key("a-key-nobody-used").await,
        Err(StoreError::NotFound)
    ));
}

#[tokio::test]
async fn the_ledger_of_an_unknown_payment_is_empty_not_an_error() {
    let store = store_or_skip!();
    assert!(store.ledger(Uuid::new_v4()).await.unwrap().is_empty());
}

#[tokio::test]
async fn ping_reaches_the_database() {
    let store = store_or_skip!();
    store.ping().await.expect("ping");
}

// ------------------------------------------------------------- utilities

async fn capture(store: &Store, id: &Uuid, amount: Money) -> Payment {
    let stored = store.get(*id).await.unwrap();
    let transition = stored
        .payment
        .apply(Event::AcquirerCaptured { amount })
        .unwrap();
    store
        .apply(*id, PaymentState::Pending, transition, None, "captured")
        .await
        .unwrap();
    store.get(*id).await.unwrap().payment
}
