package com.aquashop.order.domain;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * One recorded transition.
 *
 * <p>This table is the only place a compensation is visible after the fact: a
 * released hold leaves no trace on the order itself, and "why does this order
 * say PAYMENT_FAILED when the customer says they were charged?" is answered
 * here or not at all.
 */
@Entity
@Table(name = "order_event")
public class OrderEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_id", nullable = false)
    private UUID orderId;

    @Column(nullable = false, insertable = false, updatable = false)
    private Instant at;

    @Enumerated(EnumType.STRING)
    @Column(name = "from_state", length = 24)
    private OrderState fromState;

    @Enumerated(EnumType.STRING)
    @Column(name = "to_state", nullable = false, length = 24)
    private OrderState toState;

    @Column(length = 500)
    private String detail;

    protected OrderEvent() { }

    public OrderEvent(UUID orderId, OrderState fromState, OrderState toState, String detail) {
        this.orderId = orderId;
        this.fromState = fromState;
        this.toState = toState;
        this.detail = detail;
    }

    public Long getId() { return id; }
    public UUID getOrderId() { return orderId; }
    public Instant getAt() { return at; }
    public OrderState getFromState() { return fromState; }
    public OrderState getToState() { return toState; }
    public String getDetail() { return detail; }
}
