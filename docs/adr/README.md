# Architecture decision records

One record per decision that would be expensive to reverse or that an interviewer would
reasonably challenge. Each states the decision, the reason, and **what it costs** — a record
without a cost section is advocacy, not a decision record.

Records are immutable once accepted. A changed mind is a new record that supersedes an old one,
because the reasoning that was true at the time is the useful part.

| # | Decision | Status |
|---|---|---|
| [0001](0001-validate-terraform-with-mocks-not-localstack.md) | Validate the AWS layer with `terraform test` and mock providers, not LocalStack | Accepted |
| [0002](0002-three-environments-one-materialised.md) | Three overlays, only one materialised at a time | Accepted |
| [0003](0003-one-postgres-database-per-service.md) | One Postgres instance, one database and login role per service | Accepted |
| [0004](0004-nats-jetstream-not-kafka.md) | NATS JetStream, not Kafka | Accepted |
| [0005](0005-server-rendered-bff-not-an-spa.md) | A server-rendered BFF, not a React SPA | Accepted |
| [0006](0006-memory-limits-but-no-cpu-limits.md) | Memory limits always, CPU requests only | Accepted |
| [0007](0007-two-repositories.md) | Two repositories: application code and desired state | Accepted |
| [0008](0008-availability-is-computed-from-the-deadline.md) | Availability is computed from the hold deadline, not from a reaper | Accepted |
| [0009](0009-mandatory-idempotency-key.md) | `Idempotency-Key` is mandatory on reservations and bound to a request digest | Accepted |
| [0010](0010-lock-then-read-in-two-statements.md) | Lock tank rows and read availability in two statements | Accepted |
| [0011](0011-derived-state-over-stored-state.md) | Derived state over stored state, wherever a clock can answer | Accepted |
| [0012](0012-hold-stock-before-taking-money.md) | Hold stock before taking money | Accepted |
| [0013](0013-record-external-effects-outside-the-transaction.md) | An effect in another service must be recorded outside the transaction that may roll back | Accepted |
| [0014](0014-unknown-is-not-failure.md) | An unknown payment outcome is a state, not a failure | Accepted |
| [0015](0015-write-the-intent-before-the-call.md) | Write the intent before the external call, not after | Accepted |
| [0016](0016-rules-are-data-not-code.md) | Stocking rules are data, owned by the person who keeps fish | Accepted |
| [0017](0017-advisor-owns-no-data.md) | The advisor owns rules and no data | Accepted |
| [0018](0018-recover-from-state-not-from-an-outbox.md) | Recover the saga from its own state, not from an outbox — amends 0015 | Accepted |
| [0019](0019-the-catalogue-says-what-kind-of-animal-it-is.md) | The catalogue says what kind of animal it is — extends 0017 | Accepted |
| [0020](0020-push-not-subscribe-until-phase-6.md) | notification-service is pushed to, not subscribed via NATS, until Phase 6 | Accepted |
