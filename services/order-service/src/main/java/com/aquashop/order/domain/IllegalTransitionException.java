package com.aquashop.order.domain;

/** Thrown when something asks an order to make a transition the machine forbids. */
public class IllegalTransitionException extends RuntimeException {
    public IllegalTransitionException(OrderState from, OrderState to) {
        super("an order cannot go from " + from + " to " + to);
    }
}
