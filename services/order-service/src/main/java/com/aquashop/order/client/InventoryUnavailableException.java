package com.aquashop.order.client;

/** Inventory could not answer. Unknown outcome, not a business decision. */
public class InventoryUnavailableException extends RuntimeException {
    public InventoryUnavailableException(String message) { super(message); }
}
