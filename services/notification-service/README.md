# notification-service

Go. Email and webhook fan-out for order events, chosen for the reason
`docs/architecture.md` states: I/O-bound fan-out with per-target retry. Owns
one Postgres database (`notify`) and no other service's data.

## What it does

`order-service` calls `POST /v1/events` once it already knows something
happened — an order reached `CONFIRMED`, or its dispatch window opened
(`ORDER_DISPATCHABLE`, raised by `DispatchWatcher`). This service records one
`outbox` row per target (an email row if the request carried one, a webhook
row if `NOTIFICATION_WEBHOOK_URL` is configured), and a background goroutine
polls for pending rows and delivers them, recording attempts and the last
error until a row is `sent` or exhausts `NOTIFICATION_MAX_ATTEMPTS` and
becomes `failed`.

## Why push, not a NATS subscription

The design intent in `docs/architecture.md` and `docs/adr/0011-*.md` is a
broker subscription, arriving with NATS in Phase 6. NATS doesn't exist yet,
and `full-app` shouldn't have to wait for Phase 6 to be exercised, so v1 uses
a direct HTTP push instead. [ADR 0020](../../docs/adr/0020-push-not-subscribe-until-phase-6.md)
records the decision and its cost in full.

**The cost, stated plainly:** the push from `order-service` is fire-and-forget,
with a short timeout, and it catches and swallows every failure rather than
retrying or failing the caller. If this service is unreachable at the moment
`order-service` calls it, **that notification is lost permanently** — there is
nothing above the HTTP layer to retry the ingest call itself. This is an
accepted cost, not a bug: ADR 0011 already established that a stopped or lossy
notification path is not load-bearing — "the worst it can do is fail to send
an email." Once a row *is* in the outbox, delivery to the target itself does
retry, up to `NOTIFICATION_MAX_ATTEMPTS`.

## Senders are stubs

`docs/architecture.md`'s actor list already states this design: "Email and
webhook targets — external, stubbed locally." There is no SMTP relay
configured anywhere in this repository. `LoggingEmailSender` "delivers" an
email by writing a structured log line. The webhook sender does the same
unless `NOTIFICATION_WEBHOOK_URL` names a real endpoint, in which case it does
a real bounded HTTP POST — useful for testing the retry path against something
that actually answers, but still not a real integration with any external
system.

## Idempotency

A unique constraint on `(order_id, event_type, target_type)`, with
`ON CONFLICT DO NOTHING` on insert. A retried push from `order-service` (its
own client retries on transport errors, separately from the swallow-on-failure
behaviour above) queues nothing twice.

## Configuration

| Variable | Default | |
|---|---|---|
| `PORT` | `8085` | |
| `DATABASE_URL` or `DB_HOST`+`DB_PASSWORD` | — | same convention as inventory-service |
| `NOTIFICATION_WEBHOOK_URL` | unset | when unset, the webhook sender logs instead of calling out |
| `NOTIFICATION_POLL_INTERVAL` | `5s` | |
| `NOTIFICATION_MAX_ATTEMPTS` | `5` | delivery attempts per row before it becomes `failed` |
| `SHUTDOWN_GRACE` | `15s` | |

## API

| Method | Path | |
|---|---|---|
| `POST` | `/v1/events` | `{orderId, orderReference, eventType, email}` — 202 always; `queued` in the body says how many targets were actually new |
| `GET` | `/healthz` | liveness, no database touch |
| `GET` | `/readyz` | readiness, pings the database |
| `GET` | `/metrics` | Prometheus |

Not exposed through the ingress. Only `order-service` calls it.

## Tests

```bash
go test ./...                              # unit only: buildEntries' target-selection logic

createdb notify_test
NOTIFICATION_TEST_DSN=postgres://postgres@127.0.0.1:5432/notify_test?sslmode=disable \
  go test ./...                            # + store integration tests against real Postgres
```

The unit tests cover which targets one event fans out to — pure logic, no
database. The idempotent-insert behaviour that actually matters (the unique
constraint, `ON CONFLICT DO NOTHING`) can only be proven against real
Postgres, the same reasoning inventory-service's own integration suite is
built on: a mock that returns what the test expects proves the test, not the
constraint.

## What this does not do

- No real SMTP or webhook integration — see "Senders are stubs" above.
- No retry of the ingest call itself if `order-service` can't reach this
  service — see "Why push, not a NATS subscription" above.
- No per-customer notification preferences, unsubscribe, or template system.
  One event produces one email and (if configured) one webhook call; nothing
  here composes a customer-facing message beyond the stub log line.
