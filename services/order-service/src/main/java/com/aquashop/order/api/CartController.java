package com.aquashop.order.api;

import com.aquashop.order.domain.Cart;
import com.aquashop.order.repo.CartRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.UUID;

@RestController
@RequestMapping("/v1/carts")
public class CartController {

    private final CartRepository carts;

    public CartController(CartRepository carts) {
        this.carts = carts;
    }

    @PostMapping
    @Transactional
    public ResponseEntity<OrderDtos.CartView> create() {
        Cart cart = carts.save(new Cart(UUID.randomUUID()));
        return ResponseEntity.status(HttpStatus.CREATED)
                .header("Location", "/v1/carts/" + cart.getId())
                .body(OrderDtos.CartView.of(cart));
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public OrderDtos.CartView get(@PathVariable UUID id) {
        return OrderDtos.CartView.of(load(id));
    }

    /**
     * Adding the same SKU twice sets the quantity rather than adding to it, so
     * a retried request cannot silently double an order line.
     */
    @PutMapping("/{id}/lines")
    @Transactional
    public OrderDtos.CartView putLine(@PathVariable UUID id, @Valid @RequestBody OrderDtos.AddLineRequest body) {
        Cart cart = load(id);
        cart.put(body.sku(), body.name(), body.quantity(), body.unitPriceMinor(), body.livestock());
        carts.save(cart);
        return OrderDtos.CartView.of(cart);
    }

    @DeleteMapping("/{id}/lines/{sku}")
    @Transactional
    public OrderDtos.CartView removeLine(@PathVariable UUID id, @PathVariable String sku) {
        Cart cart = load(id);
        cart.remove(sku);
        carts.save(cart);
        return OrderDtos.CartView.of(cart);
    }

    private Cart load(UUID id) {
        return carts.findWithLines(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "no such cart"));
    }
}
