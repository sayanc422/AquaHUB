//! The card acquirer.
//!
//! This is the one part of the payment path that is stubbed, and the stub is
//! honest about which failure it models. Real acquirers do not merely approve
//! and decline: they also **take the money and fail to answer**, and that is
//! the case the rest of this service is built around.
//!
//! `Behaviour::Hang` reproduces it exactly. The authorisation is recorded after
//! the delay whether or not the caller is still waiting — because the charge
//! happened at the acquirer, and the caller giving up changes nothing about
//! that. A stub that simply returned an error would model a polite failure
//! nobody needs help with.

use crate::money::Money;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Behaviour {
    Approve,
    Decline,
    /// Take the money, answer after `delay`. With a client timeout shorter than
    /// the delay, the caller sees a timeout and the charge exists anyway.
    Hang,
}

impl Behaviour {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_lowercase().as_str() {
            "approve" => Some(Behaviour::Approve),
            "decline" => Some(Behaviour::Decline),
            "hang" => Some(Behaviour::Hang),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    Captured {
        acquirer_ref: AcquirerRef,
    },
    Declined,
    /// The acquirer is certain no charge exists for this reference.
    NoSuchCharge,
}

/// A fixed-size reference, so it can be `Copy` and cannot allocate on a path
/// that runs while money is in flight.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AcquirerRef(pub [u8; 20]);

impl AcquirerRef {
    fn new() -> Self {
        let s = format!("acq_{}", Uuid::new_v4().simple());
        let mut buf = [b'0'; 20];
        buf.copy_from_slice(&s.as_bytes()[..20]);
        AcquirerRef(buf)
    }

    pub fn as_str(&self) -> &str {
        std::str::from_utf8(&self.0).unwrap_or("acq_unreadable")
    }
}

/// The stub acquirer.
///
/// Its memory is the point: a charge it made is findable afterwards by the
/// reference the caller used, which is what makes an unanswered authorisation
/// resolvable instead of permanently unknown.
#[derive(Clone)]
pub struct Acquirer {
    behaviour: Behaviour,
    delay: Duration,
    charges: Arc<Mutex<HashMap<String, Outcome>>>,
}

impl Acquirer {
    pub fn new(behaviour: Behaviour, delay: Duration) -> Self {
        Acquirer {
            behaviour,
            delay,
            charges: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Ask for the money.
    ///
    /// The recording happens in a spawned task, not inline, so that a caller
    /// who times out and drops this future does not thereby cancel the charge.
    /// That asymmetry — the charge outlives the request — is the entire problem
    /// this service exists to handle.
    pub async fn authorise(&self, reference: &str, amount: Money) -> Outcome {
        let outcome = match self.behaviour {
            Behaviour::Approve | Behaviour::Hang => Outcome::Captured {
                acquirer_ref: AcquirerRef::new(),
            },
            Behaviour::Decline => Outcome::Declined,
        };

        let delay = match self.behaviour {
            Behaviour::Hang => self.delay,
            _ => Duration::ZERO,
        };

        let charges = Arc::clone(&self.charges);
        let key = reference.to_string();
        tokio::spawn(async move {
            tokio::time::sleep(delay).await;
            charges.lock().expect("acquirer mutex").insert(key, outcome);
        });

        tracing::debug!(reference, amount = %amount, ?outcome, ?delay, "acquirer called");
        tokio::time::sleep(delay).await;
        outcome
    }

    /// What happened to this reference, as far as the acquirer knows.
    ///
    /// This is the call that resolves an unanswered authorisation. A real
    /// acquirer offers the same thing, and a payment integration without it
    /// cannot ever answer "did the customer pay?" after a timeout.
    pub async fn lookup(&self, reference: &str) -> Outcome {
        self.charges
            .lock()
            .expect("acquirer mutex")
            .get(reference)
            .copied()
            .unwrap_or(Outcome::NoSuchCharge)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::money::{Currency, Money};

    fn amount() -> Money {
        Money::new(1000, Currency::INR).unwrap()
    }

    #[tokio::test]
    async fn an_approved_charge_is_findable_afterwards() {
        let acquirer = Acquirer::new(Behaviour::Approve, Duration::ZERO);
        let outcome = acquirer.authorise("ref-1", amount()).await;
        assert!(matches!(outcome, Outcome::Captured { .. }));
        // The spawned recording has to land before the lookup sees it.
        tokio::time::sleep(Duration::from_millis(20)).await;
        assert!(matches!(
            acquirer.lookup("ref-1").await,
            Outcome::Captured { .. }
        ));
    }

    #[tokio::test]
    async fn an_unknown_reference_is_not_a_charge() {
        let acquirer = Acquirer::new(Behaviour::Approve, Duration::ZERO);
        assert_eq!(acquirer.lookup("never-seen").await, Outcome::NoSuchCharge);
    }

    /// The case the service is built around: the caller gives up, and the money
    /// is taken anyway.
    #[tokio::test]
    async fn a_caller_who_times_out_does_not_cancel_the_charge() {
        let acquirer = Acquirer::new(Behaviour::Hang, Duration::from_millis(80));

        let timed_out = tokio::time::timeout(
            Duration::from_millis(10),
            acquirer.authorise("ref-hang", amount()),
        )
        .await;
        assert!(timed_out.is_err(), "the call should have timed out");

        // The charge still exists, and can be found by reference.
        tokio::time::sleep(Duration::from_millis(120)).await;
        assert!(
            matches!(acquirer.lookup("ref-hang").await, Outcome::Captured { .. }),
            "a dropped request must not un-charge the customer"
        );
    }

    #[tokio::test]
    async fn a_decline_records_a_decline_not_a_charge() {
        let acquirer = Acquirer::new(Behaviour::Decline, Duration::ZERO);
        assert_eq!(
            acquirer.authorise("ref-d", amount()).await,
            Outcome::Declined
        );
        tokio::time::sleep(Duration::from_millis(20)).await;
        assert_eq!(acquirer.lookup("ref-d").await, Outcome::Declined);
    }
}
