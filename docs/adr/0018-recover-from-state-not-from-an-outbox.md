# 18. Recover the saga from its own state, not from an outbox

**Status:** Accepted · **Phase:** 6 · **Amends** [ADR 0015](0015-write-the-intent-before-the-call.md)

## Context

Every release note since Phase 3 has carried the same admission: `order-service`'s saga runs inside
one request, and if the process dies between taking the money and committing the holds, the holds
expire on their own — so the stock comes back — but **the refund never happens**. The only thing
that found those orders was a person running a SQL query out of
[a runbook](../runbooks/order-stuck-or-wrong.md).

[ADR 0015](0015-write-the-intent-before-the-call.md) said the fix was an outbox, by analogy with
`payment-service`, which writes an intent row before calling the acquirer.

## Decision

A scheduled recovery scan over order state. **No outbox table.**

The analogy with `payment-service` does not hold, and following it would have been ceremony. An
outbox exists to record an intention that is otherwise nowhere on disk — which is exactly
payment-service's problem: until the intent row is written, a charge at the acquirer has no
counterpart in this system at all.

Here the intention is already stored, in full. An order in `PAID`, with a payment reference and no
dispatch window, **is** the record of "money taken, work unfinished". A parallel outbox row would
duplicate the order row and then have to be kept consistent with it — a second source of truth for
a fact the first one already states.

What was missing was never the record. It was something to read the record and act on it.

Two ways to be stuck, and they need different answers:

| State | What happened | What recovery does |
|---|---|---|
| `PAID` | Money taken and recorded, holds not committed | Finish the saga: commit, or refund if the holds have since expired |
| `STOCK_RESERVED` | Died during authorisation, so whether the money moved is unknown | Ask payment-service. Captured → finish. Not taken → release the holds and fail. **Still unknown → hand it to `PAYMENT_UNRESOLVED`** and let the reconciler own it |

That last row is the one worth pointing at: the recovery does not guess. An answer it cannot get
goes to the state that already exists for exactly that answer
([ADR 0014](0014-unknown-is-not-failure.md)).

## Consequences

The most expensive failure this system can produce — money taken for an order that never ships and
nobody notices — is now handled by the system rather than by a runbook. Demonstrated with a real
`SIGKILL` mid-checkout, not a simulated one: the order sat `PAID` with its hold uncommitted and no
process alive, and came back `CONFIRMED` after a restart with nobody touching it.

**Cost: another load-bearing scheduled job.** That is now three — the payment reconciler, this, and
payment-service's own — against two that are pure bookkeeping (the reaper, the dispatch watcher).
The distinction still holds and is still worth stating: stopping this one *delays* an outcome,
because every order it touches is already in a state that is correct and merely unfinished. It
cannot corrupt one. `orders_stuck` is the gauge that has to come back to zero.

**Cost: a threshold to get wrong.** `stuck-after-ms` must exceed the slowest checkout that could
still be in flight, or the recovery races the request that is already finishing the job. Two
minutes, against a checkout that measures in hundreds of milliseconds.

**An outbox still earns its place later.** When this service starts publishing domain events to
other systems, a published event genuinely has no other home, and the argument in
[ADR 0015](0015-write-the-intent-before-the-call.md) applies unchanged. That is the messaging phase.
This decision narrows 0015 to the case it was actually about; it does not overturn it.

## A note on how the gap was closed

The test simulates the death by rewinding an order to the state a crash leaves and ageing the row —
the state on disk is identical either way, which is the whole reason the saga commits each step
separately. But the demonstration used an actual `kill -9` against an actual in-flight checkout,
because a test that only ever exercises a simulated crash proves the simulation.
