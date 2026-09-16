package com.aquashop.order.notification;

/**
 * A best-effort side channel to notification-service, not a saga step.
 *
 * <p>There is no compensation here and there cannot be one: a lost notification
 * is not a business failure the way a lost payment or a double-sold tank is.
 * ADR 0011 already establishes that the dispatch watcher's job is "not
 * load-bearing... the worst it can do is fail to send an email," and this
 * client exists to make that literally true for the caller — every
 * implementation must swallow its own failures and never throw, so a down or
 * slow notification-service can never affect an order's state.
 *
 * <p>{@code http} (real) or {@code noop} (default) via {@code
 * notification.client}. {@code core} and {@code commerce} never set the
 * property, so they get the no-op and this is a silent no-op for them.
 */
public interface NotificationClient {

    enum Event {
        ORDER_CONFIRMED,
        ORDER_DISPATCHABLE
    }

    /**
     * Tell notification-service something happened. Must never throw and must
     * never block the caller for longer than a short, bounded timeout.
     */
    void notify(Event event, String orderId, String orderReference, String email);
}
