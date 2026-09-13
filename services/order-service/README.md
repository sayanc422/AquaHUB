# order-service

Cart, checkout, and the order state machine. The service that has to be right when something else
goes wrong.

## The saga

Checkout crosses two services and a payment provider, with no distributed transaction available:

```
  1. reserve    one hold per SKU in inventory-service    compensate: release
  2. authorise  take the money                           compensate: refund
  3. commit     turn every hold into a sale              compensate: refund
  4. confirm    fix the dispatch window                  —
```

**The ordering is the design.** Stock is held before the money is taken. A customer charged for a
fish that was never available is a refund, an apology and a support ticket; a customer whose card is
declined after a hold is a released hold and nothing else. The reverse order is simpler to write and
puts the cost of every failure on the customer.

**Every compensation is safe to repeat.** Release is a no-op on a hold that has already gone; refund
is idempotent on the payment reference. A compensation that fails because the work was already undone
leaves the order in exactly the state the compensation existed to prevent.

**One transaction per line, not one for all of them.** The first version reserved every line inside a
single transaction. When the third line was refused, the rollback erased the rows recording the first
two holds — which by then existed in inventory-service — so the compensation found nothing to release
and real stock sat held until its TTL expired. An effect in another service is not covered by your
transaction, so the record of it must be committed the moment it happens. See
`OrderSteps.reserveOneLine`.

## States

```
PENDING ─→ STOCK_RESERVED ─→ PAID ─→ CONFIRMED ─→ SHIPPED
   │             │                       │
   ↓             ↓                       ↓
STOCK_       PAYMENT_                 REFUNDED  ←── PAID, when a hold expired
UNAVAILABLE  FAILED                                before it could be committed
```

There is **no transition from PAID to PAYMENT_FAILED**. Once the money is taken the only way out is a
refund that says so by name; an order sitting in PAYMENT_FAILED with the customer's money in the
account is the worst outcome available.

There is also **no state for "waiting for the dispatch window"** and none for "ready to ship".
Whether a confirmed order may leave the building is `now() >= dispatch_at` — a question about the
clock, not a fact to be stored and kept current by a job. Same rule as inventory-service's hold
expiry; see [ADR 0008](../../docs/adr/0008-availability-is-computed-from-the-deadline.md) and
[ADR 0011](../../docs/adr/0011-derived-state-over-stored-state.md).

## Dispatch windows

A bag of fish posted on a Thursday sits in a depot over the weekend and arrives dead. So livestock
dispatches Monday, Tuesday or Wednesday only, before a 14:00 cut-off in the shop's local time; dry
goods go any weekday. An order placed on Thursday afternoon is confirmed and paid for on Thursday and
cannot ship until Monday — legitimately waiting for something no event will deliver.

`ShippingCalendar` is pure and clock-injected, so "what happens at 13:59 on a Wednesday?" is a test
rather than a conversation.

## Payment

`PaymentGateway` is the port payment-service will plug into. Until then `StubPaymentGateway` stands
in, and its outcome is **configuration** (`PAYMENT_STUB_OUTCOME=APPROVE|DECLINE`), not a field on the
request: a test hook in the API would let anyone who can place an order choose whether to pay.

The stub's limits, stated rather than discovered: no ledger, no idempotency of its own, no network,
and no outcome between "declined" and "authorised". Nothing here demonstrates that the saga survives
a payment provider *timing out*, which is the failure a real one spends most of its design on.

## API

| Method | Path | |
|---|---|---|
| `POST` | `/v1/carts` | new cart |
| `PUT` | `/v1/carts/{id}/lines` | add or replace a line — a retry cannot double a quantity |
| `DELETE` | `/v1/carts/{id}/lines/{sku}` | |
| `POST` | `/v1/orders/from-cart/{cartId}` | run the saga. **Always 201**, even for a declined card: the request succeeded, and the answer is an order in `PAYMENT_FAILED` |
| `GET` | `/v1/orders/{id}`, `/v1/orders/by-reference/{ref}` | `dispatchable` is derived, never stored |
| `GET` | `/v1/orders/{id}/events` | the audit trail — the only place a compensation is visible afterwards |

Not exposed through the ingress. The storefront calls it; it calls inventory-service.

## Tests

```bash
mvn test                                  # 24 tests: state machine, calendar, HTTP client

createdb orders_test
ORDER_TEST_DSN=jdbc:postgresql://127.0.0.1:5432/orders_test ORDER_TEST_USER=postgres \
  mvn test                                # + 8 saga tests against a real Postgres
```

The saga tests need a real database because what they assert is that each step committed its own
transaction and left the order in a state the next step could read. `catalog-service` uses
Testcontainers for the same reason; this service takes a DSN from the environment so the suite also
runs where there is no Docker. **Cost:** the database is not created for you, and the tests skip
silently when the variable is missing rather than failing loudly — which is the trade Testcontainers
exists to avoid.

`aPartlyReservedOrderReleasesTheHoldsItAlreadyTook` is the one that earned its keep: it found the
rollback-erases-the-holds bug described above.

## Configuration

| Variable | Default | |
|---|---|---|
| `DB_URL` `DB_USER` `DB_PASSWORD` | — | |
| `INVENTORY_BASE_URL` | `http://inventory-service:8081` | |
| `INVENTORY_CONNECT_TIMEOUT_MS` / `..._READ_TIMEOUT_MS` | `1000` / `2000` | unbounded calls here exhaust the checkout thread pool |
| `ORDER_HOLD_TTL_SECONDS` | `900` | the customer's time to enter a card |
| `ORDER_DISPATCH_ZONE` | `Asia/Kolkata` | the cut-off is the shop's local time |
| `PAYMENT_STUB_OUTCOME` | `APPROVE` | `DECLINE` demonstrates compensation |

## What this does not do

The saga runs inside one request. If the process dies between step 2 and step 3, the money has been
taken, the holds are still held, and nothing resumes: the holds expire by themselves — so the stock
comes back — but the refund never happens, and only the `order_event` trail would show it. A durable
saga log with a recovery scan is the fix, and it is Phase 6 work, once NATS is there to carry the
retries. The 60-second `terminationGracePeriodSeconds` on the deployment is doing work that a saga
log should be doing.
