package com.aquashop.order.domain;

import jakarta.persistence.*;

@Entity
@Table(name = "cart_line")
@IdClass(CartLine.Key.class)
public class CartLine {

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cart_id")
    private Cart cart;

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

    protected CartLine() { }

    CartLine(String sku, String name, int quantity, long unitPriceMinor, boolean livestock) {
        this.sku = sku;
        this.name = name;
        this.quantity = quantity;
        this.unitPriceMinor = unitPriceMinor;
        this.livestock = livestock;
    }

    void setCart(Cart cart) { this.cart = cart; }
    void setQuantity(int quantity) { this.quantity = quantity; }

    public String getSku() { return sku; }
    public String getName() { return name; }
    public int getQuantity() { return quantity; }
    public long getUnitPriceMinor() { return unitPriceMinor; }
    public boolean isLivestock() { return livestock; }

    public static class Key implements java.io.Serializable {
        private java.util.UUID cart;
        private String sku;
        public Key() { }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key k)) return false;
            return java.util.Objects.equals(cart, k.cart) && java.util.Objects.equals(sku, k.sku);
        }
        @Override public int hashCode() { return java.util.Objects.hash(cart, sku); }
    }
}
