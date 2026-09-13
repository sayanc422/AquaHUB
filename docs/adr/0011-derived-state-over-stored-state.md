# 11. Derived state over stored state, wherever a clock can answer

**Status:** Accepted · **Phase:** 3 (generalises [ADR 0008](0008-availability-is-computed-from-the-deadline.md))

## Context

Phase 2 established that a hold stops holding stock when its deadline passes, because the deadline is
in the availability query rather than in a column a job keeps current. Phase 3 met the same shape of
problem again: a confirmed order may not ship until its dispatch window opens, days later.

The obvious design is a state — `AWAITING_DISPATCH` — and a scheduled job that moves orders out of it
when their time comes. It is also the design that makes a cron load-bearing for the business: if the
job stops, paid orders sit unshippable with nothing wrong with them, and the failure is invisible
until a customer asks.

## Decision

Whenever the answer is a function of the clock and data already stored, compute it; do not store it
and do not schedule something to maintain it.

- `inventory-service`: availability subtracts holds `WHERE expires_at > now()`.
- `order-service`: `dispatchable` is `state = CONFIRMED AND now() >= dispatch_at`. There is no
  `AWAITING_DISPATCH` state and no `READY_TO_SHIP` state.

Both services still run a background job — a reaper, a dispatch watcher — and in both cases the job
is deliberately *not* load-bearing. It marks rows, moves a gauge and gives the notification service
something to react to. If it stops, nothing is late and nothing ships early.

## Consequences

The correctness of stock and of dispatch does not depend on the health of a scheduler. Both jobs can
run in every replica with no leader election, no distributed lock and no singleton deployment,
because the worst two of them can do together is perform the same harmless write twice.

It also makes the tests honest: `TestExpiredHoldReleasesStockWithNoReaperRun` never calls the reaper,
and `aConfirmedOrderIsDispatchableOnlyOnceItsWindowOpens` never runs the watcher.

**Cost:** the derived value is computed on every read, so it cannot be indexed directly, and a query
that filters on it needs a predicate over `dispatch_at` (which can be indexed) rather than over a
state column. At a volume far above this shop's, that flips: a stored, maintained state column with a
covering index is faster, and buying that speed means taking on exactly the correctness problem this
decision avoids. The point at which it is worth it is a measurement, not a guess, and this project has
not measured it.

**Second cost:** "what state is this order in?" now has two answers — the stored `state` and the
derived `dispatchable` — and an API that returned only the first would be lying by omission. Both are
in the response for that reason.
