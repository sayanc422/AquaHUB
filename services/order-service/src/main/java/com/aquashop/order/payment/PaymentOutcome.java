package com.aquashop.order.payment;

/**
 * What payment-service says about a payment that was left unresolved.
 *
 * <p>Three answers, and the third is not a failure mode of the query — it is a
 * legitimate, expected answer that means "ask again later".
 */
public sealed interface PaymentOutcome {

    /** The money was taken. */
    record Captured(String paymentRef) implements PaymentOutcome { }

    /** No money was taken, and none will be. */
    record NotTaken(String reason) implements PaymentOutcome { }

    /** Still unknown. Asking again later is the only correct response. */
    record StillUnresolved() implements PaymentOutcome { }
}
