# AquaShop — working notes for Claude

A polyglot Kubernetes platform for a freshwater aquarium shop. Designed for AWS, validated with
mock providers, run on k3d, **never applied to an AWS account**.

This file is tracked in Git, so it reaches every session — local, web, or otherwise. It is the only
thing that does. Conversation history and `~/.claude/` settings are per-machine.

Read [docs/context_summary.md](docs/context_summary.md) for current state and open items, and
[RELEASE-NOTES.md](RELEASE-NOTES.md) for what has actually been measured.

## The one thing to know first

**Both `core` and `commerce` have now run in k3d** (16 September 2026) — the first session with a
Docker daemon. All six original services are up, a live checkout ran the full saga (reserve → authorise →
commit → confirm) through `order-service`, `inventory-service` and `payment-service` together,
in-cluster, and ended `CONFIRMED` with a committed reservation and a correct dispatch window. Running
it found three real defects, all fixed: see below. Measured figures for `core` and
`commerce` are in [docs/context_summary.md](docs/context_summary.md); the whole platform (all six
services plus k3s, ingress, cert-manager) came in at ~2 GiB, well under every prior estimate.

`notification-service` and `staff-portal` are now built too — code, tests, Dockerfiles, manifests,
`bootstrap.sh --profile full-app` — same session. Each builds and passes its own tests standalone
(staff-portal additionally verified by actually running the container: clean boot in ~2.8 s,
correct non-root UID, working stdout logging). But **`full-app` has not run successfully in k3d**:
three attempts were blocked before a single pod deployed, by a memory preflight sitting right at the
edge of this machine's unconfigured ~7.4 GB WSL2 ceiling and, once, a transient Helm/GitHub network
timeout. `full-app`'s real memory requirement is therefore still unknown — the run never got far
enough to import an image. `platform` and `observability` haven't run either, and have no manifests
yet.

## How this project works

**Verify by running, not by reading.** Every defect of consequence in this repository was found by
running something: the oversell race, the premature payment void, two backwards advisor rules, a
lazy-loading 500, a saga that could not survive a crash, an advisor that refused one of the
best-known good tanks in the hobby, and — first time in k3d — three build/deploy defects that no
amount of review had caught: a `runAsNonRoot: true` pod securityContext that kubelet could not
verify because the distroless images' `USER nonroot` is a name, not a UID; `inventory-service`'s
`go.mod` requiring Go 1.25 while its Dockerfile pinned 1.24; and `payment-service`'s Cargo.lock
resolving a transitive dependency that needs Cargo's `edition2024` feature, unavailable on the
pinned Rust 1.82. All three only surface when the image is actually built and run. Several had been
reviewed and looked fine. If you change behaviour, start the service and exercise it.

**State the cost of every decision.** ADRs carry a `## Cost` section and it is never empty. A
decision with no downside has not been thought about.

**Never soften a limitation.** If something is unproven, the docs say unproven. If a number is an
estimate, it is labelled an estimate. "Should work" is not a status.

**Comments explain why, not what.** The codebase's comments carry the reasoning that would
otherwise be lost — why `FOR UPDATE` is two statements, why there is no `limits.cpu` in the quota,
why the advisor's rules are a YAML file. Match that when you add code.

## Layout

| Path | What |
|---|---|
| `services/catalog-service` | Java 21 / Spring Boot. Products, categories, species care profiles. Owns the only data anyone else reads |
| `services/inventory-service` | Go. Tank-scoped, TTL-bounded, idempotent stock reservations |
| `services/order-service` | Java. Checkout as a saga with compensation and crash recovery |
| `services/payment-service` | Rust / Axum. Append-only ledger, enforced by a Postgres trigger |
| `services/aquatics-advisor` | Python / FastAPI. Whether a tank will work. No database of its own |
| `services/storefront` | TypeScript / Fastify. Server-rendered |
| `services/notification-service` | Go. Email/webhook fan-out, pushed to by `order-service` (ADR 0020). Built, not yet run in k3d |
| `services/staff-portal` | JSP / Jakarta EE on WildFly. Read-only back-office. Built, not yet run in k3d |
| `platform-repo/dev/` | The dev overlay. Moves to its own repository at Phase 4 |
| `docs/adr/` | One record per expensive-to-reverse decision |
| `docs/runbooks/` | One page per failure, written to be followed at 02:00 |

## Rules that are not obvious

- **Migrations are forward-only and numbered.** `catalog-service` uses Flyway, `inventory-service`
  an embedded Go migrator with an advisory lock, `payment-service` sqlx. Never edit a migration
  that has been deployed. Nothing here has been deployed anywhere yet, so editing is currently
  safe — that stops being true the day `bootstrap.sh` runs against a cluster you keep.
- **`ddl-auto: validate`, never `update`.** It caught two mapping defects on the catalog's first
  ever boot. Keep it.
- **`open-in-view: false`.** Every repository query that feeds a DTO must join-fetch what the DTO
  reads. The inherited `findAll()` is the trap; it caused a 500 in production-shaped testing.
- **The catalogue owns species facts; the advisor owns rules about them.** ADR 0017 and ADR 0019.
  The advisor keeps no copy of a species profile — a copy is a second source of truth that drifts
  on the first correction.
- **`image_key`, never `image_url`.** The storefront composes `IMAGE_BASE_URL + key`, so moving to
  a CDN is a ConfigMap change. A key with no file behind it renders a broken image, so leave it
  NULL until the photograph exists.
- **No `limits.cpu` in the ResourceQuota.** A quota counting `limits.cpu` makes a CPU limit
  mandatory, and with a LimitRange default every JVM is silently CFS-throttled. This reversed
  ADR 0006 once already.
- **Memory profiles are load-bearing.** The design targets 11 GB usable inside WSL2 via the
  `.wslconfig` override in `docs/getting-started-locally.md`, but that override has never been
  applied on this machine — `/proc/meminfo` measures ~7.4 GB, WSL2's unconfigured default. The
  `observability` profile's ~9.2 GB estimate does not fit that unconfigured ceiling at all; it does
  fit the intended 11 GB one. Never build images while the observability profile is up.
- **A distroless `nonroot` image needs `runAsUser: 65532` explicitly.** `runAsNonRoot: true` alone
  is not enough — kubelet cannot verify a `USER nonroot` (a name) without running the container, and
  every service hits `CreateContainerConfigError` until the numeric UID is spelled out in the pod
  securityContext. All six `platform-repo/dev/*/deployment.yaml` files carry this now.
- **A Dockerfile's pinned toolchain version is a claim that gets stale silently.** `go.mod`'s `go`
  directive and `Cargo.lock`'s resolved transitive dependencies can both drift ahead of what a
  Dockerfile pins, and `mvn`/`go build`/`cargo build` inside CI or a local dev shell won't catch it
  — only building the actual image does. `inventory-service` (`golang:1.25-bookworm`) and
  `payment-service` (`rust:1.90-bookworm`, needed for Cargo's `edition2024` feature) both had to be
  bumped past what their own manifests declare as MSRV once this ran for the first time.

## Testing

```bash
cd services/catalog-service  && mvn test     # needs Docker (Testcontainers) — has never run
cd services/inventory-service && go test ./...
cd services/order-service    && mvn test     # 55 tests, 18 skipped (DB-gated)
cd services/payment-service  && cargo test   # 18 DB tests need PAYMENTS_TEST_DSN
cd services/aquatics-advisor && python3 -m pytest    # 35 tests
cd services/notification-service && go test ./...   # integration test needs NOTIFICATION_TEST_DSN
cd services/staff-portal     && mvn test     # 3 tests, no DB (reads only, no DB of its own)
```

`CatalogApiTest` requires Testcontainers and has never been executed in any session. Its numbers
were verified by hand against a running service, which is not the same thing — a contradiction
inside it (two tests asserting different counts from the same endpoint) survived undetected because
of exactly that gap.

## Known gaps, in order of how much they matter

1. `full-app`, `platform` and `observability` profiles have never run in k3d — their memory figures
   remain estimates. `core` and `commerce` are both measured now. `full-app` has manifests and
   passing builds/tests but three live attempts were blocked by the unconfigured WSL2 memory
   ceiling before deploying a single pod — see `docs/context_summary.md`.
2. Secrets are plaintext in Git. External Secrets + SOPS is planned, not built.
3. Observability and Argo CD (`platform`) are budgeted profiles with no manifests behind them yet;
   `full-app` now has manifests (notification-service, staff-portal) but is unverified in k3d.
4. Photograph licensing: every row in `services/storefront/public/species/CREDITS.md` says
   `unverified`, and must not reach a commercial launch that way.
5. `staff-portal` is read-only: no stock-adjustment, species-editing, or claims workflow, because
   none of those have a backend write endpoint on any service yet. A DOA-claims model doesn't exist
   anywhere in the codebase — `architecture.md`'s "staff manage tanks, stock, claims" actor
   description is a target, not what's built.

## Git

Branch: `claude/clever-shannon-ivtkw6`. There is no `main`; this branch is the remote default.

Pull before starting, push before stopping, one session at a time on a branch. A web session and a
local session cannot see each other's uncommitted work.
