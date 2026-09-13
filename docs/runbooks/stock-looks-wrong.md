# Stock looks wrong

**Symptom:** the count in the API does not match the fish in the tank, or a customer reports that
something went out of stock and came back.

## First: is it wrong, or is it held?

The most common answer is that nothing is wrong. A hold subtracts from `available` and does not
touch `onHand`, so a tank with fish in it can legitimately report zero available.

```bash
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://inventory-service:8081/v1/stock/FSH-NEO-01
```

`onHand` is the glass. `available` is what may still be sold. `held` is the difference, and it is
always someone's in-flight checkout.

A `quarantine` tank reports its count with `available: 0`. That is deliberate — the fish exist and
the person reconciling the count is standing in front of them.

## Second: is a hold stuck?

It cannot be, by construction ([ADR 0008](../adr/0008-availability-is-computed-from-the-deadline.md)):
availability ignores any hold past its `expires_at`, whether or not the reaper has run. If
`available` is low and stays low, the holds are live, not stranded.

Confirm against the gauge, then look at the holds themselves:

```bash
# active holds, from the service
kubectl -n aquashop-dev exec deploy/storefront -- \
  wget -qO- http://inventory-service:8081/metrics | grep inventory_active_holds

# the holds, from the database
kubectl -n aquashop-dev exec -it statefulset/postgres -- \
  psql -U inventory -d inventory -c "
    SELECT id, order_ref, sku, quantity, expires_at - now() AS remaining
      FROM reservation
     WHERE state = 'held' AND expires_at > now()
     ORDER BY expires_at"
```

If those rows have real `order_ref`s with time remaining, the system is behaving correctly and the
question is why checkout is slow, not why stock is missing.

## Third: has the reaper stopped?

A stopped reaper cannot cause this, but it is worth knowing about:

```bash
kubectl -n aquashop-dev logs deploy/inventory-service | grep -E 'reaper|expired holds'
```

`reaper pass failed` repeatedly means the database is refusing writes — go to the Postgres pod.
Silence is normal: the reaper only logs when it expires something.

## Fourth: a genuine discrepancy

The glass and the database disagree and no hold explains it. This is a stock count problem, not a
software one — a mis-delivery, a death, a fish moved between tanks without a record.

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- \
  psql -U inventory -d inventory -c "
    UPDATE tank SET quantity_on_hand = <counted>, note = 'recount <date>: <reason>'
     WHERE code = 'T-02'"
```

Write the reason in the note. The next person to read this row will be doing so during an incident.

Two constraints protect you: `quantity_on_hand >= 0` is a CHECK, so a typo that drives stock
negative is refused rather than stored. A recount below what is currently held does **not** cancel
those holds — the holds stay, `available` goes to zero, and the commits that follow will be refused
by the same CHECK. If a recount has invalidated live holds, release them explicitly and let the
customers retry:

```bash
# only the holds against the tank that was recounted
kubectl -n aquashop-dev exec -it statefulset/postgres -- \
  psql -U inventory -d inventory -c "
    UPDATE reservation SET state = 'released', updated_at = now()
     WHERE state = 'held' AND expires_at > now() AND id IN (
       SELECT reservation_id FROM reservation_line l
         JOIN tank t ON t.id = l.tank_id WHERE t.code = 'T-02')"
```

## What not to do

Do not delete `reservation` rows. `reservation_line` cascades, the hold silently stops counting,
and the reason a fish went missing becomes unanswerable. Release them instead — the row stays and
says what happened.
