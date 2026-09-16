# AquaShop — Context Summary

*Paste this as the opening message of a new session, together with the original project brief.
It is the state of the work, not a restatement of the brief.*

**Last updated:** end of the first k3d run, `core` + `commerce` profiles and a live in-cluster
checkout (16 September 2026).

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
| Checkout ordering | Reserve stock, then take money, then commit | A declined card costs a released hold; the reverse ordering costs a refund and an apology. Cost: stock is held for customers who never complete, and the saga needs a compensation on the stock side that must be idempotent, out-of-transaction and non-masking. |
| Saga bookkeeping | Each reservation is committed in its own transaction as it is taken | A rollback across the loop erases the record of holds that already exist elsewhere, and the compensation then releases nothing. Cost: one round trip per line instead of one per checkout. |
| Waiting states | Derived from the clock, never stored | Generalises the reservation-expiry rule: no scheduled job is load-bearing. Cost: the value cannot be indexed directly, and the API must expose both stored state and derived state or it is lying by omission. |
| Saga crash recovery | A scan over order state, NOT an outbox (amends the Phase 4 plan) | The intention is already stored: an order in PAID with a payment ref and no dispatch window IS the record. An outbox would duplicate the order row. Cost: a third load-bearing scheduled job, and a threshold that must exceed the slowest in-flight checkout. |
| Unknown payment outcomes | A state in both services, never collapsed into success or failure | Releasing holds on a timeout sells stock while the customer's money is gone; confirming promises an unpaid order. Cost: two reconcilers that ARE load-bearing, and a state customers see ("we are checking with your bank"). |
| Payment durability | The intent row is written before the acquirer is called | A charge-then-record design loses the record of every charge it dies during. Cost: two round trips instead of one, and a table of `pending` rows to scan. |
| Stocking rules | Data in a YAML file with a justification per threshold, not code | The rules change weekly and belong to whoever keeps fish. Cost: a YAML file is not type-checked, and one list of SKUs (fin-nippers) is really data that belongs on the catalog's species profile. |
| Advisor storage | None. It reads species profiles from catalog-service | A local copy is a second source of truth that drifts on the first correction. Cost: it cannot answer at all when the catalog is down, and a SKU lookup costs an extra hop. |
| Catalogue shape | A tree: category.parent_id, with status ACTIVE/COMING_SOON/HIDDEN | A shop is browsed by narrowing. Cost: five levels means five clicks, so every level needs a "browse all" escape hatch, and counts have to be subtree counts or every branch tile reads zero. |
| CPU limits | Requests only on JVM services; memory limits always | A CPU limit means CFS throttling — the container is stopped for the rest of each 100 ms period, which reads as latency spikes on an idle-looking node. Memory is limited because memory is not compressible. Cost: a runaway pod can starve neighbours; ResourceQuota is the backstop. |
| Pod securityContext for distroless images | `runAsUser: 65532` / `runAsGroup: 65532` set explicitly alongside `runAsNonRoot: true`, on all six deployments | The distroless `:nonroot` images set `USER nonroot` — a name, not a UID — and kubelet's `runAsNonRoot` check cannot verify a name without running the container first, so every pod sat in `CreateContainerConfigError` on the first real k3d run. Cost: couples every deployment manifest to the specific numeric UID Google's distroless images happen to use (65532); a future base-image change that picks a different UID breaks this silently until the next `kubectl apply`. |
| `inventory-service` builder image | `golang:1.25-bookworm`, not `1.24` | `go.mod` already declared `go 1.25.0`; the Dockerfile had drifted behind it and `docker build` was the first thing to notice, because `go test`/`go build` on a dev machine use whatever local toolchain is installed. Cost: none beyond the version bump — no first-party code changed. |
| `payment-service` builder image | `rust:1.90-bookworm`, not `1.82` (the crate's own declared `rust-version`) | `Cargo.lock` resolved a transitive dependency (`home v0.5.12`) whose manifest requires Cargo's `edition2024` feature, stabilized in 1.85 — a stricter floor than the crate's own MSRV, and invisible until the pinned builder image actually ran `cargo build`. Cost: the builder image is now well ahead of the declared `rust-version = "1.82"`, so that field is aspirational for anyone building outside Docker with an older local toolchain; nothing first-party changed. |

## Memory profiles

| Profile | Adds | Total |
|---|---|---|
| `core` | k3d, ingress-nginx, cert-manager, Postgres, catalog, storefront | **1.32 GiB measured** (`kubectl top node`, 16 Sep 2026) |
| `commerce` | order, inventory, payment, advisor, NATS | **~2.0 GiB measured** (`core` + commerce services; NATS not deployed yet — see below) |
| `full-app` | notification, staff-portal (WildFly) | ~5.2 GB (estimate) |
| `platform` | Argo CD | ~6.1 GB (estimate) |
| `observability` | kube-prometheus-stack, OTel collector, Tempo, prometheus-adapter | ~9.2 GB (estimate) |

`core` and `commerce` are both measured now, not estimated, and both came in well under budget:
`core` at 1.32 GiB against a ~2.6 GB estimate, `commerce` at **~2.05 GiB total** (node went from
1322 MiB to 2052 MiB adding all four commerce services) against a ~4.2 GB *additive* estimate — i.e.
commerce added ~730 MiB, not ~1.6 GB. `full-app`, `platform` and `observability` remain budgets: only
`core` and `commerce` have run in k3d so far, and `commerce`'s figure does not include NATS, which
`bootstrap.sh --profile commerce` does not deploy (planned for Phase 6).

Per-pod, from `kubectl top pods -A` after both profiles were up and settled:

| Pod | CPU | Memory |
|---|---|---|
| `catalog-service` (JVM, 640Mi limit) | 3m | 215 MiB |
| `order-service` (JVM, limit TBD) | 7m | 224 MiB |
| `storefront` (Node) | 1m | 30 MiB |
| `aquatics-advisor` (Python/FastAPI) | 3m | 43 MiB |
| `inventory-service` (Go) | 1m | 3 MiB |
| `payment-service` (Rust) | 1m | 2 MiB |
| `postgres` | 6m | 59 MiB |
| `ingress-nginx-controller` | — | 184–189 MiB |
| `cert-manager` (+ webhook, cainjector) | — | ~53 MiB |
| `metrics-server` | — | ~19–21 MiB |

`catalog-service`'s 215 MiB and `order-service`'s 224 MiB are the first honest JVM numbers in this
repository — measured under their actual cgroup limits with `MaxRAMPercentage=70`, not against host
RAM the way the 338 MiB and 361 MiB figures below were. `payment-service`'s 2 MiB and `inventory-service`'s 3 MiB in-cluster are even lower than
`inventory-service`'s previously-measured 13.9 MiB idle / 17.0 MiB after 200 reservations (against a
local Postgres on a build container, not in k3d) — consistent with the "Rust earned its place with a
number" argument in the Phase 4 notes, and a reminder that these two services were effectively idle
during the smoke-test window below, not under sustained load.

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
    order-service/          Java 21, Spring Boot 3.3, checkout saga, dispatch calendar
    payment-service/        Rust 1.94, Axum, sqlx, append-only ledger, distroless/cc
    aquatics-advisor/       Python 3.11, FastAPI, rules in YAML, no database
  platform-repo/dev/        namespace + quota + limitrange, postgres, catalog, storefront,
                            inventory, order, payment, advisor, ingress
  docs/
    architecture.md         full prose architecture
    architecture.pdf        13 pages, styled, diagrams embedded, current through the k3d run
    architecture-pdf.html   source of the PDF
    adr/                    nineteen decision records, each with its cost
    slo.md                  objectives, consequences, and which numbers are measured
    runbooks/               five runbooks; four reproduced locally, one written from docs
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

1. ~~Bring `docs/architecture.md` and `RELEASE-NOTES.md` up to date with the measured `core` +
   `commerce` numbers.~~ **Done** (16 September 2026). Both now carry the measured figures, the
   three k3d defects and fixes, the live-checkout walkthrough, and corrected "never run in k3d" /
   "no database tests" / "saga not crash-safe" claims that had gone stale since Phases 4, 5 and the
   ADR 0018 crash-recovery close. `CLAUDE.md` and `docs/getting-started-locally.md` picked up the
   same corrections in passing. `order-service/README.md`'s stale `StubPaymentGateway`-only
   description was also fixed (see next point).
   **New finding while doing this:** the `.wslconfig` memory override that
   `docs/getting-started-locally.md` has always instructed (`memory=11GB`) has never actually been
   applied on this machine — `/proc/meminfo` measures **7.4 GB**, not 11 GB. `core` + `commerce`
   fit fine either way, but the `observability` profile's ~9.2 GB estimate does not fit the
   *unconfigured* 7.4 GB ceiling at all, only the intended 11 GB one. This was invisible while every
   figure in the memory table was an unmeasured estimate sitting against an unmeasured ceiling.
   Applying it means editing `C:\Users\<you>\.wslconfig` on the Windows side and `wsl --shutdown`
   (which ends any WSL session, including this one) — not done, flagged for the user rather than
   done unilaterally.
2. ~~The PDF is now the next item.~~ **Done** (16 September 2026). `docs/architecture-pdf.html`
   was rewritten to mirror the current `architecture.md` (13 pages, up from 8, all Phase 1-only
   content replaced) and rendered to `docs/architecture.pdf` via a headless-Chromium/puppeteer
   script (not installed system-wide; run from a scratch Node checkout since this machine has no
   native Linux Node.js on PATH, only a Windows interop shim that can't build native modules from a
   WSL path). **A pre-existing template bug surfaced doing this:** the page CSS's `@page` height
   (`297mm`) had never matched its own `.page` div height (`386mm`) — a mismatch that predates this
   session and was invisible because no PDF had ever actually been rendered from this file before.
   Fixed by aligning `@page` to `386mm` and letting long sections flow onto a second physical page
   (`min-height` instead of a hard-clipped fixed height) rather than silently corrupting content.
   The diagrams (`docs/diagrams/generate.py`) were also updated: `order-service`, `inventory-service`,
   `payment-service` and `aquatics-advisor` now show as built/run-in-k3d rather than planned, and the
   deployment diagram lists all six running services with their measured footprints instead of just
   `core`.
3. **`full-app`, `platform` and `observability` profiles have never run in k3d.** No manifests
   *or code* exist yet for any of `platform` (Argo CD), `observability`, or `full-app`
   (notification-service, staff-portal) — this corrects an earlier version of this document, which
   claimed `full-app` "has manifests but hasn't been exercised"; there is nothing under
   `services/` or `platform-repo/dev/` for either service. All three are unbuilt, not just
   unexercised. `observability`'s ~9.2 GB estimate would not fit the unconfigured 7.4 GB WSL2
   ceiling even once built, until the `.wslconfig` override above is applied.
4. **Still not written:** the full local-to-cloud document (only the Phase 1 extract exists, in
   `docs/architecture.md` §9 and on page 7 of the PDF).

   *(The `payment-service` database test suite that was listed here is done: 18 gated tests.)*
5. **Phase 6:** observability and the delivery layer — the OTel collector, Tempo, a
   kube-prometheus-stack, and then Argo CD with the app-of-apps across dev, uat and prod. This is
   also where `order-service` gets the outbox that makes its saga crash-safe, and where NATS arrives
   to carry the retries (the `commerce` profile above ran without NATS — nothing in the current path
   needs it yet). Ends with a trace that follows one customer action from the storefront through the
   checkout saga to the ledger.

---

### First commerce-profile k3d run — notes worth carrying forward (16 September 2026)

- `./scripts/bootstrap.sh --profile commerce` brought up all six services together in-cluster for the
  first time: `catalog-service`, `storefront`, `inventory-service`, `order-service`,
  `payment-service`, `aquatics-advisor`, alongside `postgres`. Two more build-time defects surfaced,
  both toolchain-vs-lockfile drift, neither caught by any prior local run because local runs use
  whatever toolchain happens to be installed rather than the pinned Docker image:
  - `inventory-service`: `go.mod` declared `go 1.25.0`; the Dockerfile pinned `golang:1.24-bookworm`.
    `go mod download` refused to run. Fixed by bumping the Dockerfile to `golang:1.25-bookworm`.
  - `payment-service`: `Cargo.lock` resolved `home v0.5.12`, whose own manifest requires Cargo's
    `edition2024` feature (stabilized in Rust 1.85); the Dockerfile pinned `rust:1.82-bookworm`,
    matching the crate's declared `rust-version` but not what the lockfile actually needed. Fixed by
    bumping the Dockerfile to `rust:1.90-bookworm`. The crate's own `rust-version = "1.82"` is now a
    floor for the first-party code, not a guarantee that `cargo build` succeeds with it.
- **A live checkout ran the full saga in-cluster for the first time**, from outside the ingress (a
  temporary `curlimages/curl` pod inside the namespace, since `order-service` is intentionally not
  exposed through the public ingress — only the storefront and `inventory-service` are meant to call
  it): create a cart, add a line (`INV-AMA-01`, Amano Shrimp × 2), checkout with an
  `Idempotency-Key`. Result: `201`, order state `CONFIRMED`, reservation state `COMMITTED`,
  `paymentRef` set, dispatch window `2026-09-21T14:00+05:30` (the next Monday after the Thursday
  16 Sep cutoff — the shipping calendar rule working correctly against a real clock). The order-event
  audit trail showed exactly the documented state machine: `PENDING → STOCK_RESERVED → PAID →
  CONFIRMED`, each transition timestamped a fraction of a second apart. `inventory-service` correctly
  reflected the sale afterward (`held: 0`, `onHand` reduced by the purchased quantity).
- Total node memory for `core` + `commerce` together: 2052 MiB, up from `core` alone's 1322 MiB — so
  the four commerce services together cost ~730 MiB, not the ~1.6 GB the additive estimate implied.
- One pre-existing note confirmed still true: `order-service`'s README documents a `StubPaymentGateway`
  gated by `PAYMENT_STUB_OUTCOME`, but the running service logs `payment gateway: payment-service over
  HTTP` — it already talks to the real `payment-service` over HTTP, not the stub. The README section
  describing the stub is about an earlier phase and is now misleading; worth a follow-up edit, not
  done in this session since it's a docs-accuracy nit, not a runtime defect.

### First k3d run — notes worth carrying forward (16 September 2026)

- `core` profile: cluster up, both images built and imported, `catalog-service` and `storefront`
  rolled out, both answering 200 through `https://aquashop.localtest.me/` and `ingress-nginx` with
  the self-signed CA. First time this repository has run in a cluster rather than against a bare
  local Postgres.
- The defect: every pod (not just catalog and storefront — all six `platform-repo/dev/*` manifests
  carry the same pattern) sat in `CreateContainerConfigError`. The distroless `:nonroot` base images
  set `USER nonroot`, a name; `runAsNonRoot: true` alone gives kubelet nothing numeric to check
  without running the container. Fix: `runAsUser: 65532` / `runAsGroup: 65532` (Google's distroless
  nonroot UID) added explicitly to the pod securityContext in all six deployments. Caught by running
  the pod, exactly the way this project expects defects to surface — review of the YAML alone would
  not have caught it, because `runAsNonRoot: true` reads as complete.
- A `PLACEHOLDER` image tag is checked into every deployment manifest by design (`# CI rewrites this
  to the git SHA`); the first ReplicaSet briefly tries to pull `aquashop/<service>:PLACEHOLDER` from
  Docker Hub and fails with `ErrImagePull` before `bootstrap.sh`'s own `kubectl set image` step
  supersedes it. Cosmetic on a from-scratch bootstrap; on a rolling update against a real registry it
  would not happen at all, since CI would have already rewritten the tag.
- Flyway ran its 8 migrations against Postgres inside the cluster on first boot, cleanly — no repeat
  of the Phase 1 mapping defects, which were fixed long before this session.
- `kubectl top` (via metrics-server, installed with `--metrics`) gives the first honest node-level
  number: 1.32 GiB for the whole `core` profile including k3s system pods, cert-manager,
  ingress-nginx, CoreDNS and metrics-server itself — comfortably under the ~2.6 GB estimate that
  stood in for it until now.


### Phase 1 verification notes — worth carrying forward

- Phase 1 was written, reviewed and committed without ever being executed, and it did not boot.
  Two mapping defects, both caught by `ddl-auto: validate`, both fatal at startup. Review does not
  substitute for running the thing.
- `CHAR(3)` maps to `bpchar` and fails validation against a `String` field. Use `VARCHAR(n)`.
- A `NUMERIC(n,1)` column needs a `BigDecimal` field. Hibernate refuses `precision`/`scale` on a
  `double` outright — "scale has no meaning for SQL floating point types" — which is the mapping
  saying the field type is wrong, not the annotation.
- The SKU string is the whole contract between `catalog-service` and `inventory-service`. Check it
  against the other service's seed data rather than assuming; a drift is invisible in both
  databases and shows up as a product the customer cannot buy.
- Verified by hand with the catalog stopped: storefront liveness stayed 200, readiness went 503,
  the page returned 502. The design's most-repeated claim, demonstrated for the first time.

---

### Phase 3 implementation notes worth carrying forward

- Reserve before charging. The ordering is the whole design; see `docs/adr/0012-*`.
- A `@Transactional` method that calls another service is a trap. The rollback erases the record of
  effects that already happened elsewhere, and the compensation is then blind. Commit the record of
  an external effect as soon as it happens; `docs/adr/0013-*`.
- Spring's `@Transactional` does nothing when the method is called from inside the same class — the
  proxy is bypassed silently. The saga steps live in their own bean for that reason alone.
- `PAID -> PAYMENT_FAILED` must not exist in the state machine. Make the worst outcome unreachable
  rather than unlikely.
- Compensations: idempotent, `REQUIRES_NEW`, and they must swallow their own failures so they cannot
  mask the original one.
- The `ResourceQuota` counted `limits.cpu`, which makes a CPU limit mandatory, and the `LimitRange`
  default then supplied one. Every JVM service had been throttled since Phase 1 by a file that says
  nothing about JVMs. Check the namespace before believing a deployment manifest.
- The dispatch calendar is pure and clock-injected. "What happens at 13:59 on a Wednesday" should be
  a test, not a discussion.

---

### Phase 4 implementation notes worth carrying forward

- "Unknown" is a third answer, not a flavour of failure. Every layer has to keep it distinct: the
  acquirer stub, payment-service's 504, the HTTP gateway's exception type, and the order state.
  Flattening it anywhere loses the property everywhere.
- Write the intent BEFORE the external call. payment-service does; order-service's saga still does
  not, and that is the Phase 6 outbox.
- A lookup that says "no charge" is not proof that no charge will be made. Voiding on it wrote off a
  payment the customer was charged for five seconds later. Only void beyond a window that exceeds
  the acquirer's in-flight time -- or better, call an explicit cancel, which this stub has no
  equivalent of.
- Two resolvers (the caller retrying and the reconciler) will race. A conditional
  `UPDATE ... WHERE state = 'pending'` makes the loser write nothing, which is why both can run
  without coordination.
- Rust earned its place with a number: 6 MiB against 361 MiB for comparable work. The exhaustive
  matching is the other half -- there is no `_ =>` anywhere in the ledger machine, deliberately.
- payment-service's constraints live in SQL, so they need a database to test. Making the crate a
  lib plus a thin binary is what allows `tests/` to import it at all -- a binary crate cannot be.
- The two-resolver race is the test worth keeping: two `apply` calls that both believe the payment
  is pending, and exactly one write. A second ledger entry there is a second charge on the books
  for one charge at the bank.

---

### Phase 5 implementation notes worth carrying forward

- Thresholds live in rules.yaml with a sentence of justification each, and the API quotes those
  sentences to the customer. A rule that cannot explain itself should not be in the file.
- The tests load the SHIPPED rules file. That is what makes a loosened threshold visible.
- Rules are read once at startup, never hot-reloaded: two pods answering differently mid-rollout is
  worse than waiting for a deployment, and every response carries the rules version.
- Three verdicts. No overlap at all is a refusal; a narrow overlap is a caution. They are different
  problems.
- A size-only predation rule refuses a kuhli loach with neon tetras. What predicts predation is
  mouth gape, which the catalog does not record; the rule is limited to aggressive species, and the
  remaining gap (a peaceful angelfish eating neons) is written down rather than hidden.
- `combinations` never pairs a species with itself, so the same-species check had to be explicit --
  without it, two male bettas passes everything.
- A fourth Phase 1 defect surfaced here: GET /api/products returned 500 because the inherited
  findAll() does not join-fetch the category. I had seen that error in an earlier session and blamed
  my own shell one-liner. A second consumer calling it for real is what exposed it.

---

### Catalogue tree notes worth carrying forward

- Roots-only at `/api/categories`. A client that has to filter a flat list to draw a menu has to
  understand the tree, which is the service's job.
- Publish `browsable` alongside `status`. A client keeping its own list of "statuses that mean yes"
  goes stale the first time one is added.
- Tile counts are subtree counts. A branch holds no products of its own.
- The recursive CTE returns category *ids*; products are then loaded by JPQL with `join fetch`.
  A native query returning `product.*` maps a lazy category proxy and blows up at render time --
  the same defect that took down `GET /api/products`.
- Real stock found a backwards rule in the advisor: mbuna are aggressive AND kept in twelves. Check
  `min_group_size` before refusing a species for being kept with itself.
- Images are stored as KEYS (`species/demasoni.jpg`), never URLs. The storefront composes the URL
  from `IMAGE_BASE_URL`, so a CDN move is configuration rather than a migration over every row.
- No photograph in the repository may be one found through an image search. The shop is a commercial
  use; the rule and the reasoning are in `services/storefront/public/species/README.md`.

---

### Known limitations to state plainly, never soften

- Secrets are plaintext in Git at Phase 1. Largest gap in the repo. Phase 5 replaces it.
- Single-node cluster: PodDisruptionBudgets, anti-affinity and node drains are configured in later
  phases but cannot be exercised.
- The AWS layer has never been applied.
- No performance number is measured under sustained load for anything, in or out of k3d.
- All six services have run outside k3d, against a local Postgres, **and now all six have run *in*
  k3d** (`core` + `commerce` profiles, 16 September 2026) — probes, resource limits, ingress/TLS
  (for `catalog-service`/`storefront`), and a live checkout across `order-service`,
  `inventory-service` and `payment-service` together are all exercised in-cluster. Not yet exercised
  in-cluster: sustained load, a `kill -9` mid-checkout against the in-cluster saga specifically (the
  crash-recovery demonstration below was outside k3d), and the `full-app`/`platform`/`observability`
  profiles.
- ~~The checkout saga is not crash-safe.~~ **Closed.** `SagaRecovery` scans for orders stuck in PAID
  or STOCK_RESERVED and finishes them; demonstrated with a real `kill -9` mid-checkout. It is a
  state scan rather than an outbox -- see `docs/adr/0018-*`, which amends 0015.
- `payment-service`'s acquirer is a stub: no partial captures, no chargebacks, no 3-D Secure, no
  settlement files, and an in-process memory that a restart wipes.
- The card acquirer is stubbed, so nothing here proves behaviour against a real payment network.
- `aquatics-advisor` has no automated test of its HTTP layer or its catalog client, and its image is
  not distroless. Both are stated in its README rather than left to be found.
- Ten photographs are committed and ten products carry them. Three Malawi fish (saulosi, red zebra,
  acei) and all seven sections still have keys pointing at files nobody has taken -- they render as
  placeholders, which is the designed behaviour.
- **Every photograph in the repository has unverified provenance**, recorded row by row in
  `services/storefront/public/species/CREDITS.md`. They are there so the site can be reviewed against
  real images; none may ship until it is the shop's own, licensed, or breeder-supplied.
- `catalog-service`'s test suite uses Testcontainers, so it could not be executed in the session that
  wrote the tree tests. Every assertion was verified by hand against the running service instead --
  which is weaker, and is why the first CI run after this change is worth watching.

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
