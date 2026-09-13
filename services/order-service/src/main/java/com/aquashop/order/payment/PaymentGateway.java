package com.aquashop.order.payment;

/**
 * The port payment-service will plug into.
 *
 * <p>Two operations, because the saga needs exactly two: take the money, and
 * give it back. Authorisation and capture are deliberately one call here —
 * splitting them is a real design choice for a shop that ships days after it
 * charges, and it belongs with the service that owns the ledger, not with a
 * stub in the order service.
 */
public interface PaymentGateway {

    /**
     * @return a reference for the payment, to be stored on the order
     * @throws PaymentDeclinedException when the money was not taken — a
     *         business outcome, and the branch the saga compensates
     */
    String authorise(String orderReference, long amountMinor, String currency, String email);

    /**
     * Give the money back. Must be safe to call twice: the saga can be retried,
     * and a refund that fails because it already happened would leave an order
     * stuck in a state that says the customer is owed money.
     */
    void refund(String paymentRef, long amountMinor, String reason);
}
