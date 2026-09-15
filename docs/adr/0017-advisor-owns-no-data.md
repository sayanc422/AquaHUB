# 17. The advisor owns rules and no data

**Status:** Accepted · **Phase:** 5

## Context

`aquatics-advisor` needs every inhabitant's temperature range, pH range, hardness range, adult size,
minimum group size, temperament and diet. All of it already exists in `catalog-service`, which owns
species care profiles.

The convenient thing is to copy it: a local table, populated from the catalog, queried directly. It
removes a network call from every request and a dependency from the readiness check.

## Decision

No database. The advisor reads species profiles from `catalog-service` over HTTP and caches them for
five minutes.

A copy would be a second source of truth. The first time somebody corrects a pH range in the catalog
and the advisor keeps advising from the old one, the shop is giving advice that contradicts its own
product page — and nothing in either service would report a problem.

The JSON is converted to the advisor's own `Species` type once, at the boundary, so a field rename
upstream lands in one adapter rather than in a dozen rules.

## Consequences

One source of truth for what a species needs, which is the data-ownership rule of the platform
applied to the service where copying would have been easiest to justify.

The advisor is also the simplest deployment here: no volume, no credentials, no migrations, no
`DATABASE_URL` in its ConfigMap.

**Cost: it cannot answer anything when the catalog is down.** Readiness fails and the pod leaves the
Service endpoints; liveness deliberately does not check, or a catalog outage would restart every
healthy advisor pod in a loop. The cache softens a slow catalog, not an absent one.

**Cost: a cache is bounded staleness by another name.** A corrected care profile takes up to five
minutes to reach the advice. That is a deliberate trade for not making the advisor's latency the
catalog's, and the number is configuration rather than a constant.

**Cost: an extra hop.** The catalog is addressed by slug and the rest of the platform speaks SKU, so
resolving a SKU costs a product-list call. A SKU-addressed endpoint on `catalog-service` would remove
it — which is a conversation with that service rather than a workaround here, and it has not been
had.
