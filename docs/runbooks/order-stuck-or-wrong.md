# An order is in the wrong state

**Symptom:** a customer says they were charged and the order says it failed, or an order has been
sitting "confirmed" for days and has not shipped, or stock went missing after a checkout.

## First: read the event trail

Every transition is recorded, and it is the only place a compensation is visible — a released hold
leaves no mark on the order itself.

```bash
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://order-service:8082/v1/orders/<id>/events
```

A normal failed checkout looks like this, and needs no action:

```
-               -> PENDING          order created from cart ...
PENDING         -> STOCK_RESERVED   2 hold(s), ttl 900s
STOCK_RESERVED  -> STOCK_RESERVED   released hold ... (payment declined)
STOCK_RESERVED  -> STOCK_RESERVED   released hold ... (payment declined)
STOCK_RESERVED  -> PAYMENT_FAILED   card declined
```

Both holds released, no payment reference on the order: the customer was not charged and the stock is
back. If they insist they were charged, it is an authorisation hold at their bank, not a capture.

## "It says CONFIRMED but it has not shipped"

Confirmed is not shippable. Livestock leaves Monday to Wednesday only, before a 14:00 cut-off in the
shop's time zone, so an order placed on Thursday afternoon waits until Monday — correctly.

```bash
# dispatchAt is the answer; `dispatchable` is derived from it and the clock
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://order-service:8082/v1/orders/<id>
```

If `dispatchable` is `true` and nothing has shipped, the problem is downstream of this service, not
in it. Nothing has to run for an order to become dispatchable, so the dispatch watcher being stopped
cannot be the cause — check it anyway, because its silence means no notification was sent:

```bash
kubectl -n aquashop-dev logs deploy/order-service | grep 'dispatch window open'
```

## "The order says PAYMENT_UNRESOLVED"

The payment provider did not answer, and whether the customer was charged is genuinely unknown. The
order is correct to be in this state; what matters is that it does not stay there.

Nothing needs releasing by hand. The holds were deliberately left alone — releasing them would be a
decision that the payment failed — and they expire on their own within `ORDER_HOLD_TTL_SECONDS`.

```bash
# how many, and for how long
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://order-service:8082/actuator/metrics/orders_payment_unresolved

# what payment-service says about the same payment
kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U orders -d orders -c "
  SELECT reference, state, payment_idempotency_key, updated_at FROM customer_order
   WHERE state = 'PAYMENT_UNRESOLVED'"

kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://payment-service:8083/v1/payments/by-key/<key>
```

The order-service reconciler asks every 30 s and finishes the checkout either way: captured means it
resumes at the commit step (and refunds if the holds have since expired), not-taken means it releases
the holds and marks the order `PAYMENT_FAILED`.

**If the number is not falling**, the reconciler is the thing to check — unlike the dispatch watcher,
this one is load-bearing:

```bash
kubectl -n aquashop-dev logs deploy/order-service | grep -E 'unresolved|resolving'
kubectl -n aquashop-dev exec deploy/storefront -- wget -qO- http://payment-service:8083/metrics \
  | grep -E 'payment_pending|payment_unresolved_total|payment_reconciled_total'
```

`payment_pending` above zero for more than a few minutes means payment-service cannot resolve either
— the acquirer is not answering its lookups. That is an incident with the provider, not with this
system, and the correct action is to leave the orders unresolved and say so. Guessing is what every
rule here exists to prevent.

## "The order says PAYMENT_FAILED but there is a payment reference"

That combination should be impossible: the state machine has no transition from `PAID` to
`PAYMENT_FAILED`, and the database has a CHECK requiring a payment reference on every state at or
past `PAID`. If you are looking at it, something wrote to the database outside the application.
Do not fix the row. Capture it, and find out what wrote it.

## "The order is REFUNDED"

The expensive path, and it worked: the money was taken, a hold had expired before it could be
committed, and the refund was issued. The event trail will say `refunded: reservation ... could not
be committed`. The customer should be told, because nothing notifies them yet.

Worth checking whether it is happening often — a rising `REFUNDED` count means the hold TTL is too
short for how long customers take to pay:

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U orders -d orders -c "
  SELECT state, count(*) FROM customer_order
   WHERE created_at > now() - interval '7 days' GROUP BY state ORDER BY 2 DESC"
```

## "Stock is missing and a checkout is the suspect"

Cross the two services by reservation id. order-service records every hold it took:

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U orders -d orders -c "
  SELECT o.reference, o.state, r.sku, r.reservation_id, r.state
    FROM customer_order o JOIN order_reservation r ON r.order_id = o.id
   WHERE o.id = '<id>'"

kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U inventory -d inventory -c "
  SELECT id, sku, quantity, state, expires_at FROM reservation WHERE id = '<reservation_id>'"
```

A hold that is `HELD` in order-service and absent in inventory-service means the order remembers a
hold that was never created. A hold that is `held` in inventory-service and absent in order-service
is the reverse, and is the failure mode
[ADR 0013](../adr/0013-record-external-effects-outside-the-transaction.md) is about: the stock
returns on its own when the hold expires, within `ORDER_HOLD_TTL_SECONDS` (default 900).

Do not release it by hand unless it is outside that window. If it is, the runbook for the stock side
is [stock-looks-wrong.md](stock-looks-wrong.md).

## "An order stopped half way through"

The system now handles this itself. `SagaRecovery` scans every minute for orders that have sat in
`PAID` or `STOCK_RESERVED` longer than `ORDER_STUCK_AFTER_MS` (default two minutes) and finishes
them — committing the holds, or refunding if the holds expired while the order was stuck, or asking
payment-service when the charge is unknown.

```bash
kubectl -n aquashop-dev logs deploy/order-service | grep SagaRecovery
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://order-service:8082/actuator/metrics/orders_stuck
```

`orders_stuck` is the gauge that has to come back to zero. If it is climbing, the recovery is
running and failing — read the logs — rather than not running.

The manual query below still works, and is worth knowing for the case where the recovery itself is
the thing that is broken:

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U orders -d orders -c "
  SELECT reference, state, payment_ref, updated_at FROM customer_order
   WHERE state = 'PAID' AND updated_at < now() - interval '10 minutes'"
```

Any row here is an order that took money and never confirmed. Each one needs a refund issued by hand
and the reason recorded.
