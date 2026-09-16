package com.aquashop.order;

import com.aquashop.order.client.InventoryClient;
import com.aquashop.order.client.ReservationExpiredException;
import com.aquashop.order.domain.*;
import com.aquashop.order.payment.StubPaymentGateway;
import com.aquashop.order.repo.CartRepository;
import com.aquashop.order.repo.OrderEventRepository;
import com.aquashop.order.repo.OrderRepository;
import com.aquashop.order.service.CheckoutSaga;
import com.aquashop.order.service.SagaRecovery;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * The recovery scan, against a real Postgres.
 *
 * <p>What is being tested is a process death, which cannot be simulated by
 * killing the JVM inside a test. It is simulated the only honest way available:
 * run the saga to the exact state a death would leave behind, then age the row
 * past the threshold and let the scan find it. The state on disk is identical
 * either way, which is the whole reason the saga commits each step separately.
 */
@SpringBootTest
@EnabledIfEnvironmentVariable(named = "ORDER_TEST_DSN", matches = ".+")
class SagaRecoveryTest {

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("ORDER_TEST_DSN"));
        registry.add("spring.datasource.username",
                () -> System.getenv().getOrDefault("ORDER_TEST_USER", "postgres"));
        registry.add("spring.datasource.password",
                () -> System.getenv().getOrDefault("ORDER_TEST_PASSWORD", ""));
        // Every scheduler off: these tests drive the scan by hand so a passing
        // run is never a timing accident.
        registry.add("orders.dispatch-scan-interval-ms", () -> "3600000");
        registry.add("orders.payment-reconcile-interval-ms", () -> "3600000");
        registry.add("orders.recovery-scan-interval-ms", () -> "3600000");
        registry.add("orders.stuck-after-ms", () -> "0");
    }

    @Autowired CheckoutSaga saga;
    @Autowired SagaRecovery recovery;
    @Autowired CartRepository carts;
    @Autowired OrderRepository orders;
    @Autowired OrderEventRepository events;
    @Autowired StubPaymentGateway payments;
    @MockBean InventoryClient inventory;

    @BeforeEach
    void setUp() {
        payments.setOutcome(StubPaymentGateway.Outcome.APPROVE);
        reset(inventory);
        when(inventory.reserve(anyString(), anyString(), anyString(), anyInt(), anyInt()))
                .thenAnswer(call -> new InventoryClient.Reservation(
                        UUID.randomUUID(), call.getArgument(1), call.getArgument(2),
                        call.getArgument(3), "held", "2026-09-16T12:00:00Z"));
    }

    @Transactional
    UUID cart() {
        Cart cart = carts.save(new Cart(UUID.randomUUID()));
        cart.put("FSH-MAL-02", "Demasoni", 12, 85000, true);
        carts.save(cart);
        return cart.getId();
    }

    /**
     * The gap this class was written for.
     *
     * <p>Money taken, holds still held, and the process gone. Nothing else in
     * the system would ever have finished this order.
     */
    @Test
    void anOrderLeftPaidIsFinished() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        assertThat(order.getState()).isEqualTo(OrderState.CONFIRMED);

        // Rewind it to the state a death between step 2 and step 3 leaves.
        strand(order.getId(), OrderState.PAID);

        recovery.scan();

        CustomerOrder done = orders.findById(order.getId()).orElseThrow();
        assertThat(done.getState()).isEqualTo(OrderState.CONFIRMED);
        assertThat(done.getDispatchAt()).isNotNull();
        assertThat(done.getPaymentRef()).isNotNull();
    }

    /**
     * The ordinary case for an order that was stuck for a while: the holds
     * expired in the meantime. The money has to go back, and the order has to
     * say REFUNDED rather than quietly failing.
     */
    @Test
    void anOrderWhoseHoldsExpiredWhileStuckIsRefunded() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        strand(order.getId(), OrderState.PAID);

        doThrow(new ReservationExpiredException(UUID.randomUUID(), "reservation_expired"))
                .when(inventory).commit(any());

        recovery.scan();

        CustomerOrder done = orders.findById(order.getId()).orElseThrow();
        assertThat(done.getState()).isEqualTo(OrderState.REFUNDED);
        assertThat(done.getState().holdsMoney()).isFalse();
        assertThat(done.getPaymentRef()).isNotNull();   // a refund with no reference is unauditable
    }

    /**
     * Died during authorisation, and the money had in fact been taken. The
     * recovery asks rather than assuming, then finishes the job.
     */
    @Test
    void anOrderStrandedBeforePaymentIsFinishedWhenTheChargeTurnsOutToHaveHappened() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        String paymentRef = order.getPaymentRef();
        strand(order.getId(), OrderState.STOCK_RESERVED);

        // The stub remembers the authorisation under the order's key, which is
        // what makes "did this customer pay?" answerable after a crash.
        recovery.scan();

        CustomerOrder done = orders.findById(order.getId()).orElseThrow();
        assertThat(done.getState()).isEqualTo(OrderState.CONFIRMED);
        assertThat(done.getPaymentRef()).isEqualTo(paymentRef);
    }

    /**
     * Died before the card was ever charged. Only now is releasing the stock
     * correct: "no money moved" has become a fact rather than a guess.
     */
    @Test
    void anOrderStrandedWithNoChargeReleasesItsHoldsAndFails() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        strand(order.getId(), OrderState.STOCK_RESERVED);
        // Wipe the gateway's memory of the charge: the process died before it.
        payments.forget();

        recovery.scan();

        CustomerOrder done = orders.findById(order.getId()).orElseThrow();
        assertThat(done.getState()).isEqualTo(OrderState.PAYMENT_FAILED);
        assertThat(done.getState().holdsMoney()).isFalse();
        verify(inventory, atLeastOnce()).release(any());
    }

    /**
     * An order the recovery cannot resolve must not be guessed at. It goes to
     * the state that already exists for an unknown payment, and the reconciler
     * owns it from there.
     */
    @Test
    void anOrderWhosePaymentIsStillUnknownIsHandedToTheReconciler() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        strand(order.getId(), OrderState.STOCK_RESERVED);
        payments.setOutcome(StubPaymentGateway.Outcome.UNRESOLVED);
        payments.forget();

        recovery.scan();

        CustomerOrder done = orders.findById(order.getId()).orElseThrow();
        assertThat(done.getState()).isEqualTo(OrderState.PAYMENT_UNRESOLVED);
        assertThat(done.getPaymentIdempotencyKey()).isNotNull();
        // Holds left alone: releasing them would be a decision that the payment
        // failed, which is exactly what is not known.
        verify(inventory, never()).release(any());
    }

    /** A finished order is not stuck, however old it is. */
    @Test
    void aConfirmedOrderIsLeftAlone() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        clearInvocations(inventory);

        recovery.scan();

        assertThat(orders.findById(order.getId()).orElseThrow().getState())
                .isEqualTo(OrderState.CONFIRMED);
        verifyNoMoreInteractions(inventory);
    }

    /** Running it twice must not charge, refund or commit anything twice. */
    @Test
    void recoveringTheSameOrderTwiceChangesNothingTheSecondTime() {
        CustomerOrder order = saga.checkout(cart(), "buyer@example.com");
        strand(order.getId(), OrderState.PAID);

        recovery.scan();
        int eventsAfterFirst = events.findByOrderIdOrderByIdAsc(order.getId()).size();
        recovery.scan();

        assertThat(events.findByOrderIdOrderByIdAsc(order.getId())).hasSize(eventsAfterFirst);
        assertThat(orders.findById(order.getId()).orElseThrow().getState())
                .isEqualTo(OrderState.CONFIRMED);
    }

    /**
     * Put an order back into the state a process death would have left, and age
     * it past the threshold.
     *
     * <p>Written with SQL rather than through the domain, deliberately: the
     * state machine forbids going backwards, which is correct, and a test that
     * needed a back door in the production code would be testing the back door.
     */
    private void strand(UUID orderId, OrderState state) {
        orders.rewindForTest(orderId, state.name());
        // The holds too: a process that died before committing left them held,
        // and an order rewound without them has nothing left to commit.
        orders.rewindReservationsForTest(orderId);
    }
}
