//! The HTTP surface.
//!
//! The status codes carry meaning the caller acts on, so they are chosen
//! carefully rather than defaulted:
//!
//! | | |
//! |---|---|
//! | `201` | the money was taken |
//! | `200` | this key already took it — a replay, not a second charge |
//! | `402` | the acquirer refused. No money moved. |
//! | `409` | the key was used for a different request |
//! | `504` | **unknown.** The acquirer did not answer, and the money may or may not have been taken. |
//!
//! The 504 is the one that matters. Returning 500 would invite the caller to
//! treat it as a failure and move on, and moving on from "the customer may have
//! been charged" is how money goes missing. A caller that receives it must
//! resolve the payment by key rather than assume.

use crate::acquirer::{Acquirer, Outcome};
use crate::ledger::{Event, PaymentState};
use crate::money::{Currency, Money};
use crate::store::{Store, StoreError, StoredPayment};
use axum::extract::{Path, State};
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use chrono::{Duration as ChronoDuration, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use uuid::Uuid;

#[derive(Clone)]
pub struct AppState {
    pub store: Store,
    pub acquirer: Acquirer,
    pub acquirer_timeout: Duration,
    /// How long an authorisation could still be in flight at the acquirer.
    ///
    /// Until a pending payment is this old, "the acquirer has no charge for
    /// this reference" means **not yet**, not **never**. See
    /// [`resolve_pending`].
    pub void_after: Duration,
    pub metrics: Arc<Metrics>,
}

/// Four counters, each answering a question somebody asks during an incident.
#[derive(Default)]
pub struct Metrics {
    pub captured: AtomicU64,
    pub declined: AtomicU64,
    pub unresolved: AtomicU64,
    pub refunded: AtomicU64,
    pub reconciled: AtomicU64,
}

pub fn routes(state: AppState) -> Router {
    Router::new()
        .route("/v1/payments", post(create_payment))
        .route("/v1/payments/:id", get(get_payment))
        .route("/v1/payments/:id/ledger", get(get_ledger))
        .route("/v1/payments/:id/refund", post(refund))
        // The endpoint that makes a timeout survivable: ask what happened,
        // using the key you sent. Without it, an unanswered authorisation is
        // permanently unknown and every timeout becomes a manual investigation.
        .route("/v1/payments/by-key/:key", get(resolve_by_key))
        // Liveness answers from the process alone: if it touched Postgres, a
        // database outage would restart every healthy pod.
        .route("/healthz", get(|| async { Json(json!({"status": "ok"})) }))
        .route("/readyz", get(readyz))
        .route("/metrics", get(metrics))
        .with_state(state)
}

// ---------------------------------------------------------------- shapes

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreatePaymentRequest {
    pub order_reference: String,
    pub amount_minor: i64,
    pub currency: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PaymentView {
    pub id: String,
    pub order_reference: String,
    pub amount_minor: i64,
    pub currency: String,
    pub state: PaymentState,
    /// What is still held from the customer. Zero for a declined or fully
    /// refunded payment, and zero for a pending one — because a pending payment
    /// is not money taken.
    pub balance_minor: i64,
    /// Whether the customer's money is with us. A caller should read this
    /// rather than inferring it from the state name: `pending` looks like
    /// progress and means "we do not know".
    pub holds_money: bool,
    /// False only while the acquirer has not answered.
    pub resolved: bool,
    pub acquirer_ref: Option<String>,
    pub created_at: String,
}

impl PaymentView {
    fn of(p: &StoredPayment) -> Self {
        PaymentView {
            id: p.id.to_string(),
            order_reference: p.order_reference.clone(),
            amount_minor: p.payment.amount.minor(),
            currency: p.payment.amount.currency().code().to_string(),
            state: p.payment.state,
            balance_minor: p.payment.balance.minor(),
            holds_money: p.payment.state.holds_money(),
            resolved: p.payment.state.is_resolved(),
            acquirer_ref: p.acquirer_ref.clone(),
            created_at: p.created_at.to_rfc3339(),
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RefundRequest {
    pub amount_minor: i64,
    pub reason: Option<String>,
}

fn problem(status: StatusCode, code: &str, message: impl Into<String>) -> Response {
    (
        status,
        Json(json!({ "error": code, "message": message.into() })),
    )
        .into_response()
}

fn idempotency_key(headers: &HeaderMap) -> Option<String> {
    headers
        .get("Idempotency-Key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty() && s.len() <= 128)
        .map(str::to_string)
}

// -------------------------------------------------------------- handlers

async fn create_payment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreatePaymentRequest>,
) -> Response {
    let Some(key) = idempotency_key(&headers) else {
        return problem(
            StatusCode::BAD_REQUEST,
            "missing_idempotency_key",
            "the Idempotency-Key header is required, and must be 1-128 characters",
        );
    };

    let currency = match Currency::parse(&body.currency) {
        Ok(c) => c,
        Err(e) => return problem(StatusCode::BAD_REQUEST, "unknown_currency", e.to_string()),
    };
    if body.amount_minor <= 0 {
        return problem(
            StatusCode::BAD_REQUEST,
            "invalid_amount",
            "amount must be a positive number of minor units",
        );
    }
    let amount = match Money::new(body.amount_minor, currency) {
        Ok(a) => a,
        Err(e) => return problem(StatusCode::BAD_REQUEST, "invalid_amount", e.to_string()),
    };

    // The intent is written first. If this process dies during the acquirer
    // call, the row is what makes the charge findable afterwards.
    let (stored, created) = match state
        .store
        .begin_payment(&key, &body.order_reference, amount)
        .await
    {
        Ok(v) => v,
        Err(StoreError::IdempotencyConflict) => {
            return problem(
                StatusCode::CONFLICT,
                "idempotency_key_reused",
                "this Idempotency-Key was used for a different payment",
            )
        }
        Err(e) => return internal(e),
    };

    if !created {
        // A replay. Answer about the payment that already exists rather than
        // charging again; if it is still pending, try to resolve it.
        return match stored.payment.state {
            PaymentState::Pending => resolve(state, stored).await,
            _ => settled_response(&stored, StatusCode::OK, &state),
        };
    }

    // The acquirer call is bounded. An unbounded one would hold the request
    // until the socket gave up, and the caller's own timeout would fire first
    // anyway, leaving this service unaware it had been abandoned.
    let outcome = tokio::time::timeout(
        state.acquirer_timeout,
        state.acquirer.authorise(&key, amount),
    )
    .await;

    match outcome {
        Ok(Outcome::Captured { acquirer_ref }) => {
            let transition = match stored.payment.apply(Event::AcquirerCaptured { amount }) {
                Ok(t) => t,
                Err(e) => return internal(e),
            };
            if let Err(e) = state
                .store
                .apply(
                    stored.id,
                    PaymentState::Pending,
                    transition,
                    Some(acquirer_ref.as_str()),
                    "acquirer captured",
                )
                .await
            {
                return internal(e);
            }
            state.metrics.captured.fetch_add(1, Ordering::Relaxed);
            reload(&state, stored.id, StatusCode::CREATED).await
        }
        Ok(Outcome::Declined) => {
            let transition = match stored.payment.apply(Event::AcquirerDeclined) {
                Ok(t) => t,
                Err(e) => return internal(e),
            };
            if let Err(e) = state
                .store
                .apply(
                    stored.id,
                    PaymentState::Pending,
                    transition,
                    None,
                    "acquirer declined",
                )
                .await
            {
                return internal(e);
            }
            state.metrics.declined.fetch_add(1, Ordering::Relaxed);
            reload(&state, stored.id, StatusCode::PAYMENT_REQUIRED).await
        }
        Ok(Outcome::NoSuchCharge) => {
            let transition = match stored.payment.apply(Event::Fail) {
                Ok(t) => t,
                Err(e) => return internal(e),
            };
            if let Err(e) = state
                .store
                .apply(
                    stored.id,
                    PaymentState::Pending,
                    transition,
                    None,
                    "acquirer refused the request",
                )
                .await
            {
                return internal(e);
            }
            reload(&state, stored.id, StatusCode::PAYMENT_REQUIRED).await
        }
        Err(_elapsed) => {
            // The honest answer: we do not know. The payment stays pending, the
            // row is on disk, and the caller is told how to find out.
            state.metrics.unresolved.fetch_add(1, Ordering::Relaxed);
            tracing::warn!(
                payment_id = %stored.id,
                key = %key,
                "acquirer did not answer within the timeout; payment left pending"
            );
            (
                StatusCode::GATEWAY_TIMEOUT,
                Json(json!({
                    "error": "acquirer_timeout",
                    "message": "the acquirer did not answer. The payment may or may not have been taken.",
                    "paymentId": stored.id.to_string(),
                    "idempotencyKey": key,
                    "resolveAt": format!("/v1/payments/by-key/{key}"),
                })),
            )
                .into_response()
        }
    }
}

/// What a resolution attempt concluded.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Resolution {
    /// The payment now has an outcome.
    Settled(PaymentState),
    /// Still unknown, and guessing would be worse than waiting.
    StillPending,
}

/// Ask the acquirer again about a payment it never answered for, and record
/// whatever it says.
///
/// Both the caller-driven path (after a 504) and the reconciler call this, so
/// the two cannot drift apart. They are safe to run at once: the conditional
/// update in the store means only one of them writes.
///
/// ## Why "no charge" is not immediately a void
///
/// The first version of this function treated `NoSuchCharge` as proof that no
/// charge would ever be made, and voided the payment. That is wrong, and it was
/// wrong in the most expensive direction available.
///
/// A demonstration, run against this service: the acquirer was given a 6 s
/// delay and the client a 1.5 s timeout. The authorisation timed out, the
/// caller resolved by key one second later, the acquirer had not recorded the
/// charge *yet*, and the payment was written off as `failed`. Five seconds
/// later the money was taken. The customer was charged and the ledger said the
/// payment never happened — the one outcome every other rule in this service
/// exists to prevent.
///
/// An authorisation that has not appeared is not an authorisation that will not
/// appear. So a `NoSuchCharge` may only void a payment once it is older than
/// `void_after`, which must exceed the longest an authorisation can be in
/// flight at the acquirer. Before that, the honest answer is that it is still
/// unknown.
///
/// The properly authoritative version of this is an explicit cancel call to the
/// acquirer, which makes "no charge" a fact rather than an observation. That
/// needs an acquirer that offers one; the age window is what is available here,
/// and it is a weaker guarantee that should be named as such.
pub async fn resolve_pending(
    state: &AppState,
    stored: &StoredPayment,
) -> Result<Resolution, String> {
    let outcome = tokio::time::timeout(
        state.acquirer_timeout,
        state.acquirer.lookup(&stored.idempotency_key),
    )
    .await;

    let (event, acquirer_ref, detail) = match outcome {
        Ok(Outcome::Captured { acquirer_ref }) => (
            Event::AcquirerCaptured {
                amount: stored.payment.amount,
            },
            Some(acquirer_ref),
            "resolved: the acquirer had taken the money".to_string(),
        ),
        Ok(Outcome::Declined) => (
            Event::AcquirerDeclined,
            None,
            "resolved: declined".to_string(),
        ),
        Ok(Outcome::NoSuchCharge) => {
            let age = Utc::now().signed_duration_since(stored.created_at);
            let void_after = ChronoDuration::from_std(state.void_after)
                .unwrap_or_else(|_| ChronoDuration::seconds(60));
            if age < void_after {
                // Too young to call. The authorisation may still land.
                tracing::info!(
                    payment_id = %stored.id,
                    age_secs = age.num_seconds(),
                    "acquirer has no charge yet; too early to void"
                );
                return Ok(Resolution::StillPending);
            }
            (
                Event::AcquirerVoided,
                None,
                format!(
                    "resolved: no charge after {}s, beyond the {}s window in which one could still land",
                    age.num_seconds(),
                    void_after.num_seconds()
                ),
            )
        }
        Err(_) => return Ok(Resolution::StillPending),
    };

    let transition = stored.payment.apply(event).map_err(|e| e.to_string())?;
    state
        .store
        .apply(
            stored.id,
            PaymentState::Pending,
            transition,
            acquirer_ref.as_ref().map(|r| r.as_str()),
            &detail,
        )
        .await
        .map_err(|e| e.to_string())?;

    state.metrics.reconciled.fetch_add(1, Ordering::Relaxed);
    Ok(Resolution::Settled(transition.state))
}

async fn resolve(state: AppState, stored: StoredPayment) -> Response {
    match resolve_pending(&state, &stored).await {
        Ok(Resolution::Settled(PaymentState::Captured)) => {
            reload(&state, stored.id, StatusCode::OK).await
        }
        Ok(Resolution::Settled(_)) => reload(&state, stored.id, StatusCode::PAYMENT_REQUIRED).await,
        Ok(Resolution::StillPending) => (
            StatusCode::GATEWAY_TIMEOUT,
            Json(json!({
                "error": "still_unresolved",
                "message": "the acquirer has not answered, and it is too early to assume no charge was made",
                "paymentId": stored.id.to_string(),
            })),
        )
            .into_response(),
        Err(e) => internal(e),
    }
}

async fn resolve_by_key(State(state): State<AppState>, Path(key): Path<String>) -> Response {
    match state.store.get_by_key(&key).await {
        Ok(stored) if stored.payment.state == PaymentState::Pending => resolve(state, stored).await,
        Ok(stored) => settled_response(&stored, StatusCode::OK, &state),
        Err(StoreError::NotFound) => problem(
            StatusCode::NOT_FOUND,
            "not_found",
            "no payment was ever started with that key",
        ),
        Err(e) => internal(e),
    }
}

async fn get_payment(State(state): State<AppState>, Path(id): Path<Uuid>) -> Response {
    match state.store.get(id).await {
        Ok(stored) => (StatusCode::OK, Json(PaymentView::of(&stored))).into_response(),
        Err(StoreError::NotFound) => problem(StatusCode::NOT_FOUND, "not_found", "no such payment"),
        Err(e) => internal(e),
    }
}

async fn get_ledger(State(state): State<AppState>, Path(id): Path<Uuid>) -> Response {
    match state.store.ledger(id).await {
        Ok(rows) if rows.is_empty() => {
            problem(StatusCode::NOT_FOUND, "not_found", "no such payment")
        }
        Ok(rows) => {
            let body: Vec<_> = rows
                .iter()
                .map(|r| {
                    json!({
                        "seq": r.seq,
                        "kind": r.kind,
                        "amountMinor": r.amount_minor,
                        "balanceAfter": r.balance_after,
                        "detail": r.detail,
                        "at": r.at.to_rfc3339(),
                    })
                })
                .collect();
            (StatusCode::OK, Json(body)).into_response()
        }
        Err(e) => internal(e),
    }
}

async fn refund(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<RefundRequest>,
) -> Response {
    let Some(key) = idempotency_key(&headers) else {
        return problem(
            StatusCode::BAD_REQUEST,
            "missing_idempotency_key",
            "a refund needs an Idempotency-Key, or a retry pays out twice",
        );
    };

    // A refund that already happened is answered, not repeated.
    match state.store.find_refund(&key).await {
        Ok(Some(_)) => return reload(&state, id, StatusCode::OK).await,
        Ok(None) => {}
        Err(e) => return internal(e),
    }

    let stored = match state.store.get(id).await {
        Ok(s) => s,
        Err(StoreError::NotFound) => {
            return problem(StatusCode::NOT_FOUND, "not_found", "no such payment")
        }
        Err(e) => return internal(e),
    };

    let amount = match Money::new(body.amount_minor, stored.payment.amount.currency()) {
        Ok(a) => a,
        Err(e) => return problem(StatusCode::BAD_REQUEST, "invalid_amount", e.to_string()),
    };

    let transition = match stored.payment.apply(Event::Refund { amount }) {
        Ok(t) => t,
        Err(e) => return problem(StatusCode::CONFLICT, "refund_refused", e.to_string()),
    };

    let detail = body.reason.unwrap_or_else(|| "refund".to_string());
    match state
        .store
        .apply_refund(stored.id, stored.payment.state, transition, &key, &detail)
        .await
    {
        Ok(true) => {
            state.metrics.refunded.fetch_add(1, Ordering::Relaxed);
            reload(&state, id, StatusCode::OK).await
        }
        // Somebody refunded it underneath us; the caller's intent is satisfied.
        Ok(false) => reload(&state, id, StatusCode::OK).await,
        Err(e) => internal(e),
    }
}

async fn readyz(State(state): State<AppState>) -> Response {
    match state.store.ping().await {
        Ok(()) => (StatusCode::OK, Json(json!({"status": "ok"}))).into_response(),
        Err(_) => (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({"status": "unready", "reason": "database unreachable"})),
        )
            .into_response(),
    }
}

async fn metrics(State(state): State<AppState>) -> Response {
    let m = &state.metrics;
    let pending = state.store.count_pending().await.unwrap_or(-1);
    let body = format!(
        "# HELP payment_captured_total Payments where the acquirer took the money.\n\
         # TYPE payment_captured_total counter\n\
         payment_captured_total {}\n\
         # HELP payment_declined_total Payments the acquirer refused.\n\
         # TYPE payment_declined_total counter\n\
         payment_declined_total {}\n\
         # HELP payment_unresolved_total Authorisations the acquirer did not answer in time.\n\
         # TYPE payment_unresolved_total counter\n\
         payment_unresolved_total {}\n\
         # HELP payment_reconciled_total Pending payments later resolved by asking the acquirer again.\n\
         # TYPE payment_reconciled_total counter\n\
         payment_reconciled_total {}\n\
         # HELP payment_refunded_total Refunds written to the ledger.\n\
         # TYPE payment_refunded_total counter\n\
         payment_refunded_total {}\n\
         # HELP payment_pending Payments with no outcome yet. The number that must come back to zero.\n\
         # TYPE payment_pending gauge\n\
         payment_pending {}\n",
        m.captured.load(Ordering::Relaxed),
        m.declined.load(Ordering::Relaxed),
        m.unresolved.load(Ordering::Relaxed),
        m.reconciled.load(Ordering::Relaxed),
        m.refunded.load(Ordering::Relaxed),
        pending,
    );
    (StatusCode::OK, body).into_response()
}

// ------------------------------------------------------------- utilities

async fn reload(state: &AppState, id: Uuid, status: StatusCode) -> Response {
    match state.store.get(id).await {
        Ok(stored) => (status, Json(PaymentView::of(&stored))).into_response(),
        Err(e) => internal(e),
    }
}

fn settled_response(stored: &StoredPayment, status: StatusCode, _state: &AppState) -> Response {
    let status = match stored.payment.state {
        PaymentState::Declined | PaymentState::Failed => StatusCode::PAYMENT_REQUIRED,
        _ => status,
    };
    (status, Json(PaymentView::of(stored))).into_response()
}

/// The detail goes to the log; the caller gets a code. A database error message
/// is a map of the schema.
fn internal(e: impl std::fmt::Display) -> Response {
    tracing::error!(error = %e, "request failed");
    problem(
        StatusCode::INTERNAL_SERVER_ERROR,
        "internal_error",
        "the request could not be completed",
    )
}
