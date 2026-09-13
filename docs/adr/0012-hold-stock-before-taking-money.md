# 12. Hold stock before taking money

**Status:** Accepted · **Phase:** 3

## Context

Checkout has to do two things that can each fail: secure the stock, and take the money. They can be
done in either order, and no distributed transaction is available to do both at once.

## Decision

Reserve first, authorise second, commit third.

The two orderings fail differently, and the difference is entirely about who pays for the failure:

| | Reserve then pay | Pay then reserve |
|---|---|---|
| Card declined | Hold released. Customer sees "declined", tries another card. | — |
| Stock gone | Customer sees "out of stock" before paying. | Customer has been charged for something that does not exist. Refund, apology, support ticket. |
| Both fine | Identical. | Identical. |

The second column is simpler to implement — no compensation on the stock side — and it moves the cost
of every failure onto the customer.

## Consequences

The expensive path shrinks to one case: payment succeeds and the hold has expired before the commit.
The saga refunds and the order ends in `REFUNDED`, which says by name what happened. That path is
reachable in practice only if the customer takes longer than the 15-minute hold TTL between
authorisation and commit, which is why the TTL is a business decision rather than a technical one.

There is no transition from `PAID` to `PAYMENT_FAILED`. Once money is taken, the only way out is a
refund; an order in `PAYMENT_FAILED` with the customer's money in the account is the worst state the
system could produce, so the state machine makes it unreachable rather than merely unlikely.

**Cost:** stock is held for customers who will not complete, which is real inventory taken out of the
shop — worse for livestock, where the tank is the constraint. The TTL bounds it, and the release on
decline returns it immediately rather than fifteen minutes later.

**Cost:** the saga now needs a compensation on the stock side, and every compensation must be
idempotent, must not be enrolled in a transaction that is about to roll back, and must not replace
the original failure with one of its own. That is three rules that a pay-first design never has to
get right.
