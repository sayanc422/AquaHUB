# payment-service

Authorisation, capture, refund, and the ledger behind them.

The smallest surface in the platform and the strictest correctness requirement, which is why it is
in Rust.

## The failure it is built around

Not a decline. **An acquirer that takes the money and does not answer.**

A decline is easy: no money moved, tell the customer, release the stock. The hard case is a request
that times out, because the two obvious responses are both wrong — calling it a failure releases the
stock while the customer's money is gone, and calling it a success promises an order that may never
have been paid for.

Everything here exists for that case:

| | |
|---|---|
| **The intent is written before the acquirer is called** | A service that charges first and records afterwards loses the record of every charge it dies in the middle of. The `pending` row is what makes an unanswered charge findable at all. |
| **`pending` is never counted as money taken** | A CHECK constraint enforces `state <> 'pending' OR balance_minor = 0`. Every report, every API response, every downstream decision reads it the same way. |
| **`GET /v1/payments/by-key/{key}`** | The endpoint that makes a timeout survivable. Without it, an unanswered authorisation is permanently unknown and every timeout becomes a manual investigation. |
| **A reconciler** | Asks again about pending payments on a timer, so an outcome arrives even if nobody calls back. |

## Why Rust

Two properties, both load-bearing:

**Exhaustive matching.** Every ledger transition is a `match` with no catch-all arm. Adding a state
or an event stops the build until a person has said what it means in every case. A payment system's
worst failure is a case nobody thought about being swallowed by a default branch.

**Checked arithmetic.** Every operation on money returns a `Result`. In release builds Rust wraps on
overflow silently, and a wrapped balance is a refund of nine quintillion rupees. Amounts are integer
minor units, never floats — a float cannot hold 0.1, and a ledger out by a rounding error is a
ledger nobody can reconcile. A direction is an entry's *kind*, never the sign of its amount.

**Cost:** the slowest build in this repository by a wide margin, and the smallest maintainer pool of
the five services.

## States

```
                  ┌─ captured ─→ partially_refunded ─→ refunded
pending ─────────┤
 (no money taken) ├─ declined
                  └─ failed          (the acquirer confirmed no charge exists)
```

`pending` is the only unresolved state, and the only one where the truth is unknown rather than
merely unfortunate.

## The ledger

Append-only, and enforced — a trigger refuses `UPDATE` and `DELETE` on `ledger_entry` rather than
trusting everyone to remember. A refund is a new entry, never an edit of the capture it reverses.
The balance is a fold over the entries, and history that can be rewritten is not history.

```
seq 1  authorise  amount 72000   balance 0       intent for order AQ-1C35BB05F3
seq 2  capture    amount 72000   balance 72000   resolved: the acquirer had taken the money
seq 3  refund     amount 5000    balance 67000   one fish arrived DOA
```

## API

| | | |
|---|---|---|
| `POST` | `/v1/payments` | Requires `Idempotency-Key`. **201** taken · **200** replay, not a second charge · **402** declined · **409** key reused for a different request · **504** unknown |
| `GET` | `/v1/payments/by-key/{key}` | Resolve an unknown outcome. 504 means *still* unknown — which is an answer, not an error |
| `POST` | `/v1/payments/{id}/refund` | Requires `Idempotency-Key`, or a retry pays out twice. Over-refund is 409 |
| `GET` | `/v1/payments/{id}` · `/ledger` | `holdsMoney` is what a caller should read; `pending` looks like progress and means "we do not know" |
| `GET` | `/healthz` `/readyz` `/metrics` | Liveness does not touch Postgres; readiness does |

Not exposed through the ingress. `order-service` calls it; customers never do.

## The acquirer is a stub

The service is real; the card network behind it is not. `Behaviour::Hang` is the honest part: it
records the authorisation after the delay **whether or not the caller is still waiting**, because
the charge happened at the acquirer and the caller giving up changes nothing about that.

What it does not model: partial captures, chargebacks, 3-D Secure, settlement files, or an acquirer
that answers inconsistently. And its memory is in-process, so a restart makes previously recorded
charges look like `NoSuchCharge` — which is exactly the situation the void window below guards
against, and is worth knowing when reading a demo.

## The bug this service was already written to prevent, and still had

The first version of `resolve_pending` treated "the acquirer has no charge for this reference" as
proof that no charge would ever be made, and voided the payment.

Demonstrated against this service: acquirer delay 6 s, client timeout 1.5 s. The authorisation timed
out, a resolve one second later found no charge, and the payment was written off as `failed`. Five
seconds later the money was taken. **The customer was charged and the ledger said the payment never
happened** — the one outcome every other rule here exists to prevent.

An authorisation that has not appeared is not an authorisation that will not appear. A `NoSuchCharge`
may now only void a payment older than `ACQUIRER_VOID_AFTER_SECONDS`, which must exceed the longest
an authorisation can be in flight. The properly authoritative fix is an explicit cancel call to the
acquirer, which makes "no charge" a fact rather than an observation; the age window is what is
available here, and it is a weaker guarantee that deserves to be named as one.

## Configuration

| Variable | Default | |
|---|---|---|
| `DATABASE_URL` | — | |
| `PORT` | `8083` | |
| `ACQUIRER_BEHAVIOUR` | `approve` | `approve` · `decline` · `hang` |
| `ACQUIRER_DELAY_MS` | `5000` | how long `hang` waits before recording the charge |
| `ACQUIRER_TIMEOUT_MS` | `2000` | give up and leave the payment pending |
| `ACQUIRER_VOID_AFTER_SECONDS` | `60` | below this age, "no charge" means "not yet" |
| `RECONCILE_INTERVAL_MS` | `15000` | |
| `RECONCILE_AFTER_SECONDS` | `20` | how old a pending payment must be before asking again |

## Tests

```bash
cargo test    # 24 tests: money, the ledger machine, the acquirer's timeout behaviour
```

All of them are pure or in-process; there is no database in the test suite. What that leaves
untested is the SQL — the CHECK constraints, the append-only trigger, and the conditional update
that stops two resolvers writing twice. Those were exercised by hand against a real Postgres and
should have a gated integration suite like `order-service`'s. That is the honest gap here.
