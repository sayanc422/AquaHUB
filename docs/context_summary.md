# AquaShop — Context Summary

*Paste this as the opening message of a new session, together with the original project brief.
It is the state of the work, not a restatement of the brief.*

**Last updated:** end of Phase 2 build session (13 September 2026).

---

## Decisions already made — do not re-litigate these

| Decision | Choice | Why, and what it costs |
|---|---|---|
| Terraform validation | `terraform test` with `mock_provider`, plus `fmt`, `validate`, `tflint`, `checkov` | LocalStack cannot emulate EKS, ELBv2 or Multi-AZ RDS outside Pro, and a plan against a thin emulation proves nothing. Cost: module wiring and variable contracts are proven; AWS behaviour is not, and that must be said in interviews. |
| Environments | Three overlays — dev, uat, prod — all managed by Argo CD, only one materialised at a time; the others sit at `replicas: 0` | ~11 GB cannot hold two full environments. Cost: no environment has ever run concurrently with another. Never say "I ran prod"; say "three overlays under GitOps, one materialised at a time". |
| Database topology | One Postgres StatefulSet; one logical database and one login role per service, each with `CONNECT` on its own database only | Saves ~1.1 GB. Does not violate the data-ownership rule — no shared schema, no cross-service joins, no cross-boundary FKs. Cost: blast-radius isolation is lost; one restart takes every service down, which per-service RDS would not. |
| Message broker | NATS JetStream, not Kafka | No consumer needs log replay or partition-key ordering; Kafka costs ~1 GB this machine does not have. Cost: smaller tooling ecosystem, and MSK is a heavier migration than the mapping implies. |
| Storefront shape | Fastify BFF with server-rendered templates, not a React SPA | The BFF story is aggregation, timeouts and trace propagation. An SPA adds a build toolchain and a client state layer that prove none of that. |
| Java build tool | Maven | Matches the WildFly/WAR world, so the build tool is not a second unfamiliar thing. |
| Repositories | `aquashop` (application code), `aquashop-platform` (GitOps desired state) | A CI bot writing to the app repo would retrigger CI on its own commit. |
| Reservation expiry | Availability subtracts only holds with `expires_at > now()`; the reaper is bookkeeping | A background job that is load-bearing makes stock correctness depend on a cron's health. Cost: every availability read pays for an aggregate over `reservation_line`; a materialised counter would be faster and would reintroduce the correctness problem. |
| Reservation concurrency | Lock tank rows in one statement, read availability in a second | READ COMMITTED takes a statement's snapshot *before* it blocks on a lock, so one `SELECT ... FOR UPDATE` oversells — the concurrency test caught it. Cost: one extra round trip; a hot SKU serialises on its tanks. |
| Idempotency | `Idempotency-Key` required, bound to a digest of the canonical request | Checkout retries. Cost: a breaking change for any client not told, and the digest's canonical form is a maintenance obligation on whoever adds a request field. |
| Stock allocation | Best-fit, then largest-first | Livestock from one tank ships as one bag. Cost: fragmentation — many small orders leave many tanks holding a few fish each. |
| CPU limits | Requests only on JVM services; memory limits always | A CPU limit means CFS throttling — the container is stopped for the rest of each 100 ms period, which reads as latency spikes on an idle-looking node. Memory is limited because memory is not compressible. Cost: a runaway pod can starve neighbours; ResourceQuota is the backstop. |

## Memory profiles (estimates until measured)

| Profile | Adds | Est. total |
|---|---|---|
| `core` | k3d, ingress-nginx, cert-manager, Postgres, catalog, storefront | ~2.6 GB |
| `commerce` | order, inventory, payment, advisor, NATS | ~4.2 GB |

`inventory-service` measures 13.9 MiB resident idle and 17.0 MiB after 200 reservations — but
against a local Postgres on a build container, not in k3d. It is the only service in the repository
with any measured figure at all.
| `full-app` | notification, staff-portal (WildFly) | ~5.2 GB |
| `platform` | Argo CD | ~6.1 GB |
| `observability` | kube-prometheus-stack, OTel collector, Tempo, prometheus-adapter | ~9.2 GB |

Hard rule, enforced in `bootstrap.sh`: never build images while the observability profile is up.
~1.8 GB of headroom does not survive a Maven or Cargo build, and the failure mode is the kernel
OOM killer taking an unrelated pod.

---

## What exists on disk

```
aquashop/
  scripts/
    bootstrap.sh            idempotent; memory preflight refuses to run below 4 GB free
    k3d-cluster.yaml        traefik, servicelb, metrics-server all disabled
  services/
    catalog-service/        Java 21, Spring Boot 3.3, Flyway, Testcontainers, distroless
    storefront/             TypeScript, Fastify BFF, SSR HTML, distroless
    inventory-service/      Go 1.24, pgx, embedded migrations, distroless static
  platform-repo/dev/        namespace + quota + limitrange, postgres, catalog, storefront,
                            inventory, ingress
  docs/
    architecture.md         full prose architecture
    architecture.pdf        8 pages, styled, diagrams embedded  (PHASE 1 CONTENT ONLY)
    architecture-pdf.html   source of the PDF                   (PHASE 1 CONTENT ONLY)
    adr/                    ten decision records, each with its cost
    slo.md                  objectives, consequences, and which numbers are measured
    runbooks/               four runbooks; three reproduced locally, one written from docs
    diagrams/generate.py    generates all three SVGs
    diagrams/*.svg          architecture, deployment, delivery-flow
  RELEASE-NOTES.md          per phase: what was built, measured, and still unproven
```

### Phase 1 implementation notes worth carrying forward

- Flyway owns the schema; Hibernate runs `ddl-auto: validate`. `open-in-view: false`.
- A CHECK constraint makes a livestock product without a care profile impossible.
- DTOs are separate from entities: the JSON is a published contract, the schema is private.
- Repository queries use `join fetch` — the category name renders per row, so lazy loading is N+1.
- Twelve species are seeded with real care parameters (temperature, pH, dGH, adult size, minimum
  group size, temperament, diet, plant safety), plus plants, hardscape, equipment and food.
- Integration tests run against real Postgres via Testcontainers, not H2: the schema uses CHECK
  constraints and a functional index that H2 would ignore or reject.
- `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=70` — the JVM must size its heap from the cgroup limit,
  or it sizes from host RAM and gets OOM-killed (exit 137).
- Startup probe carries the slow JVM boot (30 × 5 s) so liveness can stay tight.
- Storefront liveness (`/healthz`) deliberately does **not** call the catalog; readiness
  (`/readyz`) does. A catalog outage must not restart every storefront pod.
- Every upstream call from the BFF is bounded at 2 s.

---

### Phase 2 implementation notes worth carrying forward

- Availability puts the deadline in the query, so the reaper is not load-bearing. This is the single
  most defensible decision in the service; see `docs/adr/0008-*`.
- The first version of `Reserve` oversold. Locking the tanks and reading their availability in one
  `SELECT ... FOR UPDATE` is wrong under READ COMMITTED, because a statement's snapshot is taken
  before it blocks on the lock. Lock in one statement, read in a second. The concurrency test
  (20 goroutines, 8 fish, 2 at a time) is what caught it, and it is worth keeping in that shape.
- `ON CONFLICT DO UPDATE`, not `DO NOTHING`, for the idempotency insert: `DO NOTHING` returns no row
  when the conflicting insert is still uncommitted elsewhere, and the follow-up `SELECT` cannot see
  it either. `xmax = 0` distinguishes a genuine insert from a conflict.
- A refused reservation must roll back its idempotency key, or a customer who reduces the basket and
  retries with the same key gets a permanent 409.
- Migrations take a Postgres advisory lock. Without it a rolling update crash-loops one pod on
  "relation already exists", which reads as a broken image.
- The Go container needs no writable mount at all — unlike the JVM, which needs `/tmp`.

---

## Open items, in order

1. **Run `./scripts/bootstrap.sh` and record real numbers.** Still the first item, and still
   blocked on a machine with Docker — the Phase 2 session had none, so `inventory-service` has
   never run in k3d. Every profile memory figure remains an estimate. Replace them from
   `kubectl top pods -A` in `docs/architecture.md`, the PDF source, and `RELEASE-NOTES.md`.
2. **Bring the PDF up to date.** `docs/architecture-pdf.html` still carries Phase 1 content only;
   `docs/architecture.md` is now ahead of it. Regenerate after the numbers from item 1 land, so the
   PDF is rebuilt once rather than twice.
3. **Still not written:** the full local-to-cloud document (only the Phase 1 extract exists, in
   `docs/architecture.md` §7 and on page 7 of the PDF).
4. **Phase 3:** `order-service` in Java — cart, checkout orchestration, the order state machine with
   its time-driven waiting state, and the saga that calls `inventory-service` and compensates by
   releasing the hold when payment fails. Ends with an order that survives a payment failure without
   stranding stock.

### Known limitations to state plainly, never soften

- Secrets are plaintext in Git at Phase 1. Largest gap in the repo. Phase 5 replaces it.
- Single-node cluster: PodDisruptionBudgets, anti-affinity and node drains are configured in later
  phases but cannot be exercised.
- The AWS layer has never been applied.
- No performance number is measured for anything except `inventory-service`, and that only against
  a local Postgres on a build container — never in k3d, never under sustained load.
- `inventory-service` has never run in the cluster, and nothing calls `release` on a failed payment
  yet. Compensation arrives with Phase 3.

---

## How this session worked, and should keep working

- Accuracy before documents. Clarifying questions first; a wrong assumption compounds across a
  document set.
- One phase at a time, each ending in something demonstrable. Phase 1 ends with a fish in a browser;
  Phase 2 ends with a hold that expires and returns its stock with nobody doing anything.
- Write the test that can fail before believing the code. The Phase 2 oversell bug was found by a
  concurrency test, not by review, and it would have survived any number of readings.
- Name the cost of every decision — memory, complexity, operational burden.
- Push back on claims that would not survive an interview follow-up. The honest framing —
  *"designed for AWS, validated locally, run on k3d"* — is the point, not a limitation.
