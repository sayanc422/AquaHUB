# 2. Three overlays, only one materialised at a time

**Status:** Accepted · **Phase:** 1 (Argo CD arrives at Phase 4)

## Context

A credible delivery story needs dev, uat and prod under GitOps. Roughly 11 GB of usable memory
cannot hold two full environments at once.

## Decision

Three overlays — dev, uat, prod — all described in the GitOps repository and all managed by Argo
CD. Only one is materialised at a time; the others sit at `replicas: 0`.

## Consequences

Promotion is a pull request, the overlay diff is real, and the environment structure is honest
about what it is.

**Cost:** no environment has ever run concurrently with another. Cross-environment behaviour —
a uat load test while dev serves traffic, a promotion observed in both at once — has never
happened here. Never say "I ran prod". Say "three overlays under GitOps, one materialised at a
time".
