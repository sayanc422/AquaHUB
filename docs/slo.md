# Service level objectives

An SLO is a promise with a consequence. A number nobody would act on is a dashboard label, so each
objective below names what happens when it is missed.

**Every number on this page is either measured and labelled as such, or a target that has never been
tested.** The distinction is the point of the page.

## What is actually measured

Measured on 13 September 2026 against a local Postgres 16 on the build container — **not in k3d,
and not under realistic concurrency.** Treat them as the right order of magnitude, nothing more.

| Measurement | Value | How |
|---|---|---|
| `inventory-service` resident memory, idle | 13.9 MiB | `VmRSS` after startup and migrations |
| `inventory-service` resident memory, after 200 reservations | 17.0 MiB | `VmRSS`, same process |
| `POST /v1/reservations` mean | 2.5 ms | `inventory_http_request_duration_seconds_sum / _count`, 40 successful reservations |
| `POST /v1/reservations` distribution | 39 of 40 under 5 ms, 40 of 40 under 10 ms | histogram buckets |
| Oversell under 300 concurrent reservations against 95 units | 0 | 95 succeeded, 205 refused, `available` reached exactly 0 |
| `catalog-service` time to readiness | 5.8 s | cold start against an empty database, Flyway included |
| `catalog-service` resident memory | 338 MiB | **with no cgroup limit** — the JVM sized its heap from 16 GB of host RAM, so this is not what it uses under the 640Mi limit |
| `storefront` resident memory | 76 MiB | serving rendered pages against a live catalog |
| Whole failed checkout, end to end | 107 ms | 2 reservations, 2 releases, 5 persisted transitions, across two services |
| `order-service` checkout requests | 69 ms mean, 193 ms max | 7 requests including first-call JIT warm-up |
| `order-service` resident memory | 361 MiB | same caveat as the catalog: no cgroup limit, so the heap was sized from host RAM |
| `payment-service` resident memory | **6 MiB** | the same measurement, on the service doing comparable work in Rust |
| `payment-service` release binary | 4.2 MiB | |

Not measured anywhere yet: anything in k3d, anything under sustained load, and every figure in the
profile memory table. The JVM memory figure above is measured but not *useful* — a JVM without a
cgroup limit is not the JVM the cluster runs.

## Objectives

### `catalog-service` — the read path

| | |
|---|---|
| **Availability** | 99.5% of `GET /api/**` return a non-5xx response, over 30 days |
| **Latency** | p99 of `GET /api/products` under 300 ms |
| **Why these numbers** | A browsing customer tolerates a slow page; they do not tolerate an error page. Availability is the tighter promise on purpose. |
| **Consequence when missed** | Page the on-call for availability. Latency is a ticket, not a page, unless it is sustained for an hour. |
| **Status** | Target. Never measured. |

### `inventory-service` — the reservation path

| | |
|---|---|
| **Correctness** | Zero oversells. Not an SLO with an error budget: an oversold fish is a customer who is told the livestock they paid for does not exist. |
| **Latency** | p99 of `POST /v1/reservations` under 150 ms |
| **Availability** | 99.9% of reservation requests return a non-5xx response |
| **Freshness** | A hold is invisible to availability within 0 s of its deadline — by construction, see [ADR 0008](adr/0008-availability-is-computed-from-the-deadline.md). The reaper's staleness (default 30 s) affects only the `state` column and the gauge. |
| **Why these numbers** | This call sits inside checkout. 150 ms is the point at which the checkout page needs a spinner. The tighter availability target reflects that a failure here loses a sale, not a page view. |
| **Consequence when missed** | Page on availability or on any oversell. The histogram buckets in `internal/obs/metrics.go` are cut for this SLO — 0.1, 0.15, 0.3 — rather than the library defaults, which have no edge anywhere near 150 ms. |
| **Status** | Latency measured only single-threaded on a build container (2.5 ms mean). Availability never measured. |

### `order-service` — checkout

| | |
|---|---|
| **Correctness** | No order in `PAYMENT_FAILED` with a payment reference, ever; no order stuck in `PAID`. Not an SLO with an error budget — both mean a customer's money is somewhere they cannot see. |
| **Latency** | p99 of `POST /v1/orders/from-cart/{id}` under 2 s, end to end including the reservation and payment calls |
| **Availability** | 99.9% of checkouts return a non-5xx response. A declined card is not a failure: it is a 201 with an order that says `PAYMENT_FAILED`. |
| **Why these numbers** | 2 s is the point at which a customer who has entered a card starts pressing the button again. The reservation call is bounded at 2 s on its own, so the budget assumes at most one slow upstream, not four. |
| **Consequence when missed** | Page on availability, on any stuck `PAID` order, and on any `REFUNDED` rate above a handful a week — a rising refund rate means the hold TTL is shorter than customers take to pay. |
| **Status** | Measured only single-threaded on a build container: 107 ms for a whole failed checkout. Availability never measured. |

### `payment-service` — the money

| | |
|---|---|
| **Correctness** | No payment in `pending` for longer than it takes to resolve one, and no charge without a ledger entry. Not an SLO with an error budget: both mean money whose location nobody can state. |
| **Latency** | p99 of `POST /v1/payments` under 2.5 s — the acquirer timeout plus the two writes around it |
| **Availability** | 99.9% of payment requests return a *decision*, where 504 counts as a decision: "unknown" is a correct answer and must not be traded for a confident wrong one |
| **Resolution** | Every `pending` payment resolved within 2 minutes — the reconcile interval plus the void window |
| **Consequence when missed** | Page on `payment_pending` above zero for more than 5 minutes, and on any `payment_unresolved_total` increase without a matching `payment_reconciled_total`. Those two are the alerting pair: unknowns arriving is normal, unknowns not being resolved is not. |
| **Status** | Targets. Resolution demonstrated by hand (a pending payment resolved by the reconciler with nobody asking); nothing measured under load. |

### `storefront` — the customer entry point

| | |
|---|---|
| **Availability** | 99.5% of page renders return 2xx |
| **Latency** | p95 of the category page under 800 ms, including upstream calls |
| **Degradation** | A catalog outage must degrade the page, not the pod. `/healthz` does not call the catalog, so an upstream failure cannot make Kubernetes restart every healthy storefront replica. |
| **Status** | Availability and latency: targets, never measured. Degradation: **verified by hand** — with the catalog stopped, liveness stayed 200, readiness went 503 and the page returned 502. |

## Error budget

99.5% over 30 days is 3 h 39 m of unavailability. 99.9% is 43 m.

The budget is for spending: while it is intact, ship. When a month's budget is exhausted, the next
change is a reliability change. Without that rule the budget is decoration.

**This project has never consumed an error budget, because nothing here has ever served a real
user.** The page is a statement of what would be measured and acted on, not a record of what has
been.

## What is deliberately not an SLO

- **Acquirer latency.** It is somebody else's service and no amount of alerting changes it. What is worth alerting on is *this* system's behaviour when it is slow — which is the resolution objective above, not a percentile on a call we do not control.
- **Dispatch-watcher lag.** Shippability is derived from the clock, so a stopped watcher delays no order. It delays a notification, which is worth an alert of its own and not an SLO on orders.
- **Reaper lag.** It cannot affect stock correctness ([ADR 0008](adr/0008-availability-is-computed-from-the-deadline.md)). A gauge that is 30 s stale is worth an alert only if it is stale for hours — which means a reaper that stopped, and that is worth knowing for a different reason.
- **Build duration.** It matters, it is tracked, and paging someone at 02:00 for it would be absurd.
- **Pod restart count.** A symptom, not a promise. It belongs on a dashboard, next to the OOMKill counter.
