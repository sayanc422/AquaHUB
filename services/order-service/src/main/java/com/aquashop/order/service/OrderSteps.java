package com.aquashop.order.service;

import com.aquashop.order.client.InventoryClient;
import com.aquashop.order.domain.*;
import com.aquashop.order.repo.OrderEventRepository;
import com.aquashop.order.repo.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.ZonedDateTime;
import java.util.UUID;

/**
 * The individual saga steps, each in its own transaction.
 *
 * <p>These live in a separate bean, not as private methods of {@link
 * CheckoutSaga}, and that is not a matter of taste. Spring implements
 * {@code @Transactional} with a proxy, so a call from one method of a class to
 * another method of the same class never passes through it: the annotation is
 * ignored and the work runs with no transaction at all, silently. Everything
 * appears to function until two steps need to roll back together.
 *
 * <p>Each method here is one unit of work that either happens completely or not
 * at all. None of them spans a call to another service — that is the saga's job,
 * and a transaction held open across the network is the thing sagas exist to
 * avoid.
 */
@Service
public class OrderSteps {

    private static final Logger log = LoggerFactory.getLogger(OrderSteps.class);

    private final OrderRepository orders;
    private final OrderEventRepository events;
    private final InventoryClient inventory;
    private final ShippingCalendar calendar;
    private final Clock clock;

    public OrderSteps(OrderRepository orders, OrderEventRepository events,
                      InventoryClient inventory, ShippingCalendar calendar, Clock clock) {
        this.orders = orders;
        this.events = events;
        this.inventory = inventory;
        this.calendar = calendar;
        this.clock = clock;
    }

    @Transactional
    public CustomerOrder createOrder(Cart cart, String email, String currency) {
        UUID id = UUID.randomUUID();
        CustomerOrder order = new CustomerOrder(id, reference(id), email, currency);
        for (CartLine line : cart.getLines()) {
            order.addLine(new OrderLine(line.getSku(), line.getName(), line.getQuantity(),
                    line.getUnitPriceMinor(), line.isLivestock()));
        }
        orders.saveAndFlush(order);
        events.save(new OrderEvent(id, null, OrderState.PENDING, "order created from cart " + cart.getId()));
        return order;
    }

    /**
     * Hold one line, and write the hold down in the same breath.
     *
     * <p>{@code REQUIRES_NEW}, one line at a time, and this is not a style
     * choice. The first version reserved every line inside a single
     * transaction, and {@code aPartlyReservedOrderReleasesTheHoldsItAlreadyTook}
     * failed against it: when the third line was refused, the transaction rolled
     * back — and rolled back the rows recording the first two holds, which by
     * then <em>existed in inventory-service</em>. The compensation then found no
     * reservations to release, and real stock sat held until its TTL expired.
     *
     * <p>The rule the failure teaches: an effect in another service is not
     * covered by your transaction, so the record of it must be committed as
     * soon as it happens, never inside a transaction that might still roll
     * back. A saga's memory of what it has done is the only thing its
     * compensation has to work from.
     *
     * <p>A window remains, and it is narrower rather than gone: if this process
     * dies between inventory-service committing the hold and this transaction
     * committing the row, the hold is orphaned. It expires by itself within the
     * TTL, and a retry presents the same idempotency key and is handed the same
     * reservation back — which is precisely why that key is derived from the
     * order and the SKU rather than generated per attempt.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public UUID reserveOneLine(UUID orderId, String sku, int quantity, int ttlSeconds) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        String key = "order-" + orderId + "-" + sku;
        InventoryClient.Reservation reservation =
                inventory.reserve(key, order.getReference(), sku, quantity, ttlSeconds);
        order.addReservation(new OrderReservation(sku, reservation.id(), quantity));
        orders.saveAndFlush(order);
        return reservation.id();
    }

    @Transactional
    public void commitEveryReservation(UUID orderId) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        for (OrderReservation reservation : order.getReservations()) {
            if (reservation.getState() != OrderReservation.State.HELD) {
                continue;
            }
            inventory.commit(reservation.getReservationId());
            reservation.markCommitted();
        }
        orders.saveAndFlush(order);
    }

    /**
     * Release every hold this order still has.
     *
     * <p>{@code REQUIRES_NEW} and a swallowed failure, both deliberate. A
     * compensation runs when something has already gone wrong, so it must not
     * be enrolled in a transaction that is about to roll back, and it must not
     * replace the original failure with one of its own. A hold that cannot be
     * released expires by itself within the TTL — the customer gets the right
     * outcome either way — and the event trail records that the attempt was
     * made, because that is the only place a compensation is visible afterwards.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void releaseAll(UUID orderId, String reason) {
        CustomerOrder order = orders.findById(orderId).orElse(null);
        if (order == null) {
            return;
        }
        for (OrderReservation reservation : order.getReservations()) {
            if (reservation.getState() != OrderReservation.State.HELD) {
                continue;
            }
            try {
                inventory.release(reservation.getReservationId());
                reservation.markReleased();
                events.save(new OrderEvent(orderId, order.getState(), order.getState(),
                        "released hold " + reservation.getReservationId() + " (" + reason + ")"));
            } catch (RuntimeException e) {
                log.error("could not release hold {} for order {}: {}",
                        reservation.getReservationId(), orderId, e.getMessage());
                events.save(new OrderEvent(orderId, order.getState(), order.getState(),
                        "release FAILED for hold " + reservation.getReservationId()
                                + "; it expires on its own"));
            }
        }
        orders.save(order);
    }

    @Transactional
    public void recordPayment(UUID orderId, String paymentRef, String paymentKey) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        order.setPaymentRef(paymentRef);
        if (paymentKey != null) {
            order.setPaymentIdempotencyKey(paymentKey);
        }
        OrderState from = order.transitionTo(OrderState.PAID);
        orders.save(order);
        events.save(new OrderEvent(orderId, from, OrderState.PAID, "payment " + paymentRef));
    }

    /**
     * Record that the payment's outcome is unknown.
     *
     * <p>No holds are released here, deliberately. Releasing them would be a
     * decision that the payment failed, and that is precisely what is not
     * known. They expire on their own, which returns the stock without anyone
     * having decided anything.
     */
    @Transactional
    public void markUnresolved(UUID orderId, String paymentKey, String detail) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        order.setPaymentIdempotencyKey(paymentKey);
        OrderState from = order.transitionTo(OrderState.PAYMENT_UNRESOLVED);
        order.setFailureReason(truncate(detail));
        orders.save(order);
        events.save(new OrderEvent(orderId, from, OrderState.PAYMENT_UNRESOLVED, truncate(detail)));
    }

    /**
     * The payment was resolved as never taken. Now -- and only now -- the holds
     * can go back, because "no money moved" has become a fact rather than a
     * guess.
     */
    @Transactional
    public void failUnresolved(UUID orderId, String reason) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        OrderState from = order.transitionTo(OrderState.PAYMENT_FAILED);
        order.setFailureReason(truncate(reason));
        orders.save(order);
        events.save(new OrderEvent(orderId, from, OrderState.PAYMENT_FAILED, truncate(reason)));
    }

    @Transactional
    public void confirm(UUID orderId) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        ZonedDateTime dispatch = calendar.nextDispatch(
                ZonedDateTime.now(clock.withZone(calendar.zone())), order.hasLivestock());
        order.setDispatchAt(dispatch.toInstant());
        OrderState from = order.transitionTo(OrderState.CONFIRMED);
        orders.save(order);
        events.save(new OrderEvent(orderId, from, OrderState.CONFIRMED,
                (order.hasLivestock() ? "livestock" : "dry goods") + " dispatch window " + dispatch));
        log.info("order confirmed order={} dispatchAt={}", order.getReference(), dispatch);
    }

    @Transactional
    public void advance(UUID orderId, OrderState next, String detail) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        OrderState from = order.transitionTo(next);
        orders.save(order);
        events.save(new OrderEvent(orderId, from, next, detail));
    }

    @Transactional
    public void fail(UUID orderId, OrderState next, String reason) {
        CustomerOrder order = orders.findById(orderId).orElseThrow();
        OrderState from = order.transitionTo(next);
        order.setFailureReason(truncate(reason));
        orders.save(order);
        events.save(new OrderEvent(orderId, from, next, truncate(reason)));
        log.info("order ended order={} state={} reason={}", order.getReference(), next, reason);
    }

    /** Loads an order with its collections inside a transaction, ready to render. */
    @Transactional(readOnly = true)
    public CustomerOrder load(UUID orderId) {
        CustomerOrder order = orders.findWithLines(orderId).orElseThrow();
        order.getReservations().size();
        return order;
    }

    /**
     * A human-facing reference. Customers read it out over the phone, so it is
     * not the UUID.
     */
    static String reference(UUID id) {
        return "AQ-" + id.toString().replace("-", "").substring(0, 10).toUpperCase();
    }

    static String truncate(String s) {
        return s == null ? null : (s.length() <= 200 ? s : s.substring(0, 197) + "...");
    }
}
