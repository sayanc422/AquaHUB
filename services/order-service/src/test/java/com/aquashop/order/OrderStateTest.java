package com.aquashop.order;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.domain.IllegalTransitionException;
import com.aquashop.order.domain.OrderState;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OrderStateTest {

    private static CustomerOrder order() {
        return new CustomerOrder(UUID.randomUUID(), "AQ-TEST", "a@example.com", "INR");
    }

    @Test
    void theHappyPathIsAllowedEndToEnd() {
        CustomerOrder o = order();
        o.transitionTo(OrderState.STOCK_RESERVED);
        o.transitionTo(OrderState.PAID);
        o.transitionTo(OrderState.CONFIRMED);
        o.transitionTo(OrderState.SHIPPED);
        assertThat(o.getState()).isEqualTo(OrderState.SHIPPED);
        assertThat(o.getState().isTerminal()).isTrue();
    }

    /**
     * The transition that must not exist. Once the money is taken, the way out
     * is a refund that says so by name — an order sitting in PAYMENT_FAILED
     * with the customer's money in the account is the worst outcome available.
     */
    @Test
    void aPaidOrderCanNeverBecomePaymentFailed() {
        CustomerOrder o = order();
        o.transitionTo(OrderState.STOCK_RESERVED);
        o.transitionTo(OrderState.PAID);
        assertThatThrownBy(() -> o.transitionTo(OrderState.PAYMENT_FAILED))
                .isInstanceOf(IllegalTransitionException.class);
        assertThat(o.getState()).isEqualTo(OrderState.PAID);
    }

    @Test
    void aPaidOrderCannotBeSimplyCancelled() {
        CustomerOrder o = order();
        o.transitionTo(OrderState.STOCK_RESERVED);
        o.transitionTo(OrderState.PAID);
        assertThatThrownBy(() -> o.transitionTo(OrderState.CANCELLED))
                .isInstanceOf(IllegalTransitionException.class);
    }

    @Test
    void everyTerminalStateIsAbsorbing() {
        for (OrderState state : OrderState.values()) {
            if (state.isTerminal()) {
                assertThat(state.allowedNext())
                        .as("%s must have no outgoing transitions", state)
                        .isEmpty();
            }
        }
    }

    @Test
    void statesThatHoldMoneyAreExactlyTheOnesAfterAuthorisation() {
        assertThat(OrderState.PAID.holdsMoney()).isTrue();
        assertThat(OrderState.CONFIRMED.holdsMoney()).isTrue();
        assertThat(OrderState.SHIPPED.holdsMoney()).isTrue();
        assertThat(OrderState.REFUNDED.holdsMoney()).isFalse();
        assertThat(OrderState.PAYMENT_FAILED.holdsMoney()).isFalse();
        assertThat(OrderState.STOCK_RESERVED.holdsMoney()).isFalse();
    }

    @Test
    void skippingAStepIsRefused() {
        CustomerOrder o = order();
        assertThatThrownBy(() -> o.transitionTo(OrderState.PAID))
                .isInstanceOf(IllegalTransitionException.class);
        assertThatThrownBy(() -> o.transitionTo(OrderState.CONFIRMED))
                .isInstanceOf(IllegalTransitionException.class);
    }

    @Test
    void aConfirmedOrderIsDispatchableOnlyOnceItsWindowOpens() {
        CustomerOrder o = order();
        o.transitionTo(OrderState.STOCK_RESERVED);
        o.transitionTo(OrderState.PAID);
        o.transitionTo(OrderState.CONFIRMED);

        java.time.Instant window = java.time.Instant.parse("2026-09-21T08:30:00Z");
        o.setDispatchAt(window);

        assertThat(o.isDispatchable(window.minusSeconds(1))).isFalse();
        assertThat(o.isDispatchable(window)).isTrue();
        assertThat(o.isDispatchable(window.plusSeconds(86_400))).isTrue();
    }

    @Test
    void anOrderThatIsNotConfirmedIsNeverDispatchable() {
        CustomerOrder o = order();
        o.setDispatchAt(java.time.Instant.EPOCH);
        assertThat(o.isDispatchable(java.time.Instant.now())).isFalse();
    }
}
