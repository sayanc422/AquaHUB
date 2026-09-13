# 6. Memory limits always, CPU requests only

**Status:** Accepted · **Phase:** 1

## Context

Every pod on a single node shares four cores and a fixed memory ceiling.

## Decision

Set memory requests and limits on every container. Set CPU requests, but no CPU limits.

A CPU limit is enforced by CFS throttling: once a container exhausts its quota it is stopped for
the remainder of each 100 ms period. On a JVM service that reads as latency spikes while the node
looks idle — one of the hardest symptoms to diagnose from a dashboard, because the node graph shows
spare CPU the whole time. Memory is different: it is not compressible, there is no throttling
equivalent, and the only enforcement is the OOM killer. So memory is always capped.

## Consequences

Latency stays predictable under burst, and no pod can take the node down by allocating.

**Cost:** a runaway pod can starve its neighbours of CPU. The namespace `ResourceQuota` is the
backstop, and it is a ceiling for the namespace, not fairness between pods.
