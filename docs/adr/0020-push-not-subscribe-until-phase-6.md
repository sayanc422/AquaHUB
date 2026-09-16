# 20. notification-service is pushed to, not subscribed via NATS, until Phase 6

**Status:** Accepted · **Phase:** full-app profile (pre-6)

## Context

[ADR 0011](0011-derived-state-over-stored-state.md) already settled what notification-service's
relationship to the rest of the system should be: the dispatch watcher "marks rows, moves a gauge
and gives the notification service something to react to. If it stops, nothing is late and nothing
ships early." `DispatchWatcher`'s own javadoc went further and named the mechanism — "records the
moment for the notification service to pick up **in Phase 6**" — because the intended long-term
design is a NATS subscription: `order-service` publishes domain events, notification-service
consumes them, and neither has to know the other is up.

NATS does not exist in this cluster yet. It is explicitly Phase 6 work
([context_summary.md](../context_summary.md)), and the `commerce` profile already runs without it.
Making `full-app` wait for Phase 6 would mean two new services with no way to reach one another —
not a smaller version of the design, just a broken one.

## Decision

`order-service` calls `notification-service` directly over HTTP, at the two moments it already
knows something happened: when an order reaches `CONFIRMED`
(`CheckoutSaga`, both the direct-checkout and resume/recovery paths), and when `DispatchWatcher`
marks an order's dispatch window open. Both calls are fire-and-forget — bounded timeout, every
exception caught, nothing thrown — via `NotificationClient`, toggled `noop` (default, used by `core`
and `commerce`) or `http` (set only by the `full-app` profile).

`notification-service` records what it's told in its own `outbox` table (database `notify`) and
delivers from there, with per-target retry. The retry lives entirely on the delivery side, not the
ingest side: once a row exists, `notification-service` owns getting it out; nothing upstream is ever
asked to resend an event it already fired once.

## Consequences

**This is not the Phase 6 design, and it does not pretend to be.** It is a stand-in for the exact
seam ADR 0011 already described, built so `full-app` can exist before NATS does. When NATS arrives,
`notification-service` becomes a subscriber instead of an HTTP server, `HttpNotificationClient` and
`NoopNotificationClient` are deleted, and the `outbox` table's producer changes — its consumer side
(per-target delivery and retry) does not, because that part was never the missing piece.

**Cost: an ingest-call failure loses that notification, permanently, with nothing to retry it.**
If `order-service` cannot reach `notification-service` — it's down, mid-rollout, or the call simply
times out — the event never becomes a row in the `outbox` table, and nothing tries again. This is a
real regression from what a broker would give: NATS would hold the message until a consumer is
available; a synchronous HTTP push with a swallowed failure does not. It is accepted, not overlooked,
because ADR 0011 already established that the cost of this entire path being unavailable is "the
worst it can do is fail to send an email" — a lost confirmation email is the accepted failure mode,
not a silent one, since `HttpNotificationClient` logs every failure it swallows.

**Cost: two places in `order-service` now know about notification-service**, however thinly
(`CheckoutSaga` and `DispatchWatcher`). Both go away entirely once Phase 6 replaces the push with a
subscription — this ADR's `Consequences` section is also its own removal plan.

**Cost: `DispatchWatcher.scan()` could no longer stay `@Transactional`.** Firing a notification
inside the same transaction that marks the dispatch gauge would let a slow or down
notification-service block (or, worse, through Spring's proxy-bypass-on-self-invocation trap, appear
to roll back) the one write this job must always make. The transactional write now lives in
`OrderSteps.markDispatchable`, a separate bean, and `scan()` only fires notifications after that
transaction has committed — the same reasoning that already put the saga's steps in `OrderSteps`
rather than `CheckoutSaga` itself.
