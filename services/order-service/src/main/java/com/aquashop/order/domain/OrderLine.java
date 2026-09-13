package com.aquashop.order.domain;

import jakarta.persistence.*;

/**
 * A line of an order. The price is the one quoted when the item went into the
 * cart, not the catalog's price at checkout: a price that moves between
 * "add to basket" and "pay" is a support ticket.
 */
@Entity
@Table(name = "order_line")
@IdClass(OrderLine.Key.class)
public class OrderLine {

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id")
    private CustomerOrder order;

    @Id
    @Column(length = 32)
    private String sku;

    @Column(nullable = false, length = 160)
    private String name;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "unit_price_minor", nullable = false)
    private long unitPriceMinor;

    @Column(name = "is_livestock", nullable = false)
    private boolean livestock;

    protected OrderLine() { }

    public OrderLine(String sku, String name, int quantity, long unitPriceMinor, boolean livestock) {
        this.sku = sku;
        this.name = name;
        this.quantity = quantity;
        this.unitPriceMinor = unitPriceMinor;
        this.livestock = livestock;
    }

    void setOrder(CustomerOrder order) { this.order = order; }

    public String getSku() { return sku; }
    public String getName() { return name; }
    public int getQuantity() { return quantity; }
    public long getUnitPriceMinor() { return unitPriceMinor; }
    public boolean isLivestock() { return livestock; }

    /** Composite key: an order holds at most one line per SKU. */
    public static class Key implements java.io.Serializable {
        private java.util.UUID order;
        private String sku;
        public Key() { }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key k)) return false;
            return java.util.Objects.equals(order, k.order) && java.util.Objects.equals(sku, k.sku);
        }
        @Override public int hashCode() { return java.util.Objects.hash(order, sku); }
    }
}
