package com.aquashop.order.domain;

import java.util.EnumSet;
import java.util.Set;

/**
 * The order state machine.
 *
 * <p>The legal transitions live here rather than being scattered across the
 * saga, so that "can an order go from PAID to CANCELLED?" has one answer in one
 * place. The database repeats the state list as a CHECK constraint: the enum
 * stops the application writing nonsense, the constraint stops anything else.
 *
 * <p>Deliberately absent: a state for "waiting for the dispatch window" and a
 * state for "ready to ship". Whether a confirmed order may leave the building
 * is {@code now() >= dispatch_at} — a question about the clock, not a fact to
 * be stored and kept up to date by a job. That is the same rule that makes
 * inventory-service's hold expiry safe, applied to a different problem: see
 * ADR 0008 and ADR 0011.
 */
public enum OrderState {

    /** Created; nothing reserved, no money touched. */
    PENDING,

    /** Every line is held in inventory-service. Holds expire on their own. */
    STOCK_RESERVED,

    /**
     * The payment provider did not answer, and the money may or may not have
     * been taken.
     *
     * <p>The state exists because the alternatives are both wrong: calling it a
     * failure releases the stock while the customer's money is gone, and calling
     * it a success confirms an order that may never have been paid for. An
     * order here is resolved later by asking payment-service what happened.
     *
     * <p>The holds are deliberately <em>not</em> released on the way in. They
     * expire on their own within the TTL, which returns the stock without
     * anybody having decided that the payment failed.
     */
    PAYMENT_UNRESOLVED,

    /** Payment authorised. Stock is still only held. */
    PAID,

    /** Holds committed; the stock is ours and {@code dispatch_at} is fixed. */
    CONFIRMED,

    /** Left the building. */
    SHIPPED,

    /** Terminal: a line could not be reserved. No money was taken. */
    STOCK_UNAVAILABLE,

    /** Terminal: authorisation was declined, and every hold has been released. */
    PAYMENT_FAILED,

    /**
     * Terminal: payment succeeded and the stock could not be secured after all
     * — a hold expired between authorisation and commit. The money has been
     * given back. This is the expensive path, and the one worth designing for.
     */
    REFUNDED,

    /** Terminal: cancelled before it shipped. */
    CANCELLED;

    private static final Set<OrderState> TERMINAL =
            EnumSet.of(SHIPPED, STOCK_UNAVAILABLE, PAYMENT_FAILED, REFUNDED, CANCELLED);

    public boolean isTerminal() {
        return TERMINAL.contains(this);
    }

    /** True when money has been taken and not yet given back. */
    public boolean holdsMoney() {
        return this == PAID || this == CONFIRMED || this == SHIPPED;
    }

    public boolean canTransitionTo(OrderState next) {
        return allowedNext().contains(next);
    }

    public Set<OrderState> allowedNext() {
        return switch (this) {
            case PENDING        -> EnumSet.of(STOCK_RESERVED, STOCK_UNAVAILABLE, CANCELLED);
            case STOCK_RESERVED -> EnumSet.of(PAID, PAYMENT_UNRESOLVED, PAYMENT_FAILED, CANCELLED);
            // Only the two answers the provider can eventually give. There is no
            // route from here to CANCELLED: cancelling an order whose payment
            // status is unknown is exactly the guess this state exists to avoid.
            case PAYMENT_UNRESOLVED -> EnumSet.of(PAID, PAYMENT_FAILED);
            // No route from PAID to PAYMENT_FAILED: once the money is taken the
            // only ways out are forward, or a refund that says so by name.
            case PAID           -> EnumSet.of(CONFIRMED, REFUNDED);
            // A confirmed order is cancellable, but the refund is
            // payment-service's to perform, so it goes through REFUNDED too.
            case CONFIRMED      -> EnumSet.of(SHIPPED, REFUNDED);
            case SHIPPED, STOCK_UNAVAILABLE, PAYMENT_FAILED, REFUNDED, CANCELLED
                                -> EnumSet.noneOf(OrderState.class);
        };
    }
}
