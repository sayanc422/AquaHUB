# Release notes

Newest first. Each entry says what was built, **what was measured**, and what is still unproven.
A number that has not been measured is written as a target and labelled as one.

---

## Phase 3 — `order-service`

Cart, the order state machine, the checkout saga with compensation, and livestock dispatch windows.
Java 21 / Spring Boot.

### The saga

```
  1. reserve    one hold per SKU in inventory-service    compensate: release
  2. authorise  take the money                           compensate: refund
  3. commit     turn every hold into a sale              compensate: refund
  4. confirm    fix the dispatch window                  --
```

**The ordering is the design.** Stock is held before money is taken, so a declined card costs a
released hold rather than a refund and an apology ([ADR 0012](docs/adr/0012-hold-stock-before-taking-money.md)).
There is no transition from `PAID` to `PAYMENT_FAILED`: once money is taken, the only way out is a
refund that says so by name.

### The bug worth reporting

The first implementation reserved every line inside one `@Transactional` method.
`aPartlyReservedOrderReleasesTheHoldsItAlreadyTook` failed against it: when the third line was
refused, the rollback erased the rows recording the first two holds — which by then **existed in
inventory-service** — so the compensation found nothing to release and real stock sat held until its
TTL expired.

A database transaction does not cover work that has already happened in another service. The record
of an external effect has to be committed as soon as it happens
([ADR 0013](docs/adr/0013-record-external-effects-outside-the-transaction.md)). The window is now
narrower rather than closed; an outbox closes it, and that is Phase 6.

Found by a test that asserted a compensation happened, not by review. `@Transactional` on a method
that reserves stock reads as careful rather than as a mistake.

### A platform defect found on the way

The `ResourceQuota` counted `limits.cpu`, which makes an explicit CPU limit **mandatory** on every
container; the `LimitRange` then supplied a default of `500m`. So every JVM service was being
CFS-throttled — exactly what [ADR 0006](docs/adr/0006-memory-limits-but-no-cpu-limits.md) exists to
prevent — by way of the namespace rather than the deployment, where nobody would look. The symptom
would have been latency spikes on an idle-looking node.

### Verified live, both services running together

A real `order-service` against a real `inventory-service` and a real Postgres:

```
happy path     6 neon tetra + 4 panda cory -> CONFIRMED, dispatchAt 2026-09-14T08:30Z
               stock: 70 -> 64 and 27 -> 23 available, on hand down by the same
               (committed: the fish have left the tank)

declined card  10 neon tetra + 5 panda cory -> PAYMENT_FAILED
               paymentRef null, both reservations RELEASED
               stock: 64 and 23, unchanged -- returned immediately, not in 15 minutes
```

The order's event trail shows the compensation, which is visible nowhere else:

```
-               -> PENDING          order created from cart 57e680e2...
PENDING         -> STOCK_RESERVED   2 hold(s), ttl 900s
STOCK_RESERVED  -> STOCK_RESERVED   released hold 3d904285... (payment declined)
STOCK_RESERVED  -> STOCK_RESERVED   released hold e25990b3... (payment declined)
STOCK_RESERVED  -> PAYMENT_FAILED   card declined (stub gateway configured to decline)
```

That is the phase's acceptance criterion: **an order that survives a payment failure without
stranding stock.**

### Measured

Local Postgres on the build container, **not k3d**.

| | |
|---|---|
| Whole failed checkout (2 reservations, 2 releases, 5 persisted transitions) | 107 ms |
| Checkout requests, mean | 69 ms (7 requests, including first-call JIT warm-up; max 193 ms) |
| `order-service` resident memory | 361 MiB, **with no cgroup limit** — the JVM sized its heap from host RAM |
| `inventory-service` alongside it | 14 MiB |
| Tests | 32: 18 domain, 6 HTTP client, 8 saga against a real Postgres |

### Dispatch windows

Livestock leaves Monday, Tuesday or Wednesday only, before a 14:00 cut-off in the shop's local time;
a bag posted on Thursday sits in a depot over the weekend. So an order placed Thursday afternoon is
confirmed, paid for, and waiting for Monday — a state no event will end, only the clock.

`dispatchable` is derived (`now() >= dispatch_at`), never stored, and there is no `AWAITING_DISPATCH`
state. The dispatch watcher marks the moment for the notification service and is not load-bearing —
the same rule as the reaper ([ADR 0011](docs/adr/0011-derived-state-over-stored-state.md)).

### Still unproven

- **Never run in k3d.** Two JVMs, Postgres and a Go service together is what the commerce profile now
  asks of an 11 GB budget, and that has not been tried.
- **The saga is not crash-safe.** If the process dies between taking the money and committing the
  holds, the holds expire by themselves — so the stock returns — but the refund never happens. Only
  the event trail would show it. Phase 6, with an outbox and NATS.
- `payment-service` does not exist; the stub has no ledger, no idempotency of its own, and no outcome
  between approved and declined. Nothing here shows the saga surviving a payment provider *timing
  out*, which is the failure a real one is mostly designed around.

---

## Phase 1 verification — the services were run for the first time

Phase 1 had been written, reviewed and committed, and never executed. Running it found two defects
that would have crash-looped `catalog-service` on its first boot in the cluster. Both were found by
`ddl-auto: validate`, which is the setting's entire purpose.

### Defect 1 — `currency CHAR(3)` against a `String` field

Hibernate: *wrong column type encountered in column [currency]; found [bpchar], but expecting
[varchar(3)]*. The column is now `VARCHAR(3)`. `CHAR` is blank-padded in Postgres, which makes
comparison and trimming a source of surprise, and buys nothing over a length-limited `VARCHAR`.

### Defect 2 — `NUMERIC(4,1)` water parameters against `double` fields

Hibernate: *found [numeric], but expecting [float(53)]*. The first attempt at a fix — adding
`precision`/`scale` to the `double` fields — was refused outright: *"scale has no meaning for SQL
floating point types"*. That error is the mapping telling the truth. An exact column needs an exact
field, so the seven measurements on `SpeciesProfile` are now `BigDecimal`, converted to plain
numbers in the DTO so the published JSON is unchanged.

It matters beyond the boot failure: `aquatics-advisor` computes interval overlap across every
inhabitant of a tank, and a 0.1 step that is not exactly 0.1 turns "6.8 is within 6.8–7.5" into a
coin toss at the boundary.

### Defect 3 — `inventory-service` seeded SKUs that do not exist

The Phase 2 tank seed used invented SKUs (`FSH-NEON-TETRA`) and a comment claiming they matched
`catalog-service`. They did not. They are now the catalog's own (`FSH-NEO-01`), verified against its
seed data. The SKU string is the entire contract between the two services — no shared schema, no
shared database, no foreign key — so a drift would have shown the customer a product that could not
be reserved, with nothing in either database to say why.

### Measured

Against local Postgres 16, on the build container, **not in k3d**.

| | |
|---|---|
| `catalog-service` time to readiness | 5.8 s (startup probe allows 150 s) |
| `catalog-service` resident memory | 338 MiB — but with **no cgroup limit**, so the JVM sized its heap from 16 GB of host RAM. This is not what it would use under the 640Mi limit, and is not evidence the limit is right. |
| `storefront` resident memory | 76 MiB |
| Flyway | 2 migrations applied to an empty database, clean |
| Catalog API | categories, category listing, product detail with care profile, and search all answer correctly |
| Storefront | home, category and product pages render server-side against the live catalog |

### Verified by hand: the liveness/readiness split

With `catalog-service` stopped:

```
/healthz  (liveness)  200   <- the pod is healthy; Kubernetes must not restart it
/readyz   (readiness) 503   <- the pod leaves the Service endpoints
/         (page)      502
```

That is the behaviour the design claimed and had never demonstrated: a catalog outage degrades the
page, and does not turn a partial outage into a restart loop across every storefront replica.

### Still unproven

Neither service has run in k3d. Probes, resource limits, the ingress and the TLS path are written
and reviewed, not exercised.

---

## Phase 2 — `inventory-service`

Tank-scoped, TTL-bounded, idempotent stock reservations. Go, Postgres, distroless.

### What it does

Holds stock in physical tanks for orders that have not been paid for yet. A hold subtracts from
what may be sold and does not remove fish from the glass; it is committed into a sale, released
early, or it simply expires.

### The idea the service is built around

A promise about stock is time-bounded, and **no background job has to be healthy for that to be
true.** Availability is computed as

```
quantity_on_hand − Σ holds WHERE state = 'held' AND expires_at > now()
```

so an expired hold stops holding stock at the instant it expires. The reaper only makes the `state`
column honest and keeps the active-holds gauge current. Stopped, slow, or running in all three
replicas at once, it cannot double-sell or strand stock
([ADR 0008](docs/adr/0008-availability-is-computed-from-the-deadline.md)).

### The bug worth reporting

The first version of `Reserve` locked the tank rows and read their availability in one
`SELECT ... FOR UPDATE`. It oversold, and the concurrency test caught it: twenty goroutines racing
for eight fish, two at a time, and seven got through instead of four.

Under READ COMMITTED a statement's snapshot is taken when the statement begins — **before** it
blocks on the row lock. The waiting transaction acquires the lock correctly and then reads
availability from a snapshot taken before the transaction ahead of it inserted its lines. The lock
was right; the number it protected was stale. The fix is to lock in one statement and read in a
second, whose fresh snapshot includes the committed work
([ADR 0010](docs/adr/0010-lock-then-read-in-two-statements.md)).

This is the kind of defect that does not appear in a demo, does not appear in a single-threaded
test, and appears in production as an angry customer.

### Measured

Against a local Postgres 16 on a build container — **not in k3d, and not under sustained load.**
Order of magnitude, not cluster figures.

| | |
|---|---|
| Resident memory, idle | 13.9 MiB |
| Resident memory, after 200 reservations | 17.0 MiB |
| `POST /v1/reservations`, mean | 2.5 ms |
| `POST /v1/reservations`, distribution | 39 of 40 under 5 ms; all under 10 ms |
| 300 concurrent reservations against 95 units of stock | 95 succeeded, 205 refused, 0 oversold |
| Tests | 10 unit, 14 integration, green under `-race -count=3` |

Verified end to end by hand, against a real Postgres: a hold placed with a 6 s TTL, stock at zero
while it was live, and stock back at six with the reservation reading `expired` seven seconds
later — with the commit attempt refused with `409 reservation_expired`.

### Notable implementation details

- `Idempotency-Key` is **required**, and bound to a SHA-256 digest of the canonical request. Replay
  returns 200 with the original; a reused key with a different body is a 409; a *refused*
  reservation rolls back its key so a smaller retry with the same key works
  ([ADR 0009](docs/adr/0009-mandatory-idempotency-key.md)).
- Allocation is best-fit then largest-first: if one tank can cover the order, use the smallest such
  tank, because livestock from one tank ships as one bag. **Cost: fragmentation.**
- Quarantined tanks appear in the stock endpoint with `available: 0` and are never allocated from.
  Hiding them would make the API and the shop floor disagree.
- Schema migrations run at startup behind a Postgres advisory lock, so several starting pods cannot
  run `CREATE TABLE` concurrently — without it, a rolling update crash-loops one pod on "relation
  already exists", which reads as a broken image.
- The container has **no writable mount at all**. A static Go binary does not need `/tmp` the way
  the JVM does.
- Liveness does not touch Postgres; readiness does. A database outage must not make Kubernetes
  restart every healthy pod.

### Still unproven

- **The service has never run in k3d.** It has run against a local Postgres only. Probes, the
  resource limits, the startup-probe window and the ConfigMap wiring are written and reviewed, not
  exercised.
- No load test. The latency figures are single-threaded.
- Compensation is not built: nothing yet calls `release` when a payment fails. That is Phase 3,
  when `order-service` and the saga arrive.

---

## Phase 1 — `catalog-service`, `storefront`, the cluster

Java 21 / Spring Boot catalog with Flyway-owned schema and twelve seeded species with real care
parameters; a Fastify BFF rendering HTML on the server; Postgres, ingress-nginx, cert-manager,
namespace quota and limit range on a single-node k3d cluster.

### Measured

**Nothing.** Every memory figure in `docs/architecture.md` — the whole profile table — is an
estimate, and `./scripts/bootstrap.sh` has not been run on a machine that has Docker. Replacing
those figures with `kubectl top pods -A` output is the first open item in
[docs/context_summary.md](docs/context_summary.md).

### Known gaps

- Secrets are plaintext in Git. The largest gap in the repository; Phase 5 replaces it.
- Single-node cluster: PodDisruptionBudgets, anti-affinity and node drains cannot be exercised.
- The AWS layer has never been applied.
