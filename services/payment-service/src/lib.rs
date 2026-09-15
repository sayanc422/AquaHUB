//! payment-service, as a library.
//!
//! The crate is a lib plus a thin binary rather than a single `main.rs`, and
//! the reason is testability: a binary crate cannot be imported from
//! `tests/`, so everything it contains can only ever be tested from inside
//! itself. The parts of this service that most need a real database — the CHECK
//! constraints, the append-only trigger, the conditional update that stops two
//! resolvers writing twice — cannot be reached at all from a unit test.
//!
//! Splitting the crate is what `tests/store_db.rs` needs to exist.

pub mod acquirer;
pub mod api;
pub mod ledger;
pub mod money;
pub mod store;
