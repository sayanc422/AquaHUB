# AquaShop

A polyglot Kubernetes platform for a freshwater aquarium shop.

**Designed for AWS. Validated with `terraform test` and mock providers. Run on k3d. Never applied.**

The AWS infrastructure layer in this repository has never been applied to an AWS account. The
runtime is a single-node k3d cluster inside WSL2. Diagrams carry AWS labels because AWS is the
target platform; every divergence is recorded in [docs/architecture.md](docs/architecture.md).

## Quick start

```bash
./scripts/bootstrap.sh                      # core:     k3d + ingress + TLS + catalog + storefront
./scripts/bootstrap.sh --profile commerce   # core + inventory-service
./scripts/bootstrap.sh --destroy
```

Profiles exist because ~11 GB does not hold the whole platform at once. They are not a workaround
added at the end — they are why NATS replaced Kafka, why one Postgres instance hosts a database per
service, and why only one environment is ever materialised.

Then open <https://aquashop.localtest.me/>. The certificate is self-signed; the browser warning is
expected. `localtest.me` resolves to 127.0.0.1, so no `/etc/hosts` edit is needed.

Requirements: Docker Engine in WSL2 (not Docker Desktop), `k3d`, `kubectl`, `helm`, and more than
4 GB of free memory. The script checks the last one and refuses to run rather than letting the OOM
killer make the decision.

## Status

**Phase 1 complete, and now actually run.** `catalog-service` (Java 21 / Spring Boot) and
`storefront` (TypeScript / Fastify) build, boot against Postgres and serve rendered pages. Running
them for the first time found two mapping defects that would have crash-looped the catalog on its
first boot — see [RELEASE-NOTES.md](RELEASE-NOTES.md). They have still never run *in* k3d.

**Phases 2, 3 and 4 complete in code, not in the cluster.** `inventory-service` (Go) holds stock in
physical tanks with TTL-bounded, idempotent reservations, and a concurrency test proves it cannot
oversell. `order-service` (Java) runs checkout as a saga across it — reserve, authorise, commit,
confirm — and compensates when a step fails. `payment-service` (Rust) owns an append-only ledger and
the case that matters: an acquirer that takes the money and does not answer.

All three have been run together against a real Postgres. A live checkout that confirms with a
dispatch window; a live declined card that returns every held fish to the shop immediately and takes
no money; and a live checkout against a payment provider that never answers, which ends `CONFIRMED`
with the money accounted for and nobody having touched it. None has run *in* k3d — no session so far
has had Docker, which is why that is still the first open item.

Phases 5–7 are planned. See [docs/context_summary.md](docs/context_summary.md) for current state and
[RELEASE-NOTES.md](RELEASE-NOTES.md) for what has actually been measured.

## Layout

| Path | Contents |
|---|---|
| `services/` | Application code, one directory per service. Each has its own README |
| `platform-repo/dev/` | The dev overlay: namespace, quota, Postgres, and one directory per service |
| `platform-repo/` | Cluster desired state. Moves to its own repository at Phase 4 |
| `scripts/` | k3d cluster config and the bootstrap script |
| `docs/` | Architecture, decision records, SLOs, runbooks, diagrams, context summary |

## Documentation

- [docs/architecture.md](docs/architecture.md) — architecture, decisions, costs, local-to-cloud mapping, known limitations
- [docs/adr/](docs/adr/) — one record per decision that would be expensive to reverse, each with its cost
- [docs/slo.md](docs/slo.md) — objectives, the consequence of missing each, and which numbers are measured
- [docs/runbooks/](docs/runbooks/) — one page per failure, written to be followed at 02:00
- [RELEASE-NOTES.md](RELEASE-NOTES.md) — per phase: what was built, what was measured, what is unproven
- [docs/context_summary.md](docs/context_summary.md) — current state, decisions taken, open items
- [docs/architecture.pdf](docs/architecture.pdf) — styled and printable, with diagrams. **Phase 1 content only**; `architecture.md` is ahead of it
- [docs/diagrams/](docs/diagrams/) — SVG diagrams and the script that generates them
