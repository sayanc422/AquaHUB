# 15. Write the intent before the external call, not after

**Status:** Accepted · **Phase:** 4 · **Generalises** [ADR 0013](0013-record-external-effects-outside-the-transaction.md)

## Context

[ADR 0013](0013-record-external-effects-outside-the-transaction.md) came from a bug: reserving every
line in one transaction meant a rollback erased the record of holds that already existed in another
service. The fix was to commit the record of each effect as soon as it happened.

That narrowed the window. It did not close it: between the other service committing its work and
this service committing its row, a process death still loses the record.

`payment-service` faced the same shape of problem with more at stake, because the effect is a charge.

## Decision

Write the intent **before** the call, not the outcome after it.

```
1. INSERT payment (state = 'pending')   -- committed
2. call the acquirer
3. UPDATE payment (state = 'captured' | 'declined')  + ledger entry, in one transaction
```

A crash anywhere after step 1 leaves a `pending` row that names the acquirer reference used. That
row is the only thing that makes the charge findable afterwards, and the reconciler turns it into an
answer.

The ordering also has to be safe at step 3, where two resolvers can race — the caller retrying and
the reconciler on its timer. The update is conditional (`WHERE state = 'pending'`), so the loser
writes nothing rather than appending a second capture for one charge.

## Consequences

There is no window in which a charge exists with no record of it having been attempted. A service
that charges first and records afterwards has exactly that window on every request.

This is the outbox pattern in the small: intent recorded first, effect second, reconciliation third.
`order-service`'s saga still lacks it — a death between taking the money and committing the holds
loses the refund — and that is Phase 6, with NATS carrying the retries.

**Cost:** two round trips to Postgres where a charge-then-record design has one, and a table that
accumulates `pending` rows for payments that never resolved. The partial index on
`state = 'pending'` keeps the reconciler's scan cheap regardless of how many settled payments sit
beside them.

**Cost:** the `pending` state is visible in the API and every consumer must understand it. That is
the point — a state that is quietly filtered out of responses is one nobody handles.
