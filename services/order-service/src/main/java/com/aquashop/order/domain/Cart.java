package com.aquashop.order.domain;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * A cart. Deliberately thin: it holds quoted lines and nothing else.
 *
 * <p>There is no customer on it, because there are no accounts until Phase 5;
 * the storefront keeps the cart id in a cookie. Everything interesting happens
 * at checkout, and a cart that tried to reserve stock as items were added would
 * hold livestock out of the shop for every browsing customer.
 */
@Entity
@Table(name = "cart")
public class Cart {

    @Id
    private UUID id;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "cart", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<CartLine> lines = new ArrayList<>();

    protected Cart() { }

    public Cart(UUID id) {
        this.id = id;
        this.updatedAt = Instant.now();
    }

    /** Adding the same SKU twice replaces the quantity rather than duplicating the line. */
    public void put(String sku, String name, int quantity, long unitPriceMinor, boolean livestock) {
        Optional<CartLine> existing = lines.stream().filter(l -> l.getSku().equals(sku)).findFirst();
        if (existing.isPresent()) {
            existing.get().setQuantity(quantity);
        } else {
            CartLine line = new CartLine(sku, name, quantity, unitPriceMinor, livestock);
            line.setCart(this);
            lines.add(line);
        }
        this.updatedAt = Instant.now();
    }

    public void remove(String sku) {
        lines.removeIf(l -> l.getSku().equals(sku));
        this.updatedAt = Instant.now();
    }

    public long totalMinor() {
        return lines.stream().mapToLong(l -> l.getUnitPriceMinor() * l.getQuantity()).sum();
    }

    public UUID getId() { return id; }
    public List<CartLine> getLines() { return lines; }
    public Instant getCreatedAt() { return createdAt; }
}
