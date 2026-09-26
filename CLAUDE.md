# AquaShop — working notes for Claude

A polyglot Kubernetes platform for a freshwater aquarium shop. Designed for AWS, validated with
mock providers, run on k3d, **never applied to an AWS account**.

This file is tracked in Git, so it reaches every session — local, web, or otherwise. It is the only
thing that does. Conversation history and `~/.claude/` settings are per-machine.

Read [docs/context_summary.md](docs/context_summary.md) for current state and open items,
[RELEASE-NOTES.md](RELEASE-NOTES.md) for what has actually been measured, and
[agent_learningz.md](agent_learningz.md) for mistakes already made and the pattern behind each one
— check it before starting non-trivial work, and add to it when you make one or catch one from a
previous session. It is external memory, not a change log: keep entries short, and remove one once
it's become a structural guarantee (a test, a constraint, a rule already stated in this file)
rather than a judgment call.

## The one thing to know first

**`core`, `commerce` and `full-app` have all now run in k3d** (16–17 September 2026) — the first
sessions with a Docker daemon. All eight services are up together, a live checkout ran the full saga
(reserve → authorise → commit → confirm) through `order-service`, `inventory-service` and
`payment-service`, and pushed a real notification through `notification-service` end to end
(`HttpNotificationClient` → `POST /v1/events` → `202` → stub email logged delivered four seconds
later). Running it found real defects each time, all fixed or worked around: see below. Measured
figures are in [docs/context_summary.md](docs/context_summary.md) — `core`+`commerce` together came
in at ~2 GiB, `full-app` (all eight services) at ~2.2 GiB, both well under every prior estimate.

`full-app` took three attempts across two days: two blocked outright by a memory preflight sitting
right at the edge of this machine's unconfigured ~7.4 GB WSL2 ceiling, a third that passed the
preflight and then hit a genuine rollout deadlock — `staff-portal`'s `maxUnavailable: 0` strategy
kept a permanently-`ImagePullBackOff`'d placeholder pod alive forever, and its stuck quota reservation
starved the real pod's own request. Fixed by hand in the cluster (deleted the stuck ReplicaSet) and
then for real in `platform-repo/dev/staff-portal/deployment.yaml` (`maxUnavailable: 1, maxSurge: 0`
now, so the old pod is torn down before the new one is created) — **re-verified same day**: deleted
just `staff-portal`'s own objects and reapplied fresh into the still-full namespace, reproducing the
exact original conditions. Clean single-attempt rollout, no manual intervention needed. See
RELEASE-NOTES for the full account. `platform` and `observability` haven't run and have no
manifests yet.

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
| `services/order-service` | Java. Checkout as a saga with compensation and crash recovery. Also custom tank enquiries (ADR 0021) |
| `services/payment-service` | Rust / Axum. Append-only ledger, enforced by a Postgres trigger |
| `services/aquatics-advisor` | Python / FastAPI. Whether a tank will work. No database of its own |
| `services/storefront` | TypeScript / Fastify. Server-rendered |
| `services/notification-service` | Go. Email/webhook fan-out, pushed to by `order-service` (ADR 0020). Runs in k3d, 5 MiB measured |
| `services/staff-portal` | JSP / Jakarta EE on WildFly. Read-only back-office. Runs in k3d, 456 MiB measured |
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
  `.wslconfig` override in `docs/getting-started-locally.md`. That file was written on this machine
  17 September 2026 (`C:\Users\sayan\.wslconfig`) and **has since been applied** — `/proc/meminfo`
  measured ~7.4 GB as of that date and now measures ~11 GB (confirmed 22 September 2026), so the
  `wsl --shutdown` needed to apply it happened at some point between sessions, undocumented at the
  time. The `observability` profile's ~9.2 GB estimate no longer exceeds the ceiling on paper, but it
  remains unbuilt and unmeasured — a number fitting a budget on paper is not the same claim as a
  number that has been measured. Never build images while the observability profile is up.
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
cd services/order-service    && mvn test     # 77 tests, 34 skipped (DB-gated); 0 skipped with ORDER_TEST_DSN
cd services/payment-service  && cargo test   # 18 DB tests need PAYMENTS_TEST_DSN
cd services/aquatics-advisor && python3 -m pytest    # 35 tests
cd services/notification-service && go test ./...   # integration test needs NOTIFICATION_TEST_DSN
cd services/staff-portal     && mvn test     # 3 tests, no DB (reads only, no DB of its own)
```

`CatalogApiTest` **first ran on 26 September 2026**: 34 tests, **6 failing, all pre-existing** —
stock counts and image-key assertions written before `V11`–`V15` added products and photographs,
and never updated because the suite had never run. They are stale assertions, not regressions, and
are left for a deliberate decision rather than bumped to whatever the database says today. Two
things are needed to run it on this machine, since there is no local Maven and the project's
Testcontainers speaks a Docker API (1.32) older than Docker 29 accepts (1.40+):

```bash
echo "api.version=1.44" > /tmp/docker-java.properties
docker run --rm -v "$PWD":/build -w /build -v aquashop-m2:/root/.m2 \
  -v /tmp/docker-java.properties:/root/.docker-java.properties \
  -v /var/run/docker.sock:/var/run/docker.sock -e TESTCONTAINERS_HOST_OVERRIDE=172.17.0.1 \
  maven:3.9-eclipse-temurin-21 mvn -B -q test
```

`target/` comes out root-owned from that container.

<!-- BEGIN: custom tank enquiries (23 September 2026) -->
## Custom tank enquiries — the one encrypted table

A section on the shop front where a visitor describes the tank and stocking they want and leaves an
email address and a phone number. **[ADR 0021](docs/adr/0021-encrypt-enquiry-contact-details-in-postgres.md)
is the whole decision**; what follows is what you need to not break it.

- **It lives in `order-service`, not a ninth service.** One table (`tank_inquiry`, `V3`), one
  handler (`POST /v1/inquiries`), nothing touching `customer_order`, `order_line`, `order_event` or
  the saga. An enquiry is not a checkout.
- **Postgres encrypts, not Java.** `pgcrypto`'s `pgp_sym_encrypt` on `email`, `phone` **and** the
  free-text message, all `BYTEA`, AES-256, compression off. Same instinct as `payment-service`'s
  append-only trigger: an invariant that must not be lost belongs in the database, not in a code
  review. `tank_inquiry` is the only table here that is deliberately **not** a JPA entity — a mapped
  entity would keep the plaintext in Hibernate's caches.
- **`message_chars` is the one plaintext column.** It exists so "are enquiries arriving, and are
  they empty?" is answerable by someone who is not entitled to read them.
- **The key is not in Git and never will be.** `INQUIRY_ENCRYPTION_KEY` comes from a Secret called
  `order-inquiry-key`, created by hand, out of band. `bootstrap.sh` does not create it and
  `kubectl apply -k` will not restore it. **A rebuilt cluster needs the command in
  [docs/runbooks/rotate-or-create-the-inquiry-key.md](docs/runbooks/rotate-or-create-the-inquiry-key.md)
  run again.** This is the first secret in the repository that is not plaintext in Git; it is an
  improvement on known gap 2 below, not a fix for it.
- **No key disables this one endpoint and nothing else.** `order-service` starts normally, logs one
  `WARN`, serves carts/checkout/the saga as always, and `POST /v1/inquiries` alone answers `503`
  with a body naming the runbook. There is still no fallback key and still nothing written in
  plaintext — a default key would write rows that look encrypted and are not, and orphan them the
  day a real key arrives. A key under 16 characters is refused the same way. **The `secretKeyRef` in
  `platform-repo/dev/order/deployment.yaml` must keep `optional: true`** or kubelet leaves the pod in
  `CreateContainerConfigError` and the whole point is lost. The cost of this shape is that the
  feature can be silently off on a green-looking cluster; the `WARN`, the `bootstrap.sh` warning and
  the storefront's honest 503 message are the mitigation. All verified on a real running process.
- **Write-only.** No `GET`, no list, no `Location` header. The shop's only way to read an enquiry
  today is `psql` plus the key — a real gap, recorded as one, waiting on authentication existing
  anywhere in this platform before a `staff-portal` read path can be honest.
- **No rate limiting.** A public, unauthenticated `POST`. A 16 KiB body limit at the BFF and a
  4,000-character cap are the only bounds. Fix this before this goes anywhere real.
- **The storefront is no longer GET-only.** `@fastify/formbody`, `POST /inquiries`,
  `GET /inquiries/thanks`, and `ORDER_BASE_URL` — its first call to `order-service`. Readiness still
  checks only the catalog, on purpose.

<!-- END: custom tank enquiries -->

## Known gaps, in order of how much they matter

1. `platform` and `observability` profiles have never run in k3d and have no manifests — their
   memory figures remain estimates. `core`, `commerce` and `full-app` are all measured now.
2. Secrets are plaintext in Git. External Secrets + SOPS is planned, not built.
3. Observability and Argo CD (`platform`) are budgeted profiles with no manifests behind them yet.
4. Photograph licensing: the original 10 shop-owner photos in
   `services/storefront/public/species/CREDITS.md` are still `unverified` and must not reach a
   commercial launch that way. A second batch (32 images, 17–18 September 2026) plus a re-attempt at
   the gaps it left (2 more, 22 September 2026) is sourced from Wikimedia Commons under
   CC0/public-domain/CC-BY/CC-BY-SA licences only, each verified against the Commons API and recorded
   with source/licence/artist in CREDITS.md — those 34 are launch-eligible as recorded, not
   "unverified." **All 55 products carry a photograph now**, but the last 11 (22 September 2026, same
   day, later session) are **demo-complete, not launch-eligible**, and were added at explicit user
   direction to make the site look finished. Their licences were verified exactly as the first 34's
   were — that bar did not move — but resolution, species precision, product form and third-party
   trademark all did. Five are Lanczos upscales from below the 1200×900 floor; `bristlenose-pleco` and
   `otocinclus` are genus-level *sp.* IDs; `master-test-kit` is a teaching-lab test-tube rack, not an
   aquarium test kit; `canister-filter-400lph` carries a legible FLUVAL 204 trademark on a product the
   shop does not sell, which is the one that becomes a legal problem rather than a quality problem the
   day this goes anywhere real. `canister-filter-400lph.jpg` is also the only file in that directory
   whose outer thirds are synthetic (a blurred copy of itself, to fill 4:3 from a portrait source).
   Row-by-row caveats and every upscale's original dimensions are in CREDITS.md.
   `catalog-service`'s `V9__licensed_photography.sql` wires the 32 `image_key`s in,
   `V10__licensed_photography_gap_reattempt.sql` the 2 and `V11__demo_complete_photography.sql` the
   last 11; V9's header still says "the other 13 stay NULL," corrected in V10 and V11 rather than by
   editing V9, which Flyway has already applied.

<!-- BEGIN: monster fish, arowana and section photography (23 September 2026) -->
   **Addendum, 23 September 2026 — the counts in item 4 above are now stale, and the section tiles
   are no longer empty.** `V12`–`V15` add two categories (`catfish-predatory` under `catfish-large`,
   `arowana` under `freshwater`), fourteen products and eleven species profiles: three large
   predatory catfish, *Cyrtocara moorii*, four American cichlids and six arowana. **The catalogue is
   69 products across 40 categories now, not 55 across 38**, and all 69 carry a photograph.
   - **Every category had `image_key IS NULL` until `V14`** — all of them, root and leaf, since `V7`
     cleared `V5`'s keys-with-no-files. `services/storefront/public/sections/` held a README and
     nothing else. It now holds 40 photographs and a `CREDITS.md` in the same format as the species
     one. A section tile is thematic rather than a specimen, so subject precision is looser there by
     design; the licence bar is not. One correctly-licensed candidate was rejected outright for
     having no machine-readable author — a share-alike licence naming nobody cannot be attributed.
   - **The 14 new species photographs were sourced at the original bar, not `V11`'s relaxed one.**
     Correct species, at or above 1200×900 before cropping, no third-party trademark. The real caveat
     is the four Asian arowana trade morphs: all four are genuinely *Scleropages formosus*, but
     Commons does not index by farm line. Only Golden Crossback's caption ("Quá bối," Vietnamese for
     cross-back) and Green's ("Green Arowana," stated outright) confirm the morph; Super Red's caption
     names the right trade term ("Honglongyu") but the photographed fish reads olive-gold rather than
     visibly red, and Red Tail Golden's source names no morph at all — both of those two are ours by
     eye, and `CREDITS.md` says so plainly rather than implying a caption confirms what it doesn't.
   - **`asian-arowana-*` care notes lead with CITES Appendix I**, and so do the product summaries.
     That is a legal fact about the animal — restricted or outright illegal to own in many countries
     including the US — not project flavour text, and it is the first sentence a customer reads
     rather than a footnote.
   - **`flowerhorn`'s `scientific_name` is the literal string `Hybrid (Amphilophus spp. x others)`.**
     The column is `NOT NULL` and the fish is a man-made hybrid line with no valid binomial; a
     plausible-looking invented name would read as a real taxon to a customer and to the advisor.
     `care_notes` opens with "This is not a species."
<!-- END: monster fish, arowana and section photography -->

   **Addendum, 26 September 2026 — counts stale again.** `V17`–`V20` take the catalogue to 171
   products and add an "About this fish" description column; six arowana/flowerhorn photos were
   replaced with owner-picked Pexels images (Pexels License, not Commons — a second licence source,
   recorded per row in `species/CREDITS.md`). Current state is in `docs/context_summary.md`.

5. `staff-portal` is read-only: no stock-adjustment, species-editing, or claims workflow, because
   none of those have a backend write endpoint on any service yet. A DOA-claims model doesn't exist
   anywhere in the codebase — `architecture.md`'s "staff manage tanks, stock, claims" actor
   description is a target, not what's built.

<!-- BEGIN: storefront visual redesign (24 September 2026) -->
6. **The storefront looks nothing like the dark, teal-accented theme earlier sessions built.**
   `services/storefront/public/styles.css` was rewritten in three passes against direct user
   feedback: an Apple-inspired light/dark design system, then a nav hover dropdown (since replaced,
   26 September 2026, by a category sidebar of native `<details>` with a half-opacity photo preview
   on hover, plus a header search box with a section picker — `GET /search`, backed by
   `GET /api/products?q=&in=` and the new `GET /api/category-tree`; still no JS, ADR 0005 holds),
   then an aquarium-tinted palette (blue-white background, green accent), price hidden
   on the homepage shelf only, bigger base type, and a flexbox rewrite of `.grid`/`.tiles` that fixed
   a real defect: CSS Grid's column count is fixed for the whole grid, so a ragged last row (six
   cards splitting 4-then-2) left dead space beside the short row instead of the items stretching to
   fill it. Full account in RELEASE-NOTES; the CSS Grid lesson and a `position: sticky` +
   screenshot-tool false-positive are both in `agent_learningz.md`.
<!-- END: storefront visual redesign -->

## Git

Branch: `claude/clever-shannon-ivtkw6`. There is no `main`; this branch is the remote default.

Pull before starting, push before stopping, one session at a time on a branch. A web session and a
local session cannot see each other's uncommitted work.
