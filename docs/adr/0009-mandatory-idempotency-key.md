# 9. `Idempotency-Key` is mandatory on reservations and bound to a request digest

**Status:** Accepted · **Phase:** 2

## Context

`order-service` calls `POST /v1/reservations` during checkout. That call will be retried — by the
HTTP client on a timeout, by the saga on a step failure, by a customer double-clicking. A
reservation is not naturally safe to repeat: the second call holds a second set of fish.

## Decision

`Idempotency-Key` is a **required** header, not an optional one. The key is stored with a SHA-256
digest of the canonical request (`orderRef`, `sku`, `quantity`, TTL), under a unique index.

- Same key, same request → `200` with the original reservation. The status code differs from the
  `201` of a fresh reservation, so a caller can tell its own echo from a new hold.
- Same key, different request → `409 idempotency_key_reused`. A key reused for a different intent is
  a client bug, and silently returning the old reservation would hide it.
- A *refused* reservation rolls back its key with the transaction, so a customer who reduces the
  basket and retries with the same key — as every sane client does — succeeds.

Uniqueness is enforced by Postgres, not by a read-then-write in Go: two concurrent retries race to
`INSERT`, and exactly one wins. The insert uses `ON CONFLICT DO UPDATE`, not `DO NOTHING`, because
`DO NOTHING` returns no row when the conflicting insert is still uncommitted in another transaction
and the follow-up `SELECT` cannot see it either — the retry would look like a lost key. `DO UPDATE`
takes the row lock and waits, so the loser of the race always ends up holding the winner's row.

## Consequences

A retry storm cannot double-book a fish, and it cannot do so under concurrency rather than merely
in the happy path.

**Cost:** a required header is a breaking change for any client that has not been told. The digest
is over a canonical form rather than the raw bytes, so a proxy that reformats JSON does not produce
a spurious conflict — at the cost of the digest not covering fields added later unless they are
added to the canonical form too. That is a maintenance obligation on whoever extends the request.
