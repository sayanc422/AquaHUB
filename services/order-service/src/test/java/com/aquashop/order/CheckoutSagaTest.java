package com.aquashop.order;

import com.aquashop.order.client.*;
import com.aquashop.order.domain.*;
import com.aquashop.order.payment.StubPaymentGateway;
import com.aquashop.order.repo.CartRepository;
import com.aquashop.order.repo.OrderEventRepository;
import com.aquashop.order.service.CheckoutSaga;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * The saga against a real Postgres.
 *
 * <p>Real, because what is being asserted is that each step committed its own
 * transaction and left the order in a state the next step could read — and an
 * in-memory database with different transaction semantics would prove nothing
 * about that. catalog-service uses Testcontainers for the same reason; this
 * service takes a DSN from the environment instead, so that the suite also runs
 * on a machine with no Docker. **Cost:** the database is not created for you,
 * and the tests skip silently when the variable is missing rather than failing
 * loudly, which is the trade Testcontainers exists to avoid.
 *
 * <pre>
 *   createdb orders_test
 *   ORDER_TEST_DSN=jdbc:postgresql://127.0.0.1:5432/orders_test \
 *   ORDER_TEST_USER=postgres mvn test
 * </pre>
 *
 * <p>inventory-service is a mock here, and deliberately: the point of these
 * tests is which compensation the saga performs, not whether the HTTP client
 * parses a response — {@link InventoryClientTest} covers that against a real
 * server. What is <em>not</em> covered by either is the two services running
 * together, which is why the phase also ends with a demonstration by hand.
 */
@SpringBootTest
@EnabledIfEnvironmentVariable(named = "ORDER_TEST_DSN", matches = ".+")
class CheckoutSagaTest {

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("ORDER_TEST_DSN"));
        registry.add("spring.datasource.username",
                () -> System.getenv().getOrDefault("ORDER_TEST_USER", "postgres"));
        registry.add("spring.datasource.password",
                () -> System.getenv().getOrDefault("ORDER_TEST_PASSWORD", ""));
        // The watcher would otherwise scan while the tests run.
        registry.add("orders.dispatch-scan-interval-ms", () -> "3600000");
    }

    @Autowired CheckoutSaga saga;
    @Autowired CartRepository carts;
    @Autowired OrderEventRepository events;
    @Autowired StubPaymentGateway payments;
    @MockBean InventoryClient inventory;

    @BeforeEach
    void resetGateway() {
        payments.setOutcome(StubPaymentGateway.Outcome.APPROVE);
        reset(inventory);
    }

    @Transactional
    UUID cartWith(String... skus) {
        Cart cart = carts.save(new Cart(UUID.randomUUID()));
        for (String sku : skus) {
            cart.put(sku, "Test " + sku, 2, 45000, true);
        }
        carts.save(cart);
        return cart.getId();
    }

    private void inventoryReserves() {
        when(inventory.reserve(anyString(), anyString(), anyString(), anyInt(), anyInt()))
                .thenAnswer(call -> new InventoryClient.Reservation(
                        UUID.randomUUID(), call.getArgument(1), call.getArgument(2),
                        call.getArgument(3), "held", "2026-09-13T12:00:00Z"));
    }

    // ---------------------------------------------------------------- happy

    @Test
    void anOrderThatGoesThroughEndsConfirmedWithADispatchWindow() {
        inventoryReserves();
        UUID cart = cartWith("FSH-NEO-01", "FSH-COR-01");

        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        assertThat(order.getState()).isEqualTo(OrderState.CONFIRMED);
        assertThat(order.getDispatchAt()).isNotNull();
        assertThat(order.getPaymentRef()).startsWith("pay_");
        assertThat(order.getTotalMinor()).isEqualTo(2 * 45000 * 2);
        // One hold per SKU, every one of them committed.
        assertThat(order.getReservations()).hasSize(2)
                .allMatch(r -> r.getState() == OrderReservation.State.COMMITTED);
        verify(inventory, times(2)).commit(any());
        verify(inventory, never()).release(any());
    }

    /**
     * The key must be derived from the order, not generated per attempt: a
     * retry after a timeout has to present the same key or it holds a second
     * set of fish.
     */
    @Test
    void theIdempotencyKeyIsDerivedFromTheOrderAndSku() {
        inventoryReserves();
        UUID cart = cartWith("FSH-NEO-01");

        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        verify(inventory).reserve(eq("order-" + order.getId() + "-FSH-NEO-01"),
                eq(order.getReference()), eq("FSH-NEO-01"), eq(2), anyInt());
    }

    // -------------------------------------------------------- compensation

    /**
     * The phase's headline: a payment failure must not strand stock. The holds
     * go back immediately rather than fifteen minutes later when they would
     * have expired anyway.
     */
    @Test
    void aDeclinedCardReleasesEveryHoldAndTakesNoMoney() {
        inventoryReserves();
        payments.setOutcome(StubPaymentGateway.Outcome.DECLINE);
        UUID cart = cartWith("FSH-NEO-01", "FSH-COR-01");

        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        assertThat(order.getState()).isEqualTo(OrderState.PAYMENT_FAILED);
        assertThat(order.getPaymentRef()).isNull();
        assertThat(order.getReservations()).hasSize(2)
                .allMatch(r -> r.getState() == OrderReservation.State.RELEASED);
        verify(inventory, times(2)).release(any());
        verify(inventory, never()).commit(any());

        // And the compensation is visible afterwards, which it is nowhere else.
        assertThat(events.findByOrderIdOrderByIdAsc(order.getId()))
                .extracting(OrderEvent::getDetail)
                .anyMatch(d -> d != null && d.contains("released hold"));
    }

    /**
     * A multi-line order that fails on its second line must give back the
     * first. This is the case a single-reservation design never has to face,
     * and the reason reservations are per SKU.
     */
    @Test
    void aPartlyReservedOrderReleasesTheHoldsItAlreadyTook() {
        // The *second* line fails, whichever SKU the saga reaches second. An
        // earlier version of this test named the SKUs, and passed or failed on
        // the order the lines happened to come back in.
        AtomicInteger attempts = new AtomicInteger();
        when(inventory.reserve(anyString(), anyString(), anyString(), anyInt(), anyInt()))
                .thenAnswer(call -> {
                    if (attempts.incrementAndGet() >= 2) {
                        throw new InsufficientStockException(call.getArgument(2), "insufficient_stock");
                    }
                    return new InventoryClient.Reservation(UUID.randomUUID(), call.getArgument(1),
                            call.getArgument(2), call.getArgument(3), "held", "2026-09-13T12:00:00Z");
                });

        UUID cart = cartWith("FSH-NEO-01", "FSH-COR-01");
        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        assertThat(order.getState()).isEqualTo(OrderState.STOCK_UNAVAILABLE);
        assertThat(order.getPaymentRef()).isNull();
        // The first line's hold was taken, and has been given back. This is the
        // assertion that failed when every line shared one transaction: the
        // rollback erased the row recording a hold that existed in the other
        // service, and the compensation found nothing to release.
        verify(inventory, times(1)).release(any());
        assertThat(order.getReservations())
                .singleElement()
                .matches(r -> r.getState() == OrderReservation.State.RELEASED);
    }

    /**
     * The expensive path: the money is taken and then the hold turns out to
     * have expired. The only honest outcome is a refund, and the order has to
     * say so by name — an order in PAYMENT_FAILED with the customer's money in
     * the account is the worst state available.
     */
    @Test
    void aHoldThatExpiresAfterPaymentIsRefundedNotSilentlyFailed() {
        inventoryReserves();
        doThrow(new ReservationExpiredException(UUID.randomUUID(), "reservation_expired"))
                .when(inventory).commit(any());

        UUID cart = cartWith("FSH-NEO-01");
        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        assertThat(order.getState()).isEqualTo(OrderState.REFUNDED);
        assertThat(order.getState().holdsMoney()).isFalse();
        // The payment reference survives: a refund without one is unauditable.
        assertThat(order.getPaymentRef()).startsWith("pay_");
        assertThat(order.getFailureReason()).contains("refunded");
    }

    /**
     * A compensation runs when something has already gone wrong, so it must not
     * be able to make things worse. A release that itself fails leaves the hold
     * to expire on its own and is recorded, not rethrown.
     */
    @Test
    void aFailingReleaseDoesNotHideTheOriginalFailure() {
        inventoryReserves();
        doThrow(new InventoryUnavailableException("inventory down")).when(inventory).release(any());
        payments.setOutcome(StubPaymentGateway.Outcome.DECLINE);

        UUID cart = cartWith("FSH-NEO-01");
        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        assertThat(order.getState()).isEqualTo(OrderState.PAYMENT_FAILED);
        assertThat(events.findByOrderIdOrderByIdAsc(order.getId()))
                .extracting(OrderEvent::getDetail)
                .anyMatch(d -> d != null && d.contains("release FAILED"));
    }

    @Test
    void everyTransitionIsRecordedInOrder() {
        inventoryReserves();
        UUID cart = cartWith("FSH-NEO-01");

        CustomerOrder order = saga.checkout(cart, "buyer@example.com");

        List<OrderState> states = events.findByOrderIdOrderByIdAsc(order.getId()).stream()
                .map(OrderEvent::getToState).toList();
        assertThat(states).containsSubsequence(
                OrderState.PENDING, OrderState.STOCK_RESERVED, OrderState.PAID, OrderState.CONFIRMED);
    }

    @Test
    void anEmptyCartIsRefusedBeforeAnythingIsReserved() {
        UUID cart = cartWith();
        try {
            saga.checkout(cart, "buyer@example.com");
            assertThat(false).as("an empty cart must not check out").isTrue();
        } catch (IllegalArgumentException expected) {
            verifyNoInteractions(inventory);
        }
    }
}
