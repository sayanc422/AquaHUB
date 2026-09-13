package com.aquashop.order.domain;

import jakarta.persistence.*;

import java.util.UUID;

/**
 * One hold in inventory-service, as this service remembers it.
 *
 * <p>There is a row per SKU because inventory-service reserves per SKU: an
 * order for three species is three reservations, and a saga that fails on the
 * third must release the first two. The {@code reservationId} is a UUID handed
 * over by another service — not a foreign key, because a foreign key across a
 * service boundary would make the boundary a lie.
 */
@Entity
@Table(name = "order_reservation")
@IdClass(OrderReservation.Key.class)
public class OrderReservation {

    public enum State { HELD, COMMITTED, RELEASED }

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id")
    private CustomerOrder order;

    @Id
    @Column(length = 32)
    private String sku;

    @Column(name = "reservation_id", nullable = false)
    private UUID reservationId;

    @Column(nullable = false)
    private int quantity;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private State state;

    protected OrderReservation() { }

    public OrderReservation(String sku, UUID reservationId, int quantity) {
        this.sku = sku;
        this.reservationId = reservationId;
        this.quantity = quantity;
        this.state = State.HELD;
    }

    void setOrder(CustomerOrder order) { this.order = order; }

    public String getSku() { return sku; }
    public UUID getReservationId() { return reservationId; }
    public int getQuantity() { return quantity; }
    public State getState() { return state; }
    public void markCommitted() { this.state = State.COMMITTED; }
    public void markReleased() { this.state = State.RELEASED; }

    public static class Key implements java.io.Serializable {
        private UUID order;
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
