# AquaShop

A polyglot Kubernetes platform for a freshwater aquarium shop.

**Designed for AWS. Validated with `terraform test` and mock providers. Run on k3d. Never applied.**

The AWS infrastructure layer in this repository has never been applied to an AWS account. The
runtime is a single-node k3d cluster inside WSL2. Diagrams carry AWS labels because AWS is the
target platform; every divergence is recorded in [docs/architecture.md](docs/architecture.md).

## Quick start

```bash
./scripts/bootstrap.sh          # k3d + ingress-nginx + cert-manager + Phase 1 services
./scripts/bootstrap.sh --destroy
```

Then open <https://aquashop.localtest.me/>. The certificate is self-signed; the browser warning is
expected. `localtest.me` resolves to 127.0.0.1, so no `/etc/hosts` edit is needed.

Requirements: Docker Engine in WSL2 (not Docker Desktop), `k3d`, `kubectl`, `helm`, and more than
4 GB of free memory. The script checks the last one and refuses to run rather than letting the OOM
killer make the decision.

## Status

Phase 1 complete: `catalog-service` (Java 21 / Spring Boot) and `storefront` (TypeScript / Fastify)
run in the local cluster with Postgres, ingress and TLS. Phases 2–7 are planned — see
[docs/context_summary.md](docs/context_summary.md).

## Layout

| Path | Contents |
|---|---|
| `services/` | Application code, one directory per service |
| `platform-repo/` | Cluster desired state. Moves to its own repository at Phase 4 |
| `scripts/` | k3d cluster config and the bootstrap script |
| `docs/` | Architecture (markdown and PDF), diagrams, context summary |

## Documentation

- [docs/architecture.md](docs/architecture.md) — architecture, decisions, costs, local-to-cloud mapping, known limitations
- [docs/architecture.pdf](docs/architecture.pdf) — the same, styled and printable, with diagrams
- [docs/context_summary.md](docs/context_summary.md) — current state, decisions taken, open items
- [docs/diagrams/](docs/diagrams/) — SVG diagrams and the script that generates them
