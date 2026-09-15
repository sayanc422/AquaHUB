package com.aquashop.order.payment;

/**
 * The payment provider did not answer. The money may or may not have been taken.
 *
 * <p>This is not a failure and must never be treated as one. A failure means
 * "no money moved", and acting on that belief while the customer has in fact
 * been charged is the most expensive mistake this system can make. The order
 * goes to {@code PAYMENT_UNRESOLVED} and is resolved later by asking.
 */
public class PaymentUnresolvedException extends RuntimeException {

    private final String idempotencyKey;

    public PaymentUnresolvedException(String idempotencyKey, String message) {
        super(message);
        this.idempotencyKey = idempotencyKey;
    }

    /** The key to ask payment-service about later. */
    public String getIdempotencyKey() {
        return idempotencyKey;
    }
}
