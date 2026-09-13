package com.aquashop.order.client;

/** The stock is not there. A business outcome: the order ends, nobody is paged. */
public class InsufficientStockException extends RuntimeException {
    private final String sku;

    public InsufficientStockException(String sku, String code) {
        super("inventory refused sku " + sku + ": " + code);
        this.sku = sku;
    }

    public String getSku() { return sku; }
}
