//! Money, as a type the compiler can defend.
//!
//! Every amount in this service is an integer count of minor units — paise,
//! cents — never a float. A float cannot represent 0.1 exactly, and a ledger
//! that is out by a rounding error is a ledger nobody can reconcile.
//!
//! The arithmetic is checked, never wrapping. In release builds Rust wraps on
//! overflow silently, and a wrapped balance is a refund of nine quintillion
//! rupees. Every operation here returns a `Result` instead.

use serde::{Deserialize, Serialize};
use std::fmt;

/// An amount in minor units, tagged with its currency.
///
/// The currency is part of the value rather than a column read separately,
/// so adding rupees to dollars is a compile-time-shaped error (it returns
/// `Err`) rather than a silently wrong number.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Money {
    minor: i64,
    currency: Currency,
}

/// ISO 4217, as much of it as this shop needs.
///
/// Clippy would rather these were `Inr`, `Usd`. They are not names this code
/// invented: they are the spelling the standard, the acquirer and the printed
/// receipt all use, and renaming them to satisfy a lint would put a translation
/// step between this type and every place a currency is written down.
#[allow(clippy::upper_case_acronyms)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Currency {
    INR,
    USD,
    EUR,
    GBP,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum MoneyError {
    #[error("amount overflowed")]
    Overflow,
    #[error("amount would be negative")]
    Negative,
    #[error("currency mismatch: {0} and {1}")]
    CurrencyMismatch(Currency, Currency),
    #[error("unknown currency: {0}")]
    UnknownCurrency(String),
}

impl Currency {
    pub fn code(self) -> &'static str {
        match self {
            // Exhaustive by construction: adding a currency without a code
            // stops compiling here rather than producing an empty string in a
            // receipt.
            Currency::INR => "INR",
            Currency::USD => "USD",
            Currency::EUR => "EUR",
            Currency::GBP => "GBP",
        }
    }

    pub fn parse(code: &str) -> Result<Self, MoneyError> {
        match code {
            "INR" => Ok(Currency::INR),
            "USD" => Ok(Currency::USD),
            "EUR" => Ok(Currency::EUR),
            "GBP" => Ok(Currency::GBP),
            other => Err(MoneyError::UnknownCurrency(other.to_string())),
        }
    }
}

impl fmt::Display for Currency {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.code())
    }
}

impl Money {
    /// A non-negative amount. Money in this system is never negative: a
    /// direction (charge, refund) is the entry's kind, not the sign of its
    /// amount. Signed amounts make "what is the balance" a question about
    /// conventions rather than about addition.
    pub fn new(minor: i64, currency: Currency) -> Result<Self, MoneyError> {
        if minor < 0 {
            return Err(MoneyError::Negative);
        }
        Ok(Money { minor, currency })
    }

    pub fn zero(currency: Currency) -> Self {
        Money { minor: 0, currency }
    }

    pub fn minor(self) -> i64 {
        self.minor
    }

    pub fn currency(self) -> Currency {
        self.currency
    }

    pub fn is_zero(self) -> bool {
        self.minor == 0
    }

    /// Subtraction that refuses to go below zero, rather than wrapping or
    /// producing a negative balance nobody asked for.
    pub fn sub(self, other: Money) -> Result<Money, MoneyError> {
        self.same_currency(other)?;
        let minor = self
            .minor
            .checked_sub(other.minor)
            .ok_or(MoneyError::Overflow)?;
        if minor < 0 {
            return Err(MoneyError::Negative);
        }
        Ok(Money {
            minor,
            currency: self.currency,
        })
    }

    fn same_currency(self, other: Money) -> Result<(), MoneyError> {
        if self.currency != other.currency {
            return Err(MoneyError::CurrencyMismatch(self.currency, other.currency));
        }
        Ok(())
    }
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} {}", self.minor, self.currency)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn inr(n: i64) -> Money {
        Money::new(n, Currency::INR).unwrap()
    }

    #[test]
    fn money_is_never_negative() {
        assert_eq!(Money::new(-1, Currency::INR), Err(MoneyError::Negative));
    }

    #[test]
    fn subtraction_refuses_to_go_below_zero() {
        assert_eq!(inr(100).sub(inr(101)), Err(MoneyError::Negative));
        assert_eq!(inr(100).sub(inr(100)).unwrap(), inr(0));
    }

    /// The reason every operation is checked rather than bare. In release
    /// builds Rust wraps on overflow silently, and a wrapped balance is a
    /// refund of nine quintillion rupees.
    #[test]
    fn subtraction_does_not_wrap() {
        let most_negative_possible = Money::new(0, Currency::INR).unwrap();
        // i64::MIN has no positive counterpart, so `0 - i64::MIN` overflows
        // rather than merely going negative.
        let huge = Money::new(i64::MAX, Currency::INR).unwrap();
        assert_eq!(most_negative_possible.sub(huge), Err(MoneyError::Negative));
        assert!(huge.sub(huge).unwrap().is_zero());
    }

    #[test]
    fn currencies_do_not_mix() {
        let rupees = inr(100);
        let dollars = Money::new(100, Currency::USD).unwrap();
        assert_eq!(
            rupees.sub(dollars),
            Err(MoneyError::CurrencyMismatch(Currency::INR, Currency::USD))
        );
    }

    #[test]
    fn unknown_currency_codes_are_rejected_not_defaulted() {
        assert!(Currency::parse("XYZ").is_err());
        assert_eq!(Currency::parse("INR").unwrap(), Currency::INR);
    }

    #[test]
    fn round_trips_through_its_code() {
        for c in [Currency::INR, Currency::USD, Currency::EUR, Currency::GBP] {
            assert_eq!(Currency::parse(c.code()).unwrap(), c);
        }
    }
}
