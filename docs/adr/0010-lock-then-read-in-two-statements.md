# 10. Lock tank rows and read availability in two statements

**Status:** Accepted · **Phase:** 2

## Context

Two customers reserving the last fish at the same moment must not both succeed. The first version
of `Reserve` locked the tanks and read their availability in one statement:

```sql
SELECT t.id, t.code, t.quantity_on_hand - (SELECT SUM(...)) AS available
  FROM tank t WHERE t.sku = $1 AND t.status = 'open'
 ORDER BY t.id FOR UPDATE OF t
```

It oversold. `TestConcurrentReservationsCannotOversell` — twenty goroutines racing for eight fish,
two at a time — let seven through instead of four.

The reason is the READ COMMITTED snapshot rule. A statement's snapshot is taken when the statement
*begins*, which is before it blocks on a row lock. The second transaction waits for the first to
commit, acquires the tank lock, and then reports availability from a snapshot taken before the
first transaction inserted its `reservation_line` rows. The lock was held correctly; the number it
protected was already stale.

## Decision

Take the locks in one statement, read availability in a second:

```sql
SELECT id FROM tank WHERE sku = $1 AND status = 'open' ORDER BY id FOR UPDATE;
SELECT id, code, <availability> FROM tank WHERE id = ANY($1) ORDER BY id;
```

The second statement takes a fresh snapshot, after the lock is granted, so it sees everything the
transaction it waited for committed. It reads only the ids actually locked: a tank inserted for
this SKU between the two statements is not covered by the locks, and allocating from it would
reopen the same race on a new row.

`ORDER BY id` makes the lock order total, so two reservations overlapping on two tanks cannot
deadlock. The tank row is the concurrency unit even though this transaction never updates it — it is
the row that names the resource being promised.

## Consequences

Reservations for one SKU serialise on that SKU's tanks. Different SKUs do not contend at all.

**Cost:** one extra round trip per reservation, and a hot SKU serialises on its tank rows. Measured
against a local Postgres, a reservation takes ~2.5 ms and 39 of 40 completed under 5 ms, so the
round trip is not the constraint at this scale. `SERIALIZABLE` would remove the explicit lock and
the extra statement at the price of retry loops on every caller, which is a worse contract for
`order-service` to hold.

The alternative worth naming: a `CHECK (quantity_on_hand >= 0)` alone does not solve this, because
a hold does not change `quantity_on_hand`. The constraint catches a bad *commit*; only the lock
prevents a bad *promise*.
