package com.aquashop.order.api;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.repo.OrderEventRepository;
import com.aquashop.order.repo.OrderRepository;
import com.aquashop.order.service.CheckoutSaga;
import com.aquashop.order.service.OrderSteps;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/v1/orders")
public class OrderController {

    private final CheckoutSaga checkout;
    private final OrderSteps steps;
    private final OrderRepository orders;
    private final OrderEventRepository events;
    private final Clock clock;

    public OrderController(CheckoutSaga checkout, OrderSteps steps, OrderRepository orders,
                           OrderEventRepository events, Clock clock) {
        this.checkout = checkout;
        this.steps = steps;
        this.orders = orders;
        this.events = events;
        this.clock = clock;
    }

    /**
     * Check out a cart.
     *
     * <p>Always 201 with the order, even when the order failed. A declined card
     * is not an HTTP error: the request succeeded, and the answer is an order in
     * state PAYMENT_FAILED. Returning 4xx here would make the storefront guess
     * from a status code what the body already says precisely.
     */
    @PostMapping("/from-cart/{cartId}")
    public ResponseEntity<OrderDtos.OrderView> checkout(
            @PathVariable UUID cartId, @Valid @RequestBody OrderDtos.CheckoutRequest body) {
        CustomerOrder order;
        try {
            order = checkout.checkout(cartId, body.email());
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .header("Location", "/v1/orders/" + order.getId())
                .body(OrderDtos.OrderView.of(order, clock.instant()));
    }

    @GetMapping("/{id}")
    public OrderDtos.OrderView get(@PathVariable UUID id) {
        try {
            return OrderDtos.OrderView.of(steps.load(id), clock.instant());
        } catch (java.util.NoSuchElementException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "no such order");
        }
    }

    @GetMapping("/by-reference/{reference}")
    @Transactional(readOnly = true)
    public OrderDtos.OrderView byReference(@PathVariable String reference) {
        CustomerOrder order = orders.findByReference(reference)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "no such order"));
        order.getLines().size();
        order.getReservations().size();
        return OrderDtos.OrderView.of(order, clock.instant());
    }

    /**
     * The audit trail. This is where a compensation is visible after the fact —
     * a released hold leaves no mark on the order itself.
     */
    @GetMapping("/{id}/events")
    public List<OrderDtos.EventView> events(@PathVariable UUID id) {
        List<OrderDtos.EventView> found = events.findByOrderIdOrderByIdAsc(id).stream()
                .map(OrderDtos.EventView::of).toList();
        if (found.isEmpty() && orders.findById(id).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "no such order");
        }
        return found;
    }
}
