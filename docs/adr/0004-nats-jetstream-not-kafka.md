# 4. NATS JetStream, not Kafka

**Status:** Accepted · **Phase:** 3

## Context

Domain events need a broker: order state changes, stock movements, notification fan-out.

## Decision

NATS JetStream. No consumer in this system needs log replay from an arbitrary offset or
partition-key ordering, and Kafka plus a controller costs roughly 1 GB the memory budget does not
have.

## Consequences

Durable streams, at-least-once delivery and consumer acknowledgement — enough for every consumer
here — in about a tenth of the footprint.

**Cost:** partition-key ordering semantics are unavailable, the tooling ecosystem is smaller, and
migrating to MSK is a heavier lift than a one-line row in the local-to-cloud table makes it look:
consumer groups, offset semantics and retention are not a rename.
