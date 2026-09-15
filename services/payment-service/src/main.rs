//! payment-service: authorisation, capture, refund, and the ledger behind them.
//!
//! The smallest surface in the platform and the strictest correctness
//! requirement, which is why it is in Rust: the ledger's transitions are
//! exhaustive matches with no catch-all arm, so a new state or event stops the
//! build until somebody decides what it means, and every arithmetic operation
//! on money is checked rather than wrapping.
//!
//! The failure it is built around is not a decline. It is an acquirer that
//! **takes the money and does not answer.** Everything here — writing the
//! intent before the call, the `pending` state, the resolve-by-key endpoint,
//! the reconciler — exists for that one case.

mod acquirer;
mod api;
mod ledger;
mod money;
mod store;

use acquirer::{Acquirer, Behaviour};
use api::{AppState, Metrics};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use std::time::Duration;
use store::Store;

#[tokio::main]
async fn main() {
    // JSON to stdout: the container writes, the platform collects. A service
    // that manages its own log files needs a writable filesystem and a rotation
    // policy, and this one has neither.
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .init();

    if let Err(e) = run().await {
        tracing::error!(error = %e, "fatal");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), Box<dyn std::error::Error>> {
    let database_url = env_required("DATABASE_URL")?;
    let port = env_or("PORT", "8083");
    let behaviour = Behaviour::parse(&env_or("ACQUIRER_BEHAVIOUR", "approve"))
        .ok_or("ACQUIRER_BEHAVIOUR must be approve, decline or hang")?;
    let acquirer_delay = Duration::from_millis(env_num("ACQUIRER_DELAY_MS", 5_000));
    let acquirer_timeout = Duration::from_millis(env_num("ACQUIRER_TIMEOUT_MS", 2_000));
    let reconcile_every = Duration::from_millis(env_num("RECONCILE_INTERVAL_MS", 15_000));
    let reconcile_after_secs = env_num("RECONCILE_AFTER_SECONDS", 20) as i64;
    // Must exceed the longest an authorisation can be in flight at the
    // acquirer. Below that, "no charge found" means "not yet", and voiding on
    // it writes off a payment the customer is about to be charged for.
    let void_after = Duration::from_secs(env_num("ACQUIRER_VOID_AFTER_SECONDS", 60));

    let pool = PgPoolOptions::new()
        .max_connections(env_num("DB_POOL_MAX", 8) as u32)
        .acquire_timeout(Duration::from_secs(5))
        .connect(&database_url)
        .await?;

    // Migrations run at startup, inside the pod's startup-probe window.
    sqlx::migrate!("./migrations").run(&pool).await?;
    tracing::info!("migrations applied");

    let store = Store::new(pool);
    let state = AppState {
        store: store.clone(),
        acquirer: Acquirer::new(behaviour, acquirer_delay),
        acquirer_timeout,
        void_after,
        metrics: Arc::new(Metrics::default()),
    };

    let reconciler = tokio::spawn(reconcile_loop(
        state.clone(),
        reconcile_every,
        reconcile_after_secs,
    ));

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await?;
    tracing::info!(
        port = %port,
        acquirer = ?behaviour,
        acquirer_timeout_ms = acquirer_timeout.as_millis() as u64,
        "listening"
    );

    axum::serve(listener, api::routes(state))
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    reconciler.abort();
    tracing::info!("stopped");
    Ok(())
}

/// Ask the acquirer again about payments it never answered for.
///
/// **This one is load-bearing, and that is worth saying plainly.** The reaper in
/// inventory-service and the dispatch watcher in order-service are bookkeeping:
/// stop them and nothing is wrong. Stop this and payments stay `pending`
/// forever, which means real charges are never recognised. The difference is
/// that resolving requires *asking someone else*, and no amount of clever
/// schema design makes that derivable from a clock.
///
/// What is still true: a pending payment is never counted as money taken, so a
/// stopped reconciler delays recognition rather than producing a wrong answer.
/// The gauge `payment_pending` is the alert — it is the number that must come
/// back to zero.
async fn reconcile_loop(state: AppState, every: Duration, after_secs: i64) {
    let mut ticker = tokio::time::interval(every);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        ticker.tick().await;
        match state.store.pending_since(after_secs, 100).await {
            Ok(pending) if pending.is_empty() => {}
            Ok(pending) => {
                tracing::info!(
                    count = pending.len(),
                    "resolving payments the acquirer never answered"
                );
                for stored in pending {
                    // The same function the caller-driven path uses, so the two
                    // cannot drift apart on the question of when "no charge"
                    // may be believed.
                    match api::resolve_pending(&state, &stored).await {
                        Ok(api::Resolution::Settled(new_state)) => tracing::info!(
                            payment_id = %stored.id,
                            state = new_state.as_str(),
                            "payment resolved"
                        ),
                        Ok(api::Resolution::StillPending) => tracing::warn!(
                            payment_id = %stored.id,
                            "payment still unresolved"
                        ),
                        Err(e) => {
                            tracing::error!(error = %e, payment_id = %stored.id, "could not resolve")
                        }
                    }
                }
            }
            Err(e) => tracing::error!(error = %e, "reconciler could not read pending payments"),
        }
    }
}

async fn shutdown_signal() {
    let ctrl_c = async { tokio::signal::ctrl_c().await.expect("ctrl_c handler") };
    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("SIGTERM handler")
            .recv()
            .await;
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {}
        _ = terminate => {}
    }
    tracing::info!("shutting down");
}

fn env_required(key: &str) -> Result<String, String> {
    std::env::var(key).map_err(|_| format!("{key} is not set"))
}

fn env_or(key: &str, default: &str) -> String {
    std::env::var(key).unwrap_or_else(|_| default.to_string())
}

fn env_num(key: &str, default: u64) -> u64 {
    std::env::var(key)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}
