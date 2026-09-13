# AquaShop — Architecture

> **The AWS infrastructure layer in this repository has never been applied to an AWS account.**
> It is written as production-quality Terraform and validated in CI with `fmt`, `validate`,
> `tflint`, `checkov` and `terraform test` against mock providers. That proves module composition,
> variable contracts and policy compliance. It does not prove AWS behaviour.
>
> The runtime is a single-node **k3d** cluster inside WSL2 on a 16 GB laptop. Diagrams carry AWS
> labels because AWS is the target platform. Every place the local setup diverges from that target
> is named in [Local to cloud](#local-to-cloud), not glossed over.

**Status:** Phase 1 complete — `catalog-service` and `storefront` run in the local cluster.
Phases 2–7 are planned. See [context_summary.md](context_summary.md) for current state.

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
| `notification-service` | Go | Email and webhook fan-out from domain events | I/O-bound fan-out with per-target retry |
| `staff-portal` | JSP / Jakarta EE on WildFly | Internal back-office | Deliberate. Containerising a slow-starting WAR — startup probes, stdout logging, ConfigMap config, graceful shutdown — is the exercise that connects this project to production work |
| `storefront` | TypeScript / Fastify | Customer UI and backend-for-frontend | A BFF is I/O aggregation; server-rendered HTML avoids a client state layer that proves nothing |

**Data ownership:** one logical database per service. No cross-service joins, no shared schema, no
foreign keys across boundaries. Where two services need the same data, one owns it and the other
calls its API or subscribes to its events.

Locally these are separate databases and login roles on one Postgres instance, each role holding
`CONNECT` on its own database only. See [Local to cloud](#local-to-cloud) for what that costs.

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

## 4. The memory budget

16 GB of RAM, roughly 11 GB usable inside WSL2. The full platform does not fit at once, so the
cluster is built as **profiles**: named subsets brought up for a purpose. This is not a workaround
added at the end — it is why NATS replaced Kafka, why one Postgres instance hosts per-service
databases, and why only one environment is materialised at a time.

| Profile | Adds | Est. total |
|---|---|---|
| `core` | k3d, ingress-nginx, cert-manager, Postgres, catalog, storefront | ~2.6 GB |
| `commerce` | order, inventory, payment, advisor, NATS | ~4.2 GB |
| `full-app` | notification, staff-portal (WildFly) | ~5.2 GB |
| `platform` | Argo CD | ~6.1 GB |
| `observability` | kube-prometheus-stack, OTel collector, Tempo, prometheus-adapter | ~9.2 GB |

**Every figure above is an estimate until measured.** After the first `bootstrap.sh` run, replace
them with `kubectl top pods -A` output. A measured number that was never measured is exactly the
claim that collapses under one follow-up question.

`bootstrap.sh` enforces the rule that follows from the ceiling: never build images while the
observability profile is up. ~1.8 GB of headroom does not survive a Maven or Cargo build.

### CPU limits

JVM services have CPU **requests** but no CPU **limit**. A limit means CFS throttling: once the
container exhausts its quota it is stopped for the remainder of each 100 ms period, which appears as
latency spikes while the node looks idle. Memory *is* limited, because memory is not compressible —
there is no equivalent of throttling for it, only the OOM killer.

**Cost:** a runaway pod can starve its neighbours. The namespace `ResourceQuota` is the backstop.

---

## 5. Delivery

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

## 6. Local to cloud

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

## 7. Known limitations

State these plainly. They make the project more credible, not less.

- Secrets are plaintext in Git at Phase 1.
- Single-node cluster: PDBs, anti-affinity, node drains and multi-AZ behaviour cannot be exercised.
- Only one environment is materialised at a time; none has run concurrently with another.
- The AWS layer has never been applied. Module wiring is proven; AWS behaviour is not.
- No performance number in this document set is measured yet.
- The observability stack and the image build cannot both run on this machine.

---

## 8. Diagrams

Generated by `docs/diagrams/generate.py` and committed as SVG so changes appear in diffs.

- `docs/diagrams/architecture.svg` — system architecture, Phase 1 solid and later phases dimmed
- `docs/diagrams/deployment.svg` — what runs locally beside the AWS target design
- `docs/diagrams/delivery-flow.svg` — two repositories, CI, GitOps promotion

A styled, printable version of this document with the diagrams embedded is at
`docs/architecture.pdf`.
