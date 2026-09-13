# inventory-service

Holds stock in physical tanks on behalf of orders that have not been paid for yet.

The whole service is one idea: **a promise about stock is time-bounded.** Nothing here can hold a
fish indefinitely, and no background job has to be healthy for that to be true.

## Why Go

Many small concurrent hold and expire operations, a ~40 MB resident footprint, and a service whose
load scales with request count rather than working-set size. The parts that are genuinely hard here
are transactional, not computational, so the language choice is about footprint and concurrency
ergonomics, not speed.

## The model

| Term | Meaning |
|---|---|
| **Tank** | One piece of physical glass. Stock is per tank, never one integer per SKU — a shop floor is not a warehouse bin. |
| **Hold** | A time-bounded claim on stock across one or more tanks. Subtracts from availability; does not remove fish from the tank. |
| **Commit** | The sale. Stock leaves the tank. |
| **Release** | The hold is given back early: abandoned cart, failed payment. |
| **Expiry** | The hold's deadline passes. Stock returns with nobody doing anything. |

### The rule that makes this safe

Availability is computed as `quantity_on_hand − Σ holds WHERE state = 'held' AND expires_at > now()`.

The deadline is in the query. So an expired hold stops holding stock at the instant it expires, not
when a background job notices. The reaper (`REAPER_INTERVAL`, default 30 s) only makes the `state`
column say what is already true and keeps the `inventory_active_holds` gauge honest.

That is what makes the reaper safe to run in every replica: a stopped, slow or crash-looping reaper
cannot double-sell or strand stock. It can only make a column stale.

### Idempotency

`Idempotency-Key` is **required** on `POST /v1/reservations`. A reservation is not safe to repeat,
the network will repeat it, and a caller that has not chosen a retry key has not thought about
double-booking a fish.

- Same key, same request → 200 with the original reservation (not 201).
- Same key, different request → 409 `idempotency_key_reused`.
- A *refused* reservation (insufficient stock) rolls back its key, so the customer can reduce the
  basket and retry with the same key.

### Allocation

Best-fit, then largest-first: if one tank can cover the order, use the **smallest** such tank —
livestock from one tank ships as one bag. Otherwise split largest-first so the order touches as few
tanks as possible. Quarantined tanks are visible in the stock endpoint and never allocated from.

**Cost:** best-fit fragments stock. Many small orders leave many tanks with a few fish each.

## API

| Method | Path | Notes |
|---|---|---|
| `POST` | `/v1/reservations` | Requires `Idempotency-Key`. 201 created, 200 replay, 409 insufficient/conflict |
| `GET` | `/v1/reservations/{id}` | A hold past its deadline reads as `expired` even before the reaper has been round |
| `POST` | `/v1/reservations/{id}/commit` | Idempotent. 409 `reservation_expired` if the deadline passed |
| `POST` \| `DELETE` | `/v1/reservations/{id}` `/release` | Idempotent. 409 if already committed — reversing a sale is a refund, and refunds belong to `payment-service` |
| `GET` | `/v1/stock/{sku}` | Per tank: on hand, held, available |
| `GET` | `/healthz` `/readyz` `/metrics` | Liveness does **not** touch Postgres; readiness does |

Not exposed through the ingress. `order-service` calls it; customers never do.

## Running the tests

Unit tests (allocation rules, idempotency digest) need nothing:

```bash
go test ./...
```

The store tests need a real Postgres, because what they assert — row locks, the unique index, the
`quantity_on_hand >= 0` CHECK — only exists in Postgres. A mock that returns what the test expects
would prove the mock. They skip when `INVENTORY_TEST_DSN` is unset:

```bash
export INVENTORY_TEST_DSN='postgres://postgres@127.0.0.1:5432/inventory_test?sslmode=disable'
go test -race ./...
```

`TestConcurrentReservationsCannotOversell` is the one that earns its keep: twenty goroutines race
for eight fish, two at a time, and exactly four may win. It failed against the first version of
`Reserve`, which locked the tanks and read their availability in one `SELECT ... FOR UPDATE` — see
the comment in `internal/store/store.go` for why that is wrong under READ COMMITTED.

## Configuration

| Variable | Default | |
|---|---|---|
| `DATABASE_URL` | — | Or `DB_HOST`/`DB_USER`/`DB_NAME`/`DB_PASSWORD`/`DB_PORT`/`DB_SSLMODE` |
| `PORT` | `8081` | |
| `RESERVATION_TTL` | `15m` | Default hold window |
| `RESERVATION_MAX_TTL` | `2h` | Ceiling a caller may request |
| `REAPER_INTERVAL` | `30s` | Bookkeeping only |
| `DB_POOL_MAX` | `8` | |
| `SHUTDOWN_GRACE` | `15s` | Below the pod's `terminationGracePeriodSeconds` |
