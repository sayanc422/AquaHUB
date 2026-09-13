# 13. An effect in another service must be recorded outside the transaction that may roll back

**Status:** Accepted · **Phase:** 3

## Context

`order-service` reserves one hold per SKU. The first implementation did all of them inside a single
`@Transactional` method: load the order, call inventory-service for each line, add each reservation to
the order, save.

The test `aPartlyReservedOrderReleasesTheHoldsItAlreadyTook` failed against it. When the third line was
refused, the transaction rolled back — and rolled back the rows recording the first two holds, which
by then *existed in inventory-service*. The compensation loaded the order, found no reservations, and
released nothing. Real stock sat held until its TTL expired.

The bug is not a missing null check. It is a category error: a database transaction was being treated
as though it covered work that had already happened somewhere else.

## Decision

Each line is reserved in its own `REQUIRES_NEW` transaction, which commits the record of the hold
immediately after the call that created it.

A saga's memory of what it has done is the only thing its compensation has to work from. So: an
effect in another service is not covered by your transaction, and the record of it must be committed
as soon as it happens, never inside a transaction that might still roll back.

The same reasoning is why `releaseAll` is `REQUIRES_NEW` and swallows its own failures: a compensation
runs when something has already gone wrong, so it must not be enrolled in a transaction that is about
to roll back, and it must not replace the original failure with one of its own.

## Consequences

A partial reservation is now recoverable: the holds that were taken are on disk, and the compensation
releases them.

**The window is narrower, not gone.** If the process dies between inventory-service committing the
hold and this transaction committing the row, the hold is orphaned. Two things limit the damage: it
expires by itself within the TTL, and a retry presents the same idempotency key and is handed the
same reservation back — which is exactly why that key is derived from the order and the SKU rather
than generated per attempt ([ADR 0009](0009-mandatory-idempotency-key.md)).

Closing the window properly means writing the intent *before* the call (an outbox), and that is
Phase 6, with NATS.

**Cost:** one transaction per line instead of one per checkout, so a five-line order is five
round-trips to Postgres rather than one. Measured at 107 ms for a whole failed checkout — two
reservations, two releases and five persisted transitions — so the cost is not the constraint at this
scale.

## A note on how this was found

By a test that asserted a compensation happened, not by review. The code looked right; `@Transactional`
on a method that reserves stock reads as careful rather than as a mistake. It is worth writing the test
that can fail before believing the code.
