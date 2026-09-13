# AquaShop — Context Summary

*Paste this as the opening message of a new session, together with the original project brief.
It is the state of the work, not a restatement of the brief.*

**Last updated:** end of Phase 1 build session.

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
| CPU limits | Requests only on JVM services; memory limits always | A CPU limit means CFS throttling — the container is stopped for the rest of each 100 ms period, which reads as latency spikes on an idle-looking node. Memory is limited because memory is not compressible. Cost: a runaway pod can starve neighbours; ResourceQuota is the backstop. |

## Memory profiles (estimates until measured)

| Profile | Adds | Est. total |
|---|---|---|
| `core` | k3d, ingress-nginx, cert-manager, Postgres, catalog, storefront | ~2.6 GB |
| `commerce` | order, inventory, payment, advisor, NATS | ~4.2 GB |
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
  platform-repo/dev/        namespace + quota + limitrange, postgres, catalog, storefront, ingress
  docs/
    architecture.pdf        8 pages, styled, diagrams embedded
    architecture-pdf.html   source of the PDF
    diagrams/generate.py    generates all three SVGs
    diagrams/*.svg          architecture, deployment, delivery-flow
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

## Open items, in order

1. **Run `./scripts/bootstrap.sh` and record real numbers.** Every memory figure in the docs is a
   placeholder. Replace them from `kubectl top pods -A`, in both `docs/architecture.pdf` source and
   `RELEASE-NOTES.md`.
2. **Not yet written:** `docs/architecture.md` (full prose version), `docs/adr/` records,
   `RELEASE-NOTES.md`, `docs/slo.md`, `docs/runbooks/`, the full local-to-cloud document (only the
   Phase 1 extract exists, on page 7 of the PDF).
3. **Phase 2:** `inventory-service` in Go — tank-scoped, TTL-bounded, idempotent reservations.
   Ends with a hold that expires and releases stock on its own.

### Known limitations to state plainly, never soften

- Secrets are plaintext in Git at Phase 1. Largest gap in the repo. Phase 5 replaces it.
- Single-node cluster: PodDisruptionBudgets, anti-affinity and node drains are configured in later
  phases but cannot be exercised.
- The AWS layer has never been applied.
- No performance number is measured yet.

---

## How this session worked, and should keep working

- Accuracy before documents. Clarifying questions first; a wrong assumption compounds across a
  document set.
- One phase at a time, each ending in something demonstrable. Phase 1 ends with a fish in a browser.
- Name the cost of every decision — memory, complexity, operational burden.
- Push back on claims that would not survive an interview follow-up. The honest framing —
  *"designed for AWS, validated locally, run on k3d"* — is the point, not a limitation.
