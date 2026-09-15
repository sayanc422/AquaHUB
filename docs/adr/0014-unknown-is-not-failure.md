# 14. An unknown payment outcome is a state, not a failure

**Status:** Accepted · **Phase:** 4

## Context

A payment provider can answer three ways: it took the money, it refused, or **it did not answer**.
The third is not rare and it is not a degenerate case of the second.

Before this phase, `order-service` had two branches. A provider that timed out would have gone down
the decline branch: release the holds, mark the order `PAYMENT_FAILED`, tell the customer their card
was refused. If the money had in fact been taken — which is exactly what happens when an acquirer
charges and then fails to answer — the shop would have sold the stock to somebody else while holding
a customer's money and telling them nothing happened.

The opposite guess is no better: confirming an order that may never have been paid for ships
livestock for free.

## Decision

Model the unknown as a state, in both services, and never collapse it into either neighbour.

- `payment-service` writes the intent **before** calling the acquirer, leaves the payment `pending`
  when the acquirer does not answer, and returns **504** — not 500, because 500 invites a caller to
  treat it as a failure and move on.
- `order-service` has `PAYMENT_UNRESOLVED`. Its only exits are `PAID` and `PAYMENT_FAILED`: there is
  deliberately no route to `CANCELLED`, because cancelling is the guess the state exists to avoid.
- **The holds are not released on the way in.** Releasing is a decision that the payment failed.
  They expire on their own within the TTL, which returns the stock without anybody having decided
  anything — [ADR 0008](0008-availability-is-computed-from-the-deadline.md) paying for itself in a
  case it was not designed for.
- Both services resolve by asking, using the idempotency key: `GET /v1/payments/by-key/{key}`.

A client-side timeout is treated identically to a 504, because it means the same thing: we stopped
waiting, which tells us nothing about whether the charge happened.

## Consequences

The expensive mistake is unreachable rather than unlikely. An order is never told its payment failed
while the money is gone, and never confirmed while the payment is unknown.

**Cost: two reconcilers that are load-bearing**, which is a real departure from
[ADR 0011](0011-derived-state-over-stored-state.md). The reaper and the dispatch watcher can be
stopped with no consequence; stop these and orders sit unresolved forever. The difference is not
carelessness — resolving requires *asking another party*, and no schema design makes that derivable
from a clock.

What survives of the principle is the safety property: an unresolved payment is never counted as
money taken and never has its stock released, so a stopped reconciler delays the answer rather than
producing a wrong one. Both services expose the gauge that must return to zero
(`payment_pending`, `orders_payment_unresolved`), and those are the alerts.

**Cost: a state customers will see.** "We are checking with your bank" is a worse experience than a
straight yes or no. It is also the truth, and the alternative is a confident answer that is
sometimes wrong about money.
