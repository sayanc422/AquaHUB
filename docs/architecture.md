# AquaShop — Architecture

> **The AWS infrastructure layer in this repository has never been applied to an AWS account.**
> It is written as production-quality Terraform and validated in CI with `fmt`, `validate`,
> `tflint`, `checkov` and `terraform test` against mock providers. That proves module composition,
> variable contracts and policy compliance. It does not prove AWS behaviour.
>
> The runtime is a single-node **k3d** cluster inside WSL2 on a 16 GB laptop. Diagrams carry AWS
> labels because AWS is the target platform. Every place the local setup diverges from that target
> is named in [Local to cloud](#10-local-to-cloud), not glossed over.

**Status:** Phases 1–5 complete in code. All eight services build, boot and have been exercised against a real Postgres — a live checkout, a
live compensation that returns stock when a card is declined, a live checkout that survives a payment
provider which takes the money and never answers, and a live tank check that refuses a fish and says
why. **`core`, `commerce` and `full-app` have all now run in k3d** (16–17 September 2026): all eight
services up together, a live checkout ran the full saga in-cluster and pushed a real notification
through `notification-service` end to end. `full-app` took three blocked attempts before it first
succeeded — the first two failed a memory preflight sitting right at this machine's unconfigured
WSL2 ceiling; the third passed the preflight but hit a real rollout deadlock (§8, RELEASE-NOTES) — but
once up, its measured footprint (2234 MiB) came in well under the ~5.2 GB estimate that stood in for
it until now. `platform` and `observability` remain unbuilt and unexercised.
Phases 6–7 are planned. See [context_summary.md](context_summary.md) for
current state, [RELEASE-NOTES.md](../RELEASE-NOTES.md) for what has been measured, and
[adr/](adr/) for the decisions and their costs.

---

## 1. System context

AquaShop is an online store for a freshwater aquarium business: live fish, shrimp and snails, live
plants, hardscape, equipment and food, with a full care profile published for every living species
before purchase.

Actors:

- **Customer** — browses by category, reads a care profile, checks a species against their tank,
  checks out with a computed shipping window, tracks an order, raises a DOA claim.
- **Staff** — manage tanks, stock, claims and species content through an internal back-office.
- **Payment provider** — external, stubbed locally.
- **Email and webhook targets** — external, stubbed locally.

### Why this domain

The domain was chosen because live livestock imposes constraints a generic shop demo does not, and
each constraint forces a decision worth defending:

| Constraint | Architectural consequence |
|---|---|
| Livestock is perishable and ships only in safe weather windows | An order can be *confirmed but not yet shippable*. The order state machine has a waiting state that is time-driven, not event-driven. |
| Stock is held per physical tank, not as one integer | Reservations are tank-scoped, time-bounded and idempotent — a distributed-systems problem (TTL expiry, retry safety), not a decrement. |
| Species are not mutually compatible | A rules engine over temperament and water parameters, not CRUD. Different change cadence, so a different service. |
| Water parameters must overlap across every inhabitant | Interval intersection over a set, evaluated against tank volume. |
| High-value livestock sometimes arrives dead | A claims workflow with photo evidence and a compensating refund — a real saga compensation, not a contrived one. |

---

## 2. Container view

Eight services. Every language choice is justified by a property of the service.

| Service | Stack | Owns | Why this stack |
|---|---|---|---|
| `catalog-service` | Java 21 / Spring Boot | Products, species care profiles, categories, search | Read-heavy relational data with a rich schema; the ecosystem I know best, so the platform work is the novel part |
| `order-service` | Java 21 / Spring Boot | Cart, checkout orchestration, order state machine, shipping windows | Long-lived transactional orchestration; mature saga and scheduling libraries |
| `inventory-service` | Go | Tank stock, reservations, holds, TTL expiry | Many small concurrent hold/expire operations; ~40 MB footprint suits a service that scales on request count |
| `payment-service` | Rust / Axum | Authorisation, capture, refund, ledger | Smallest surface, strictest correctness: exhaustive compile-time matching over ledger transitions, non-wrapping integer arithmetic. **Cost: slowest CI build of the eight, smallest maintainer pool.** |
| `aquatics-advisor` | Python / FastAPI | Compatibility rules, water-parameter matching, recommendations | Rules and numeric range logic that changes often and is edited by domain people |
| `notification-service` | Go | Email and webhook fan-out from domain events | I/O-bound fan-out with per-target retry. **Runs in k3d** (`full-app` profile, 17 September 2026): **5 MiB measured**, and a live checkout was seen pushing a real `ORDER_CONFIRMED` event through it end to end (`POST /v1/events` → `202` → stub email "delivered" four seconds later). |
| `staff-portal` | JSP / Jakarta EE on WildFly | Internal back-office, read-only in v1 | Deliberate. Containerising a WAR — startup probes, stdout logging, ConfigMap config, graceful shutdown — is the exercise that connects this project to production work. **Runs in k3d**: **456 MiB measured** against a 1 Gi limit — comfortable headroom, not a tight fit. Boot took ~4.1 s in-cluster, consistent with the ~2.8 s standalone measurement — not the "slow-start" the framing implied. |
| `storefront` | TypeScript / Fastify | Customer UI and backend-for-frontend | A BFF is I/O aggregation; server-rendered HTML avoids a client state layer that proves nothing |

**Data ownership:** one logical database per service. No cross-service joins, no shared schema, no
foreign keys across boundaries. Where two services need the same data, one owns it and the other
calls its API or subscribes to its events.

Locally these are separate databases and login roles on one Postgres instance, each role holding
`CONNECT` on its own database only. See [Local to cloud](#10-local-to-cloud) for what that costs.

### Asynchronous messaging

NATS JetStream, not Kafka. No consumer in this system needs log replay or partition-key ordering,
and Kafka plus a controller costs roughly 1 GB that this machine does not have.

**Cost:** partition-key ordering semantics are unavailable, the tooling ecosystem is smaller, and
migrating to MSK is a heavier lift than the local-to-cloud mapping makes it look.

---

## 3. Phase 1 — what is actually built

### catalog-service

- Flyway owns the schema; Hibernate runs `ddl-auto: validate` and will refuse to start against a
  schema it does not recognise. `open-in-view: false`, so no database session survives into view
  rendering.
- A CHECK constraint (`livestock_has_profile`) makes a living product without a care profile
  impossible at the database level, not just in application code.
- DTOs are separate from entities. The JSON is a published contract other services will depend on;
  the schema is this service's private business. Leaking entities makes every column rename a
  breaking API change.
- Repository queries use `join fetch`. The category name renders for every row in the list view, so
  lazy loading would be one query per product.
- Actuator exposes separate liveness and readiness probe groups; readiness includes the datasource,
  so a pod whose connection pool is exhausted leaves the Service endpoints instead of serving 500s.
- Twelve species seeded with real care parameters: temperature, pH and dGH ranges, adult size,
  minimum group size, temperament, diet, plant safety, and care notes.

### storefront

- Fastify BFF, server-rendered HTML, no client-side framework.
- Every upstream call is bounded at 2 s. A BFF without a timeout inherits the slowest dependency's
  latency and turns one slow service into a site-wide outage, because its own connection pool fills
  with requests that will never return.
- The category nav is cached in memory for 60 s — a deliberate, bounded staleness. A category rename
  takes up to a minute to appear; the alternative is an upstream call per page render for data that
  changes a few times a year.
- `/healthz` (liveness) does **not** call the catalog. If it did, a catalog outage would make
  Kubernetes restart every healthy storefront pod in a loop and turn a partial outage into a total
  one. `/readyz` (readiness) does call it, because a storefront that cannot reach the catalog should
  not receive traffic.

---

## 4. Phase 2 — `inventory-service`

Stock is held per physical tank, not as one integer per SKU, and every claim on it is time-bounded.
That turns inventory into a distributed-systems problem — TTL expiry, retry safety, concurrent
allocation — rather than a decrement.

**The rule the service is built on:** availability is

```
quantity_on_hand − Σ holds WHERE state = 'held' AND expires_at > now()
```

The deadline is *in the query*, so an expired hold stops holding stock at the instant it expires.
The reaper exists only to make the `state` column honest and the active-holds gauge current — it is
not load-bearing, which is why it runs in every replica with no leader election, no distributed lock
and no singleton deployment ([ADR 0008](adr/0008-availability-is-computed-from-the-deadline.md)).

**Concurrency.** Reservations for a SKU serialise on that SKU's tank rows, locked in a total order
so overlapping reservations cannot deadlock. The locks are taken in one statement and availability
is read in a second: under READ COMMITTED a statement's snapshot is taken *before* it blocks on a
lock, so doing both at once reads stale availability and oversells. The first version of the code
did exactly that, and the concurrency test caught it
([ADR 0010](adr/0010-lock-then-read-in-two-statements.md)).

**Idempotency.** `Idempotency-Key` is required, not optional, and bound to a digest of the canonical
request. Replay returns 200 with the original reservation; a key reused for a different request is a
409; a refused reservation rolls back its key
([ADR 0009](adr/0009-mandatory-idempotency-key.md)).

**Allocation.** Best-fit, then largest-first — livestock from one tank ships as one bag.
**Cost: fragmentation.** Quarantined tanks are reported with `available: 0` and never allocated
from, because the fish exist and the person reconciling the count is standing in front of them.

**Measured** (local Postgres on a build container, *not* k3d): 13.9 MiB resident idle, 17.0 MiB
after 200 reservations, 2.5 ms mean reservation, and zero oversells across 300 concurrent
reservations against 95 units of stock. See [slo.md](slo.md).

**Now also run in k3d** (16 September 2026, `commerce` profile): 3 MiB resident in-cluster —
lower still than the local-container figures above, though the pod was effectively idle during the
smoke-test window, not under sustained load. Probes, limits and ConfigMap wiring are exercised;
sustained load in-cluster is not.

---

### Containers

Multi-stage builds, distroless final stages, non-root, read-only root filesystem, all capabilities
dropped, `seccompProfile: RuntimeDefault`.

`JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=70` — the JVM must size its heap from the cgroup limit. Left
to its defaults it sees the host's memory, sizes a heap far above the container limit, and the kernel
OOM-kills it: **exit code 137**, reported by Kubernetes as `OOMKilled`.

**Cost of distroless:** there is no shell in the image, so `kubectl exec -- sh` does not work.
Debugging is via `kubectl debug` with an ephemeral container.

### Cluster

k3d with Traefik, servicelb and metrics-server disabled; ingress-nginx with `hostPort` 80/443;
cert-manager with a self-signed CA issuer; `ResourceQuota` and `LimitRange` on the namespace so an
unbounded pod cannot exist there by accident.

---

## 5. Phase 3 — `order-service`

Checkout is a saga: four steps across two services and a payment provider, with no distributed
transaction available.

```
  1. reserve    one hold per SKU in inventory-service    compensate: release
  2. authorise  take the money                           compensate: refund
  3. commit     turn every hold into a sale              compensate: refund
  4. confirm    fix the dispatch window                  --
```

**Stock is held before money is taken.** A customer charged for a fish that was never available is a
refund, an apology and a support ticket; a customer whose card is declined after a hold is a released
hold and nothing else. The reverse ordering is simpler to write and moves the cost of every failure
onto the customer ([ADR 0012](adr/0012-hold-stock-before-taking-money.md)).

**The state machine forbids the worst outcome rather than making it unlikely.** There is no
transition from `PAID` to `PAYMENT_FAILED`: once the money is taken, the only way out is `REFUNDED`,
which says by name what happened.

**A saga's memory is all its compensation has.** Reserving every line inside one transaction meant a
rollback erased the record of holds that already existed in the other service, and the compensation
released nothing while real stock stayed held. Each line is now recorded in its own committed
transaction ([ADR 0013](adr/0013-record-external-effects-outside-the-transaction.md)).

**Dispatch windows are the domain constraint made concrete.** Livestock leaves Monday to Wednesday
only, before a 14:00 cut-off in the shop's local time, because a bag posted on Thursday spends the
weekend in a depot. An order placed on Thursday afternoon is confirmed, paid for, and waiting for
Monday — a waiting state that no event ends, only the clock. `dispatchable` is therefore derived
(`now() >= dispatch_at`) and never stored, and the dispatch watcher is not load-bearing — the same
rule as inventory's reaper, generalised in [ADR 0011](adr/0011-derived-state-over-stored-state.md).

~~**Not proven:** the saga is not crash-safe.~~ **Closed.** `SagaRecovery` scans for orders stuck in
`PAID` or `STOCK_RESERVED` and finishes them; demonstrated with a real `kill -9` mid-checkout. It is
a state scan rather than an outbox ([ADR 0018](adr/0018-recover-from-state-not-from-an-outbox.md),
which amends 0015). `order-service` now talks to the real `payment-service` over HTTP, not the stub
described above — the stub was retired when Phase 4 landed. The saga has also now run end to end
in k3d (16 September 2026, `commerce` profile): a live checkout through the ingress-internal
`curlimages/curl` pod reserved, authorised, committed and confirmed, ending `CONFIRMED` with a
correct dispatch window. Not yet exercised in-cluster: a crash mid-checkout against the in-cluster
saga specifically — the `kill -9` demonstration above ran outside k3d.

---

## 6. Phase 4 — `payment-service`

The smallest surface in the platform and the strictest correctness requirement. Rust, for two
properties that are load-bearing rather than decorative: every ledger transition is an exhaustive
`match` with no catch-all arm, so a new state or event stops the build until a person decides what it
means; and every operation on money is checked, because release-mode Rust wraps on overflow silently
and a wrapped balance is a refund of nine quintillion rupees.

**The failure it exists for is not a decline.** It is an acquirer that takes the money and does not
answer. Both obvious responses are wrong — calling it a failure releases the stock while the
customer's money is gone; calling it a success promises an order that may never have been paid for.
So the unknown is a state in both services, and it never collapses into either neighbour
([ADR 0014](adr/0014-unknown-is-not-failure.md)).

**The intent is written before the acquirer is called.** A service that charges first and records
afterwards loses the record of every charge it dies in the middle of. The `pending` row is what
makes an unanswered charge findable, and the reconciler turns it into an answer
([ADR 0015](adr/0015-write-the-intent-before-the-call.md)). This is the outbox pattern in the small,
and `order-service`'s saga still lacks it.

**The ledger is append-only, enforced by a trigger** rather than by convention: a refund is a new
entry, never an edit of the capture it reverses. The balance is a fold over the entries.

**Two reconcilers here are load-bearing**, which is a real departure from
[ADR 0011](adr/0011-derived-state-over-stored-state.md) and is named as one. Resolving requires
asking another party, which no schema design makes derivable from a clock. What survives is the
safety property: an unresolved payment is never counted as money taken, so a stopped reconciler
delays the answer rather than corrupting it.

**Measured:** 6 MiB resident, against 361 MiB for `order-service` doing comparable work. That is the
argument for the language choice, as a number rather than a belief.

**Not proven:** the acquirer is a stub — no partial captures, no chargebacks, no 3-D Secure, no
settlement. Its constraints, append-only trigger and race-losing conditional update now have 18
gated database tests (`cargo test`, needs `PAYMENTS_TEST_DSN`) rather than being exercised only by
hand. Measured in-cluster (16 September 2026, `commerce` profile): 2 MiB resident, though the pod
was effectively idle during the smoke-test window, not under sustained load.

---

## 7. Phase 5 — `aquatics-advisor`

The service whose rules change weekly and whose code changes rarely, which is why it is a different
language on a different release rhythm.

**The rules are data.** `rules/rules.yaml` holds every threshold with a plain-English justification
beside it, and the API quotes those justifications back to the customer. The Python decides what to
check; the YAML decides how much is too much, and the person who keeps fish owns the second
([ADR 0016](adr/0016-rules-are-data-not-code.md)). The test suite loads the shipped file, so widening
a tolerance until an incompatible pair passes turns a test red.

**It owns no data.** Species care profiles belong to `catalog-service`; a copy here would be a second
source of truth that drifts the first time somebody corrects a pH range
([ADR 0017](adr/0017-advisor-owns-no-data.md)). **Cost:** it cannot answer anything when the catalog
is down — readiness fails, and liveness deliberately does not check, or an upstream outage would
restart every healthy pod.

**Three verdicts, not two.** No overlap at all is a refusal; a narrow overlap is a caution. Collapsing
them would force every judgement call into an extreme, and most stocking questions are neither.

**Not proven:** nothing tests the HTTP layer or the catalog client, and the image is
`python:3.11-slim` rather than distroless — a shell and a package manager in the one service whose
input is free-form customer data.

---

## 8. The memory budget

16 GB of physical RAM on the laptop; the design targets 11 GB usable inside WSL2 via a
`.wslconfig` memory override ([getting-started-locally.md](getting-started-locally.md#memory)).
That file now exists on this machine (`C:\Users\sayan\.wslconfig`, written 17 September 2026), but
applying it needs `wsl --shutdown`, which ends whatever WSL session runs it — not done as of this
writing, so `/proc/meminfo` still measures **7.4 GB**, WSL2's unconfigured default of roughly half
of host RAM. The `observability` profile's ~9.2 GB estimate does not fit
that unconfigured ceiling; it does fit the intended 11 GB one. The full platform does not fit at
once either way, so the cluster is built as **profiles**: named subsets brought up for a purpose. This is not a workaround
added at the end — it is why NATS replaced Kafka, why one Postgres instance hosts per-service
databases, and why only one environment is materialised at a time.

| Profile | Adds | Total |
|---|---|---|
| `core` | k3d, ingress-nginx, cert-manager, Postgres, catalog, storefront | **1.32 GiB measured** (`kubectl top node`, 16 Sep 2026) |
| `commerce` | order, inventory, payment, advisor, NATS | **~2.05 GiB measured** (NATS not deployed yet; see below) |
| `full-app` | notification, staff-portal (WildFly) | **2234 MiB measured** (`kubectl top node`, 17 Sep 2026) |
| `platform` | Argo CD | ~6.1 GB (estimate) |
| `observability` | kube-prometheus-stack, OTel collector, Tempo, prometheus-adapter | ~9.2 GB (estimate) |

`core`, `commerce` and `full-app` are all measured now, not estimated, and all three came in well
under their old estimates: `core` at 1.32 GiB against a ~2.6 GB estimate, `commerce` at ~2.05 GiB
total against a ~4.2 GB *additive* estimate (commerce actually added ~730 MiB), `full-app` at
**2234 MiB total against a ~5.2 GB estimate** — `staff-portal` alone, the thing that estimate was
mostly guessing about, measured 456 MiB against its own 1 Gi limit. `commerce`'s figure does not
include NATS, which `bootstrap.sh --profile commerce` does not yet deploy.

**`full-app` took three blocked attempts before it first succeeded (16–17 September 2026).** The
first two failed the memory preflight outright — a bare k3d cluster with nothing deployed yet already
leaves only ~5.9–6.4 GB free out of the unconfigured 7.4 GB ceiling, right at the profile's own
conservative 6 GB gate. The third passed the preflight and got every pod except `staff-portal`
running, then hit a genuine rollout deadlock, unrelated to raw memory pressure: `staff-portal`'s
Deployment uses `maxSurge: 1, maxUnavailable: 0`, so the old pod (permanently stuck in
`ImagePullBackOff` on the manifest's placeholder tag — cosmetic on every other service, since it's
always superseded before anyone notices) never became eligible for removal, and its `1 Gi`
`limits.memory` reservation against the namespace `ResourceQuota` (4 Gi total, eight services now
sharing it) left no room for the new pod's own `1 Gi` request. Fixed by hand in the running cluster
(deleting the stuck ReplicaSet freed the reservation) and then for real in the manifest —
`platform-repo/dev/staff-portal/deployment.yaml` now uses `maxUnavailable: 1, maxSurge: 0`, tearing
the old pod down before creating the new one instead of requiring both at once. Not yet re-verified
against a fresh reproduction (would mean tearing down the now-working cluster) — see RELEASE-NOTES
for the full account.

**`platform` and `observability` remain estimates, and `observability`'s (~9.2 GB) does
not fit inside the current, unconfigured 7.4 GB WSL2 ceiling at all**, even alone, let alone
alongside `core`. It does fit the intended 11 GB one. That gap was not visible
while every figure in this table was an unmeasured estimate; it is visible now that `core`,
`commerce` and `full-app` are all real numbers. Closing it means running `wsl --shutdown` to apply
the `.wslconfig` file above (already written; not yet applied), which has not been done yet since it
ends whatever WSL session runs it.

`bootstrap.sh` enforces the rule that follows from the ceiling: never build images while the
observability profile is up. ~1.8 GB of headroom does not survive a Maven or Cargo build.

### CPU limits

JVM services have CPU **requests** but no CPU **limit**. A limit means CFS throttling: once the
container exhausts its quota it is stopped for the remainder of each 100 ms period, which appears as
latency spikes while the node looks idle. Memory *is* limited, because memory is not compressible —
there is no equivalent of throttling for it, only the OOM killer.

**Cost:** a runaway pod can starve its neighbours. The namespace `ResourceQuota` is the backstop.

---

## 9. Delivery

Two repositories:

- `aquashop` — application code. CI per service: lint, test with a coverage gate, Trivy scan,
  multi-stage build, image tagged with the git SHA, then an automated pull request bumping the tag
  in the GitOps repo.
- `aquashop-platform` — cluster desired state. Argo CD app-of-apps across dev, uat and prod.
  Promotion is a pull request. Nobody runs `kubectl apply`.

Why two repos: a CI bot writing the tag bump into the application repo would retrigger CI on its own
commit. Separating them also makes the GitOps commit log a literal deployment history, and a
rollback becomes `git revert` of the tag-bump commit rather than a command typed against a cluster.

Image tags are the git SHA, never `:latest`. A mutable tag makes rollback a guess and makes "which
image is running" unanswerable from the cluster.

**Cost of GitOps self-heal:** Argo reverts a manual `kubectl edit` within seconds. That is the
point, and it is also how you lock yourself out of an emergency fix — which is why the runbooks
name the sync-window disable procedure.

---

## 10. Local to cloud

The full mapping document covers every component, the Terraform that would provision it, and the
traffic path end to end. This is the Phase 1 extract.

| Local | AWS counterpart | Terraform module → consumer | Faithful | Not faithful |
|---|---|---|---|---|
| k3d node container | EKS managed node group | `eks` → `cluster_endpoint`, `oidc_provider_arn`; consumed by `iam` and the addons module | Kubernetes API behaviour, scheduling, probes, quotas, RBAC | Single node, so PDBs, anti-affinity and drains are configured but never exercised. Pod IPs come from a Docker bridge, not VPC subnets, so VPC CNI IP exhaustion cannot occur here. |
| ingress-nginx `hostPort` | ALB + AWS Load Balancer Controller | `network` → `public_subnet_ids`; consumed by the controller via subnet discovery tags | Ingress objects, path routing, ingress class, nginx timeouts | No target groups, no cross-zone balancing, no deregistration delay. A missing `kubernetes.io/role/elb` tag silently produces no load balancer. |
| cert-manager self-signed CA | ACM certificate on the ALB | `acm` → `certificate_arn`; consumed by the Ingress annotation | Certificate lifecycle, secret mounting, renewal | TLS terminates *inside* the cluster here and *at the load balancer* in the target. Cipher policy, SNI and WAF association are untested. |
| Postgres StatefulSet, local-path PVC | RDS PostgreSQL, Multi-AZ | `rds` → `endpoint`, `port`, `secret_arn`; consumed by Helm values and the IRSA policy | Schema, migrations, pooling, per-service credential isolation | No failover, no automated backup, no parameter groups. The volume is node-local, so the "volume follows the pod" property of EBS does not exist. Multi-AZ failover is a DNS flip that pools must survive. |
| Plaintext Secret in Git | Secrets Manager via IRSA | `iam` → `irsa_role_arn`; consumed by the ServiceAccount annotation | Nothing — this is a Phase 1 placeholder | **The largest gap in the repository today.** Phase 5 replaces it with External Secrets + SOPS. |
| Local image import into k3d | ECR with immutable tags | `ecr` → `repository_urls`; consumed by CI and the deployment image field | SHA tags, no `:latest`, scan-on-build via Trivy | No registry auth, no pull-through cache, no VPC endpoint for private pulls, no lifecycle policy for untagged images. |

### AWS traffic path (target design, not observed)

Route 53 → ACM-terminated ALB in public subnets across two AZs → target group in IP mode, pointing
at pod IPs in private subnets → ingress-nginx → Service → pod. Egress to external payment and email
providers goes through the NAT gateway; ECR and Secrets Manager are reached through VPC endpoints so
those pulls never leave the VPC. Security group chain: ALB SG allows 443 from the internet; node SG
allows the ALB SG on the node port range; RDS SG allows the node SG on 5432 only.

### AWS failure modes I must be able to explain without having reproduced them

- **Subnet discovery tags** — a missing `kubernetes.io/role/elb` on a public subnet and the
  controller never creates the load balancer, with the reason only in the controller logs.
- **Pod IP exhaustion** — with the VPC CNI, pods take IPs from the subnet. A `/24` gives 251 usable
  addresses shared by nodes, pods and ENI warm pools; the failure is pods stuck in
  `ContainerCreating`, not a scheduling error.
- **IRSA** — the pod's projected service-account token is exchanged with STS for temporary
  credentials, scoped by a trust policy naming the OIDC provider and the service account.
- **Multi-AZ failover** — a DNS flip, not a zero-downtime event. Connection pools holding the old
  endpoint must detect the failure and reconnect.

---

## 11. Known limitations

State these plainly. They make the project more credible, not less.

- Secrets are plaintext in Git at Phase 1.
- Single-node cluster: PDBs, anti-affinity, node drains and multi-AZ behaviour cannot be exercised.
- Only one environment is materialised at a time; none has run concurrently with another.
- The AWS layer has never been applied. Module wiring is proven; AWS behaviour is not.
- Performance numbers under sustained load exist nowhere, in or out of k3d — only single-threaded,
  short smoke-test figures. `core`, `commerce` and `full-app` are now measured (not estimated) for
  idle/light load; `platform` and `observability` remain estimates.
- All eight services have now run in k3d (`core` + `commerce` + `full-app` profiles, 16–17 September
  2026): probes, resource limits, ingress/TLS, and a live checkout across `order-service`,
  `inventory-service`, `payment-service` and `notification-service` together, all exercised
  in-cluster — the notification push in particular was watched end to end, from `order-service`'s
  `HttpNotificationClient` call through to a stub email logged as delivered. `full-app` took four
  attempts: two blocked by a memory preflight sitting right at the unconfigured 7.4 GB WSL2 ceiling's
  edge, a third that passed the preflight but hit a real rollout deadlock, fixed both by hand and in
  the manifest (§8, RELEASE-NOTES). `staff-portal` is now reachable through the public ingress too,
  at `https://staff.aquashop.localtest.me/` — a separate host rather than a `/staff` path prefix
  under the main one, because `staff-portal` deploys as `ROOT.war` (its JSPs' links are
  root-relative, `/orders` not `/staff/orders`) and a path prefix would break every link past the
  first page. Not yet exercised in-cluster: sustained
  load, a `kill -9` mid-checkout against the in-cluster saga specifically, and the
  `platform`/`observability` profiles —
  `observability`'s ~9.2 GB estimate does not fit
  the current, unconfigured 7.4 GB WSL2 ceiling (§8) at all; the `.wslconfig` override that targets 11 GB
  has been written but not yet applied (needs `wsl --shutdown`, which ends whatever session runs it —
  not done as of this writing).
- ~~The checkout saga is not crash-safe.~~ **Closed.** `SagaRecovery` scans for orders stuck in
  `PAID` or `STOCK_RESERVED` and finishes them; demonstrated with a real `kill -9` mid-checkout. A
  state scan rather than an outbox — see [ADR 0018](adr/0018-recover-from-state-not-from-an-outbox.md),
  which amends 0015.
- `payment-service`'s acquirer is a stub: no partial captures, no chargebacks, no 3-D Secure, no
  settlement, and an in-process memory that a restart wipes. It now has 18 gated database tests
  covering its CHECK constraints, append-only trigger and race-losing conditional update.
- `aquatics-advisor` has no test covering its HTTP layer or its catalog client, and ships on
  `python:3.11-slim` rather than distroless — a shell and a package manager in the image.
- The advisor's predation rule uses adult length because the catalog does not record mouth gape. It
  will not catch a large peaceful fish with a big mouth, and that is stated in `rules.yaml`.
- The observability stack and the image build cannot both run on this machine.

---

## 12. Where the rest of the documents are

| Document | Contents |
|---|---|
| [adr/](adr/) | One record per decision that would be expensive to reverse, each with its cost |
| [slo.md](slo.md) | Objectives, the consequence of missing each, and which numbers are measured |
| [runbooks/](runbooks/) | One page per failure, written to be followed at 02:00 |
| [../RELEASE-NOTES.md](../RELEASE-NOTES.md) | What was built per phase, what was measured, what is unproven |

---

## 13. Diagrams

Generated by `docs/diagrams/generate.py` and committed as SVG so changes appear in diffs.

- `docs/diagrams/architecture.svg` — system architecture, Phase 1 solid and later phases dimmed
- `docs/diagrams/deployment.svg` — what runs locally beside the AWS target design
- `docs/diagrams/delivery-flow.svg` — two repositories, CI, GitOps promotion

A styled, printable version of this document with the diagrams embedded is at
`docs/architecture.pdf`.
