package com.aquashop.order.payment;

/** The money was not taken. Expected, not exceptional. */
public class PaymentDeclinedException extends RuntimeException {
    public PaymentDeclinedException(String reason) { super(reason); }
}
