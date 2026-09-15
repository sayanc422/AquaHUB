package com.aquashop.order.domain;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * An order, and the only object allowed to change its own state.
 *
 * <p>The saga asks the order to make a transition; the order refuses an illegal
 * one. Putting the guard here rather than in the service means a future second
 * caller — an admin action, a message consumer, a retry — cannot bypass it by
 * forgetting to check.
 */
@Entity
@Table(name = "customer_order")
public class CustomerOrder {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true, length = 24)
    private String reference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private OrderState state;

    @Column(nullable = false, length = 190)
    private String email;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(name = "total_minor", nullable = false)
    private long totalMinor;

    @Column(name = "has_livestock", nullable = false)
    private boolean hasLivestock;

    @Column(name = "payment_ref", length = 64)
    private String paymentRef;

    /**
     * The idempotency key this order paid with. Stored rather than recomputed,
     * so that a change to how keys are derived cannot orphan an order whose
     * payment is still unresolved.
     */
    @Column(name = "payment_idempotency_key", length = 128)
    private String paymentIdempotencyKey;

    @Column(name = "dispatch_at")
    private Instant dispatchAt;

    @Column(name = "dispatchable_seen_at")
    private Instant dispatchableSeenAt;

    @Column(name = "failure_reason", length = 200)
    private String failureReason;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // Ordered, so the saga reserves lines in the same sequence every run and an
    // order renders the same way twice. An unordered collection makes a failure
    // depend on which line the database happened to return first.
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("sku")
    private List<OrderLine> lines = new ArrayList<>();

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("sku")
    private List<OrderReservation> reservations = new ArrayList<>();

    protected CustomerOrder() { }

    public CustomerOrder(UUID id, String reference, String email, String currency) {
        this.id = id;
        this.reference = reference;
        this.email = email;
        this.currency = currency;
        this.state = OrderState.PENDING;
        this.updatedAt = Instant.now();
    }

    /**
     * The only way the state changes. Returns the previous state so the caller
     * can record the transition; an illegal one throws rather than being
     * silently ignored, because an order that quietly refuses to advance is
     * harder to find than one that fails loudly.
     */
    public OrderState transitionTo(OrderState next) {
        if (!state.canTransitionTo(next)) {
            throw new IllegalTransitionException(state, next);
        }
        OrderState previous = state;
        this.state = next;
        this.updatedAt = Instant.now();
        return previous;
    }

    public void addLine(OrderLine line) {
        line.setOrder(this);
        lines.add(line);
        this.totalMinor += line.getUnitPriceMinor() * line.getQuantity();
        if (line.isLivestock()) {
            this.hasLivestock = true;
        }
    }

    public void addReservation(OrderReservation reservation) {
        reservation.setOrder(this);
        reservations.add(reservation);
    }

    /**
     * Shippability is derived, never stored. A confirmed order whose dispatch
     * time has passed is ready; nothing has to run for that to become true.
     */
    public boolean isDispatchable(Instant now) {
        return state == OrderState.CONFIRMED && dispatchAt != null && !now.isBefore(dispatchAt);
    }

    public UUID getId() { return id; }
    public String getReference() { return reference; }
    public OrderState getState() { return state; }
    public String getEmail() { return email; }
    public String getCurrency() { return currency; }
    public long getTotalMinor() { return totalMinor; }
    public boolean hasLivestock() { return hasLivestock; }
    public String getPaymentRef() { return paymentRef; }
    public Instant getDispatchAt() { return dispatchAt; }
    public Instant getDispatchableSeenAt() { return dispatchableSeenAt; }
    public String getFailureReason() { return failureReason; }
    public Instant getCreatedAt() { return createdAt; }
    public List<OrderLine> getLines() { return lines; }
    public List<OrderReservation> getReservations() { return reservations; }

    public String getPaymentIdempotencyKey() { return paymentIdempotencyKey; }

    public void setPaymentRef(String paymentRef) { this.paymentRef = paymentRef; }
    public void setPaymentIdempotencyKey(String key) { this.paymentIdempotencyKey = key; }
    public void setDispatchAt(Instant dispatchAt) { this.dispatchAt = dispatchAt; }
    public void setDispatchableSeenAt(Instant at) { this.dispatchableSeenAt = at; }
    public void setFailureReason(String reason) { this.failureReason = reason; }
}
