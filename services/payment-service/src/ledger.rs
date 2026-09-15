//! The payment state machine and the ledger it writes.
//!
//! This is the reason this service is in Rust. Every transition is an
//! exhaustive `match` with no catch-all arm, so adding a state or an event
//! stops the build until every case has been decided by a person. A payment
//! system's worst failure is a case nobody thought about being handled by a
//! default branch.
//!
//! The ledger is append-only. A refund is a new entry, never an edit of the
//! capture it reverses: the balance is a fold over the entries, and history
//! that can be rewritten is not history.

use crate::money::{Money, MoneyError};
use serde::{Deserialize, Serialize};

/// Where a payment stands.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PaymentState {
    /// The intent is written and the acquirer has not answered.
    ///
    /// **Money may or may not have been taken.** This state exists because the
    /// alternative — calling the acquirer first and writing afterwards — loses
    /// the record of a charge whenever the process dies mid-call. A payment
    /// that is `Pending` is never counted as money taken, and is never
    /// reported to the caller as success.
    Pending,
    /// The acquirer took the money.
    Captured,
    /// The acquirer refused. No money moved.
    Declined,
    /// Some of the captured amount has been given back.
    PartiallyRefunded,
    /// All of it has.
    Refunded,
    /// The attempt ended without a charge, and not because of a decline —
    /// a malformed request, or an acquirer that answered with nonsense.
    Failed,
}

/// What happened, in the order it happened.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EntryKind {
    /// Intent recorded, before the acquirer is called.
    Authorise,
    Capture,
    Decline,
    Refund,
    /// The acquirer was asked again about a pending payment and said no charge
    /// was ever made.
    Void,
}

/// The events the machine accepts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Event {
    /// The acquirer took `amount`.
    AcquirerCaptured { amount: Money },
    /// The acquirer refused.
    AcquirerDeclined,
    /// The acquirer confirmed no charge exists for a pending payment.
    AcquirerVoided,
    /// Give `amount` back.
    Refund { amount: Money },
    /// The attempt is over and no charge was made.
    Fail,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum LedgerError {
    #[error("a payment in state {state:?} cannot accept {event}")]
    IllegalTransition {
        state: PaymentState,
        event: &'static str,
    },
    #[error("refund of {requested} exceeds the {available} still refundable")]
    RefundTooLarge { requested: Money, available: Money },
    #[error("a refund must be for more than nothing")]
    ZeroRefund,
    #[error(transparent)]
    Money(#[from] MoneyError),
}

/// What a transition changes: the new state, and the entry to append.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Transition {
    pub state: PaymentState,
    pub entry: EntryKind,
    pub entry_amount: Money,
    /// The amount still held from the customer after this entry.
    pub balance: Money,
}

/// A payment as the machine sees it: where it is, and what is still held.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Payment {
    pub state: PaymentState,
    /// What the payment was for. Fixed at creation.
    pub amount: Money,
    /// What is still held from the customer: the capture, less refunds.
    pub balance: Money,
}

impl Payment {
    /// Test-only: production builds a `Payment` from a stored row. Kept so the
    /// machine's tests can start from the state the store creates.
    #[cfg(test)]
    pub fn pending(amount: Money) -> Self {
        Payment {
            state: PaymentState::Pending,
            amount,
            balance: Money::zero(amount.currency()),
        }
    }

    /// How much could still be given back.
    pub fn refundable(&self) -> Money {
        self.balance
    }

    /// Apply an event.
    ///
    /// Every arm of the outer match is a state, and every inner match is
    /// exhaustive over the events. There is no `_ =>` anywhere in this
    /// function, deliberately: a new state or a new event must not compile
    /// until somebody has said what it means here.
    pub fn apply(&self, event: Event) -> Result<Transition, LedgerError> {
        match self.state {
            PaymentState::Pending => match event {
                Event::AcquirerCaptured { amount } => Ok(Transition {
                    state: PaymentState::Captured,
                    entry: EntryKind::Capture,
                    entry_amount: amount,
                    balance: amount,
                }),
                Event::AcquirerDeclined => Ok(Transition {
                    state: PaymentState::Declined,
                    entry: EntryKind::Decline,
                    entry_amount: Money::zero(self.amount.currency()),
                    balance: Money::zero(self.amount.currency()),
                }),
                Event::AcquirerVoided => Ok(Transition {
                    state: PaymentState::Failed,
                    entry: EntryKind::Void,
                    entry_amount: Money::zero(self.amount.currency()),
                    balance: Money::zero(self.amount.currency()),
                }),
                Event::Fail => Ok(Transition {
                    state: PaymentState::Failed,
                    entry: EntryKind::Void,
                    entry_amount: Money::zero(self.amount.currency()),
                    balance: Money::zero(self.amount.currency()),
                }),
                // Refunding money that may never have been taken would create
                // a payout with no charge behind it. Resolve the payment first.
                Event::Refund { .. } => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "refund",
                }),
            },

            PaymentState::Captured | PaymentState::PartiallyRefunded => match event {
                Event::Refund { amount } => self.refund(amount),
                // The acquirer cannot un-take money that is already captured,
                // and a second capture would charge twice.
                Event::AcquirerCaptured { .. } => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "capture",
                }),
                Event::AcquirerDeclined => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "decline",
                }),
                Event::AcquirerVoided => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "void",
                }),
                Event::Fail => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "fail",
                }),
            },

            // Terminal. A refund against a fully refunded payment is the
            // double-refund bug, and it is refused rather than clamped.
            PaymentState::Refunded | PaymentState::Declined | PaymentState::Failed => match event {
                Event::Refund { .. } => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "refund",
                }),
                Event::AcquirerCaptured { .. } => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "capture",
                }),
                Event::AcquirerDeclined => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "decline",
                }),
                Event::AcquirerVoided => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "void",
                }),
                Event::Fail => Err(LedgerError::IllegalTransition {
                    state: self.state,
                    event: "fail",
                }),
            },
        }
    }

    fn refund(&self, amount: Money) -> Result<Transition, LedgerError> {
        if amount.is_zero() {
            return Err(LedgerError::ZeroRefund);
        }
        let available = self.refundable();
        // Checked subtraction, so an over-refund is an error rather than a
        // negative balance or a wrapped one.
        let balance = available
            .checked_sub(amount)
            .map_err(|_| LedgerError::RefundTooLarge {
                requested: amount,
                available,
            })?;

        let state = if balance.is_zero() {
            PaymentState::Refunded
        } else {
            PaymentState::PartiallyRefunded
        };
        Ok(Transition {
            state,
            entry: EntryKind::Refund,
            entry_amount: amount,
            balance,
        })
    }
}

impl PaymentState {
    pub fn as_str(self) -> &'static str {
        match self {
            PaymentState::Pending => "pending",
            PaymentState::Captured => "captured",
            PaymentState::Declined => "declined",
            PaymentState::PartiallyRefunded => "partially_refunded",
            PaymentState::Refunded => "refunded",
            PaymentState::Failed => "failed",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "pending" => Some(PaymentState::Pending),
            "captured" => Some(PaymentState::Captured),
            "declined" => Some(PaymentState::Declined),
            "partially_refunded" => Some(PaymentState::PartiallyRefunded),
            "refunded" => Some(PaymentState::Refunded),
            "failed" => Some(PaymentState::Failed),
            _ => None,
        }
    }

    /// True when the customer's money is with us.
    pub fn holds_money(self) -> bool {
        match self {
            PaymentState::Captured | PaymentState::PartiallyRefunded => true,
            // Pending is NOT money taken. That is the whole point of the state:
            // an unresolved payment must never be counted as a charge.
            PaymentState::Pending
            | PaymentState::Declined
            | PaymentState::Refunded
            | PaymentState::Failed => false,
        }
    }

    pub fn is_resolved(self) -> bool {
        !matches!(self, PaymentState::Pending)
    }
}

impl EntryKind {
    pub fn as_str(self) -> &'static str {
        match self {
            EntryKind::Authorise => "authorise",
            EntryKind::Capture => "capture",
            EntryKind::Decline => "decline",
            EntryKind::Refund => "refund",
            EntryKind::Void => "void",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::money::Currency;

    fn inr(n: i64) -> Money {
        Money::new(n, Currency::INR).unwrap()
    }

    fn captured(amount: i64) -> Payment {
        let p = Payment::pending(inr(amount));
        let t = p
            .apply(Event::AcquirerCaptured {
                amount: inr(amount),
            })
            .unwrap();
        Payment {
            state: t.state,
            amount: inr(amount),
            balance: t.balance,
        }
    }

    #[test]
    fn a_pending_payment_holds_no_money() {
        let p = Payment::pending(inr(1000));
        assert!(!p.state.holds_money());
        assert!(!p.state.is_resolved());
        assert_eq!(p.balance, inr(0));
    }

    #[test]
    fn capture_moves_the_balance_and_nothing_else() {
        let t = Payment::pending(inr(1000))
            .apply(Event::AcquirerCaptured { amount: inr(1000) })
            .unwrap();
        assert_eq!(t.state, PaymentState::Captured);
        assert_eq!(t.entry, EntryKind::Capture);
        assert_eq!(t.balance, inr(1000));
        assert!(t.state.holds_money());
    }

    #[test]
    fn a_decline_takes_no_money() {
        let t = Payment::pending(inr(1000))
            .apply(Event::AcquirerDeclined)
            .unwrap();
        assert_eq!(t.state, PaymentState::Declined);
        assert_eq!(t.balance, inr(0));
        assert!(!t.state.holds_money());
    }

    /// Refunding a payment that may never have been charged would create a
    /// payout with nothing behind it.
    #[test]
    fn a_pending_payment_cannot_be_refunded() {
        let err = Payment::pending(inr(1000))
            .apply(Event::Refund { amount: inr(1000) })
            .unwrap_err();
        assert_eq!(
            err,
            LedgerError::IllegalTransition {
                state: PaymentState::Pending,
                event: "refund"
            }
        );
    }

    #[test]
    fn a_full_refund_empties_the_balance_and_is_terminal() {
        let p = captured(1000);
        let t = p.apply(Event::Refund { amount: inr(1000) }).unwrap();
        assert_eq!(t.state, PaymentState::Refunded);
        assert_eq!(t.balance, inr(0));

        let refunded = Payment {
            state: t.state,
            amount: p.amount,
            balance: t.balance,
        };
        assert!(refunded.apply(Event::Refund { amount: inr(1) }).is_err());
    }

    #[test]
    fn partial_refunds_accumulate_and_the_last_one_closes_it() {
        let mut p = captured(1000);
        for expected_balance in [700, 400, 100] {
            let t = p.apply(Event::Refund { amount: inr(300) }).unwrap();
            assert_eq!(t.state, PaymentState::PartiallyRefunded);
            assert_eq!(t.balance, inr(expected_balance));
            p = Payment {
                state: t.state,
                amount: p.amount,
                balance: t.balance,
            };
        }
        let t = p.apply(Event::Refund { amount: inr(100) }).unwrap();
        assert_eq!(t.state, PaymentState::Refunded);
        assert_eq!(t.balance, inr(0));
    }

    /// The double-refund bug, refused rather than clamped. Clamping would pay
    /// out the difference and call it success.
    #[test]
    fn a_refund_larger_than_the_balance_is_refused() {
        let p = captured(1000);
        let err = p.apply(Event::Refund { amount: inr(1001) }).unwrap_err();
        assert_eq!(
            err,
            LedgerError::RefundTooLarge {
                requested: inr(1001),
                available: inr(1000)
            }
        );
    }

    #[test]
    fn two_partial_refunds_cannot_together_exceed_the_capture() {
        let p = captured(1000);
        let first = p.apply(Event::Refund { amount: inr(600) }).unwrap();
        let after = Payment {
            state: first.state,
            amount: p.amount,
            balance: first.balance,
        };
        assert!(after.apply(Event::Refund { amount: inr(600) }).is_err());
        assert!(after.apply(Event::Refund { amount: inr(400) }).is_ok());
    }

    #[test]
    fn a_zero_refund_is_refused_rather_than_written_as_an_entry() {
        assert_eq!(
            captured(1000)
                .apply(Event::Refund { amount: inr(0) })
                .unwrap_err(),
            LedgerError::ZeroRefund
        );
    }

    /// A second capture would charge the customer twice.
    #[test]
    fn a_captured_payment_cannot_be_captured_again() {
        let p = captured(1000);
        assert!(p
            .apply(Event::AcquirerCaptured { amount: inr(1000) })
            .is_err());
        assert!(p.apply(Event::AcquirerDeclined).is_err());
        assert!(p.apply(Event::AcquirerVoided).is_err());
    }

    #[test]
    fn a_void_resolves_a_pending_payment_without_taking_money() {
        let t = Payment::pending(inr(1000))
            .apply(Event::AcquirerVoided)
            .unwrap();
        assert_eq!(t.state, PaymentState::Failed);
        assert_eq!(t.entry, EntryKind::Void);
        assert!(!t.state.holds_money());
        assert!(t.state.is_resolved());
    }

    #[test]
    fn terminal_states_accept_nothing() {
        for state in [
            PaymentState::Declined,
            PaymentState::Failed,
            PaymentState::Refunded,
        ] {
            let p = Payment {
                state,
                amount: inr(1000),
                balance: inr(0),
            };
            for event in [
                Event::AcquirerCaptured { amount: inr(1000) },
                Event::AcquirerDeclined,
                Event::AcquirerVoided,
                Event::Refund { amount: inr(1) },
                Event::Fail,
            ] {
                assert!(p.apply(event).is_err(), "{state:?} accepted {event:?}");
            }
        }
    }

    /// Only two states mean the customer's money is with us. Getting this wrong
    /// is how a reconciliation report goes quietly wrong.
    #[test]
    fn exactly_the_states_that_should_hold_money_do() {
        assert!(PaymentState::Captured.holds_money());
        assert!(PaymentState::PartiallyRefunded.holds_money());
        assert!(!PaymentState::Pending.holds_money());
        assert!(!PaymentState::Declined.holds_money());
        assert!(!PaymentState::Refunded.holds_money());
        assert!(!PaymentState::Failed.holds_money());
    }

    #[test]
    fn every_state_and_entry_kind_round_trips_through_its_string() {
        for state in [
            PaymentState::Pending,
            PaymentState::Captured,
            PaymentState::Declined,
            PaymentState::PartiallyRefunded,
            PaymentState::Refunded,
            PaymentState::Failed,
        ] {
            assert_eq!(PaymentState::parse(state.as_str()), Some(state));
        }
        assert_eq!(PaymentState::parse("nonsense"), None);
    }
}
