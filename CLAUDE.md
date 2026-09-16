# AquaShop — working notes for Claude

A polyglot Kubernetes platform for a freshwater aquarium shop. Designed for AWS, validated with
mock providers, run on k3d, **never applied to an AWS account**.

This file is tracked in Git, so it reaches every session — local, web, or otherwise. It is the only
thing that does. Conversation history and `~/.claude/` settings are per-machine.

Read [docs/context_summary.md](docs/context_summary.md) for current state and open items, and
[RELEASE-NOTES.md](RELEASE-NOTES.md) for what has actually been measured.

## The one thing to know first

**Nothing in this repository has ever run in k3d.** No session has had a Docker daemon.
`scripts/bootstrap.sh` is written, reviewed and unexecuted. Every service has been verified by
running it directly against a local Postgres, and every memory figure except one is an estimate.

If you are in a session that *does* have Docker, that is the highest-value thing you can do. See
[docs/getting-started-locally.md](docs/getting-started-locally.md).

## How this project works

**Verify by running, not by reading.** Every defect of consequence in this repository was found by
running something: the oversell race, the premature payment void, two backwards advisor rules, a
lazy-loading 500, a saga that could not survive a crash, an advisor that refused one of the
best-known good tanks in the hobby. Several had been reviewed and looked fine. If you change
behaviour, start the service and exercise it.

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
- **Memory profiles are load-bearing.** ~11 GB does not hold the whole platform. Never build images
  while the observability profile is up.

## Testing

```bash
cd services/catalog-service  && mvn test     # needs Docker (Testcontainers) — has never run
cd services/inventory-service && go test ./...
cd services/order-service    && mvn test     # 55 tests
cd services/payment-service  && cargo test   # 18 DB tests need PAYMENTS_TEST_DSN
cd services/aquatics-advisor && python3 -m pytest    # 35 tests
```

`CatalogApiTest` requires Testcontainers and has never been executed in any session. Its numbers
were verified by hand against a running service, which is not the same thing — a contradiction
inside it (two tests asserting different counts from the same endpoint) survived undetected because
of exactly that gap.

## Known gaps, in order of how much they matter

1. Nothing has run in k3d. Every memory figure is an estimate.
2. Secrets are plaintext in Git. External Secrets + SOPS is planned, not built.
3. Observability and Argo CD are budgeted profiles with no manifests behind them.
4. Photograph licensing: every row in `services/storefront/public/species/CREDITS.md` says
   `unverified`, and must not reach a commercial launch that way.

## Git

Branch: `claude/clever-shannon-ivtkw6`. There is no `main`; this branch is the remote default.

Pull before starting, push before stopping, one session at a time on a branch. A web session and a
local session cannot see each other's uncommitted work.
