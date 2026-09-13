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

## Postscript, Phase 3 — the decision was being reversed by the namespace

This record was written in Phase 1 and the deployments have always been correct: no JVM service
declares a CPU limit. The namespace was undoing it anyway.

The `ResourceQuota` counted `limits.cpu`, and a quota that counts a resource makes an explicit limit
for it **mandatory** — a container without one is rejected. The `LimitRange` then supplied a default
of `500m`, so nothing was rejected: every JVM container silently received a CPU limit and was
CFS-throttled, which is precisely the behaviour this record exists to avoid. The symptom would have
been latency spikes on an idle-looking node, with nothing in any deployment manifest to explain them.

Fixed by dropping `limits.cpu` from the quota and the default `cpu` from the `LimitRange`. Memory
remains capped in both, because memory is not compressible.

The decision did not change; its implementation was wrong for two phases, in a file nobody would
think to read when asking "why is this pod being throttled".
