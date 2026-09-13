# 5. A server-rendered BFF, not a React SPA

**Status:** Accepted · **Phase:** 1

## Context

The storefront is the customer-facing entry point. The interesting property of a BFF is
aggregation across services, bounded timeouts and trace propagation.

## Decision

A Fastify BFF rendering HTML on the server. No client-side framework.

## Consequences

Every interesting property is exercised in code a reviewer can read in one file. The 2 s upstream
timeout, the 60 s category cache and the liveness/readiness split are all visible in
`services/storefront/src`.

**Cost:** no client-side interactivity beyond forms, and no demonstration of a front-end build
pipeline. That is the intended trade: a build toolchain and a client state layer would prove
neither aggregation nor timeout behaviour.
