package com.aquashop.order.api;

import com.aquashop.order.domain.*;
import jakarta.validation.constraints.*;

import java.time.Instant;
import java.util.List;

/**
 * Wire contract. Separate from the entities for the same reason as in
 * catalog-service: the schema is this service's private business and the JSON
 * is a contract the storefront depends on.
 */
public final class OrderDtos {

    private OrderDtos() { }

    public record AddLineRequest(
            @NotBlank @Size(max = 32) String sku,
            @NotBlank @Size(max = 160) String name,
            @Min(1) @Max(500) int quantity,
            @Min(0) long unitPriceMinor,
            boolean livestock) { }

    public record CheckoutRequest(@NotBlank @Email @Size(max = 190) String email) { }

    public record LineView(String sku, String name, int quantity, long unitPriceMinor, boolean livestock) {
        static LineView of(OrderLine l) {
            return new LineView(l.getSku(), l.getName(), l.getQuantity(), l.getUnitPriceMinor(), l.isLivestock());
        }
        static LineView of(CartLine l) {
            return new LineView(l.getSku(), l.getName(), l.getQuantity(), l.getUnitPriceMinor(), l.isLivestock());
        }
    }

    public record CartView(String id, List<LineView> lines, long totalMinor) {
        public static CartView of(Cart cart) {
            return new CartView(cart.getId().toString(),
                    cart.getLines().stream().map(LineView::of).toList(),
                    cart.totalMinor());
        }
    }

    public record ReservationView(String sku, String reservationId, int quantity, String state) {
        static ReservationView of(OrderReservation r) {
            return new ReservationView(r.getSku(), r.getReservationId().toString(),
                    r.getQuantity(), r.getState().name());
        }
    }

    public record OrderView(
            String id, String reference, String state, String email,
            String currency, long totalMinor, boolean hasLivestock,
            String paymentRef, Instant dispatchAt,
            /**
             * Derived, never stored. A confirmed order whose dispatch time has
             * passed is ready to ship, and nothing has to run for that to
             * become true.
             */
            boolean dispatchable,
            String failureReason, Instant createdAt,
            List<LineView> lines, List<ReservationView> reservations) {

        public static OrderView of(CustomerOrder o, Instant now) {
            return new OrderView(
                    o.getId().toString(), o.getReference(), o.getState().name(), o.getEmail(),
                    o.getCurrency(), o.getTotalMinor(), o.hasLivestock(),
                    o.getPaymentRef(), o.getDispatchAt(), o.isDispatchable(now),
                    o.getFailureReason(), o.getCreatedAt(),
                    o.getLines().stream().map(LineView::of).toList(),
                    o.getReservations().stream().map(ReservationView::of).toList());
        }
    }

    public record EventView(Instant at, String from, String to, String detail) {
        public static EventView of(OrderEvent e) {
            return new EventView(e.getAt(),
                    e.getFromState() == null ? null : e.getFromState().name(),
                    e.getToState().name(), e.getDetail());
        }
    }
}
