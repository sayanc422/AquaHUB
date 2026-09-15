//! Persistence. The only module that writes SQL.
//!
//! Two rules run through all of it:
//!
//!   * **The intent is written before the acquirer is called.** A service that
//!     charges first and records afterwards loses the record of every charge it
//!     dies in the middle of, and there is then nothing to reconcile against.
//!   * **Every state change is one transaction that writes both the payment row
//!     and its ledger entry.** A balance that disagrees with the entries behind
//!     it is unauditable, and the entries are the source of truth.

use crate::ledger::{Payment, PaymentState, Transition};
use crate::money::{Currency, Money};
use chrono::{DateTime, Utc};
use sqlx::{postgres::PgPool, Row};
use uuid::Uuid;

/// The migrations, embedded at compile time so no database is needed to build.
/// Exposed here rather than run from `main` so the tests apply exactly the same
/// schema the service does — a test suite against a hand-written schema proves
/// the hand-written schema.
pub static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("database: {0}")]
    Db(#[from] sqlx::Error),
    #[error("payment not found")]
    NotFound,
    #[error("stored payment {0} is not readable: {1}")]
    Corrupt(Uuid, String),
    #[error("idempotency key reused for a different request")]
    IdempotencyConflict,
}

/// A payment as stored, with the identity the machine does not carry.
#[derive(Debug, Clone)]
pub struct StoredPayment {
    pub id: Uuid,
    pub idempotency_key: String,
    pub order_reference: String,
    pub payment: Payment,
    pub acquirer_ref: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct LedgerRow {
    pub seq: i32,
    pub kind: String,
    pub amount_minor: i64,
    pub balance_after: i64,
    pub detail: Option<String>,
    pub at: DateTime<Utc>,
}

#[derive(Clone)]
pub struct Store {
    pool: PgPool,
}

impl Store {
    pub fn new(pool: PgPool) -> Self {
        Store { pool }
    }

    pub async fn ping(&self) -> Result<(), StoreError> {
        sqlx::query("SELECT 1").execute(&self.pool).await?;
        Ok(())
    }

    /// Write the intent, or hand back the payment this key already made.
    ///
    /// `ON CONFLICT DO UPDATE`, not `DO NOTHING`, for the same reason as in
    /// inventory-service: `DO NOTHING` returns no row when the conflicting
    /// insert is still uncommitted elsewhere, and the follow-up `SELECT` cannot
    /// see it either, so a concurrent retry would look like a lost key.
    /// `DO UPDATE` takes the row lock and waits. `xmax = 0` separates a genuine
    /// insert from a conflict.
    ///
    /// Returns `(payment, true)` when this call created it.
    pub async fn begin_payment(
        &self,
        idempotency_key: &str,
        order_reference: &str,
        amount: Money,
    ) -> Result<(StoredPayment, bool), StoreError> {
        let mut tx = self.pool.begin().await?;

        let row = sqlx::query(
            r#"
            INSERT INTO payment (id, idempotency_key, order_reference, amount_minor, currency, state)
            VALUES ($1, $2, $3, $4, $5, 'pending')
            ON CONFLICT (idempotency_key)
                DO UPDATE SET updated_at = payment.updated_at
            RETURNING id, idempotency_key, order_reference, amount_minor, currency,
                      state, balance_minor, acquirer_ref, created_at, (xmax = 0) AS inserted
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(idempotency_key)
        .bind(order_reference)
        .bind(amount.minor())
        .bind(amount.currency().code())
        .fetch_one(&mut *tx)
        .await?;

        let inserted: bool = row.try_get("inserted")?;
        let stored = stored_from_row(&row)?;

        if !inserted {
            // Same key, different money, is a caller bug worth refusing rather
            // than quietly answering about a different payment.
            if stored.payment.amount != amount || stored.order_reference != order_reference {
                return Err(StoreError::IdempotencyConflict);
            }
            tx.commit().await?;
            return Ok((stored, false));
        }

        // Entry 1 is the intent itself, written before the acquirer is called.
        sqlx::query(
            r#"
            INSERT INTO ledger_entry (payment_id, seq, kind, amount_minor, balance_after, detail)
            VALUES ($1, 1, 'authorise', $2, 0, $3)
            "#,
        )
        .bind(stored.id)
        .bind(amount.minor())
        .bind(format!("intent for order {order_reference}"))
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok((stored, true))
    }

    /// Record the outcome of a transition: the payment row and its entry, in
    /// one transaction.
    ///
    /// The `WHERE state = $current` clause is the concurrency control. Two
    /// resolutions of the same pending payment — an inline one and the
    /// reconciler — can race, and the loser writes nothing rather than
    /// appending a second capture for the same charge.
    pub async fn apply(
        &self,
        id: Uuid,
        from: PaymentState,
        transition: Transition,
        acquirer_ref: Option<&str>,
        detail: &str,
    ) -> Result<bool, StoreError> {
        let mut tx = self.pool.begin().await?;

        let updated = sqlx::query(
            r#"
            UPDATE payment
               SET state = $1, balance_minor = $2, updated_at = now(),
                   acquirer_ref = COALESCE($3, acquirer_ref)
             WHERE id = $4 AND state = $5
            "#,
        )
        .bind(transition.state.as_str())
        .bind(transition.balance.minor())
        .bind(acquirer_ref)
        .bind(id)
        .bind(from.as_str())
        .execute(&mut *tx)
        .await?;

        if updated.rows_affected() == 0 {
            // Somebody else resolved it first. Not an error: the payment has an
            // outcome, which is all the caller needed.
            tx.rollback().await?;
            return Ok(false);
        }

        sqlx::query(
            r#"
            INSERT INTO ledger_entry (payment_id, seq, kind, amount_minor, balance_after, detail)
            SELECT $1, COALESCE(MAX(seq), 0) + 1, $2, $3, $4, $5
              FROM ledger_entry WHERE payment_id = $1
            "#,
        )
        .bind(id)
        .bind(transition.entry.as_str())
        .bind(transition.entry_amount.minor())
        .bind(transition.balance.minor())
        .bind(detail)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(true)
    }

    /// Apply a refund and remember the key that asked for it, in one
    /// transaction. A retried refund finds the key and pays out nothing more.
    pub async fn apply_refund(
        &self,
        id: Uuid,
        from: PaymentState,
        transition: Transition,
        refund_key: &str,
        detail: &str,
    ) -> Result<bool, StoreError> {
        let mut tx = self.pool.begin().await?;

        let updated = sqlx::query(
            r#"
            UPDATE payment SET state = $1, balance_minor = $2, updated_at = now()
             WHERE id = $3 AND state = $4
            "#,
        )
        .bind(transition.state.as_str())
        .bind(transition.balance.minor())
        .bind(id)
        .bind(from.as_str())
        .execute(&mut *tx)
        .await?;

        if updated.rows_affected() == 0 {
            tx.rollback().await?;
            return Ok(false);
        }

        let seq: i32 = sqlx::query(
            r#"
            INSERT INTO ledger_entry (payment_id, seq, kind, amount_minor, balance_after, detail)
            SELECT $1, COALESCE(MAX(seq), 0) + 1, 'refund', $2, $3, $4
              FROM ledger_entry WHERE payment_id = $1
            RETURNING seq
            "#,
        )
        .bind(id)
        .bind(transition.entry_amount.minor())
        .bind(transition.balance.minor())
        .bind(detail)
        .fetch_one(&mut *tx)
        .await?
        .try_get("seq")?;

        sqlx::query(
            r#"
            INSERT INTO refund_request (idempotency_key, payment_id, amount_minor, seq)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(refund_key)
        .bind(id)
        .bind(transition.entry_amount.minor())
        .bind(seq)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(true)
    }

    pub async fn find_refund(&self, refund_key: &str) -> Result<Option<Uuid>, StoreError> {
        let row = sqlx::query("SELECT payment_id FROM refund_request WHERE idempotency_key = $1")
            .bind(refund_key)
            .fetch_optional(&self.pool)
            .await?;
        Ok(row.map(|r| r.get("payment_id")))
    }

    pub async fn get(&self, id: Uuid) -> Result<StoredPayment, StoreError> {
        let row = sqlx::query(
            r#"SELECT id, idempotency_key, order_reference, amount_minor, currency,
                      state, balance_minor, acquirer_ref, created_at
                 FROM payment WHERE id = $1"#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(StoreError::NotFound)?;
        stored_from_row(&row)
    }

    pub async fn get_by_key(&self, key: &str) -> Result<StoredPayment, StoreError> {
        let row = sqlx::query(
            r#"SELECT id, idempotency_key, order_reference, amount_minor, currency,
                      state, balance_minor, acquirer_ref, created_at
                 FROM payment WHERE idempotency_key = $1"#,
        )
        .bind(key)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(StoreError::NotFound)?;
        stored_from_row(&row)
    }

    pub async fn ledger(&self, id: Uuid) -> Result<Vec<LedgerRow>, StoreError> {
        let rows = sqlx::query(
            r#"SELECT seq, kind, amount_minor, balance_after, detail, at
                 FROM ledger_entry WHERE payment_id = $1 ORDER BY seq"#,
        )
        .bind(id)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows
            .iter()
            .map(|r| LedgerRow {
                seq: r.get("seq"),
                kind: r.get("kind"),
                amount_minor: r.get("amount_minor"),
                balance_after: r.get("balance_after"),
                detail: r.get("detail"),
                at: r.get("at"),
            })
            .collect())
    }

    /// Payments the acquirer never answered for, old enough to be worth asking
    /// about again.
    pub async fn pending_since(
        &self,
        seconds: i64,
        limit: i64,
    ) -> Result<Vec<StoredPayment>, StoreError> {
        let rows = sqlx::query(
            r#"SELECT id, idempotency_key, order_reference, amount_minor, currency,
                      state, balance_minor, acquirer_ref, created_at
                 FROM payment
                WHERE state = 'pending' AND created_at < now() - make_interval(secs => $1)
                ORDER BY created_at
                LIMIT $2"#,
        )
        .bind(seconds as f64)
        .bind(limit)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(stored_from_row).collect()
    }

    pub async fn count_pending(&self) -> Result<i64, StoreError> {
        let row = sqlx::query("SELECT count(*) AS n FROM payment WHERE state = 'pending'")
            .fetch_one(&self.pool)
            .await?;
        Ok(row.get("n"))
    }
}

fn stored_from_row(row: &sqlx::postgres::PgRow) -> Result<StoredPayment, StoreError> {
    let id: Uuid = row.try_get("id")?;
    let currency_code: String = row.try_get("currency")?;
    let currency =
        Currency::parse(&currency_code).map_err(|e| StoreError::Corrupt(id, e.to_string()))?;
    let amount = Money::new(row.try_get::<i64, _>("amount_minor")?, currency)
        .map_err(|e| StoreError::Corrupt(id, e.to_string()))?;
    let balance = Money::new(row.try_get::<i64, _>("balance_minor")?, currency)
        .map_err(|e| StoreError::Corrupt(id, e.to_string()))?;
    let state_text: String = row.try_get("state")?;
    let state = PaymentState::parse(&state_text)
        .ok_or_else(|| StoreError::Corrupt(id, format!("unknown state {state_text}")))?;

    Ok(StoredPayment {
        id,
        idempotency_key: row.try_get("idempotency_key")?,
        order_reference: row.try_get("order_reference")?,
        payment: Payment {
            state,
            amount,
            balance,
        },
        acquirer_ref: row.try_get("acquirer_ref")?,
        created_at: row.try_get("created_at")?,
    })
}
