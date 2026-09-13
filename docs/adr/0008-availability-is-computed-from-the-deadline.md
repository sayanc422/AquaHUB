# 8. Availability is computed from the hold deadline, not from a reaper

**Status:** Accepted · **Phase:** 2

## Context

`inventory-service` holds stock for orders that have not been paid for. Every hold has a TTL. The
obvious implementation is a background job that sweeps expired holds and returns their stock.

That design makes the background job load-bearing. If it stops, stock is stranded — fish nobody can
buy and no customer is waiting for. If it runs twice concurrently, the sweep and a commit race for
the same rows. The health of the shop's stock then depends on the health of a cron.

## Decision

Availability is a query, and the deadline is in the query:

```sql
quantity_on_hand - COALESCE(SUM(quantity) FILTER (
    WHERE state = 'held' AND expires_at > now()), 0)
```

A hold stops holding stock at the instant it expires. A reaper still runs, but only to make the
`state` column say what is already true, to keep the `inventory_active_holds` gauge honest, and to
give a support question ("what happened to this hold?") an answer that is not arithmetic on a
timestamp.

## Consequences

The reaper is not load-bearing. Stopped, slow, or running in all three replicas at once, it cannot
double-sell or strand stock — the worst it can do is leave a column stale. That is what makes it
safe to run in every replica with no leader election, no distributed lock and no singleton
deployment.

`GET /v1/reservations/{id}` applies the same rule in Go, so a hold past its deadline reads as
`expired` even before the reaper has been round. The API never reports a hold that availability has
already stopped honouring.

**Cost:** every availability read pays for the aggregate over `reservation_line`. A partial index
on held rows keeps it small, but at a stock level far above this shop's, a materialised
per-tank counter maintained in the same transaction would be the next step — and it would
reintroduce exactly the correctness problem this decision avoids.

Verified by `TestExpiredHoldReleasesStockWithNoReaperRun`, which never calls the reaper.
