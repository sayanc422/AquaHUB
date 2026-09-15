package com.aquashop.order.service;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.domain.OrderState;
import com.aquashop.order.payment.PaymentGateway;
import com.aquashop.order.payment.PaymentOutcome;
import com.aquashop.order.repo.OrderRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Finishes checkouts whose payment outcome was unknown.
 *
 * <p><b>This one is load-bearing, and that has to be said plainly.</b> The reaper
 * in inventory-service and the dispatch watcher are bookkeeping: stop them and
 * nothing is wrong ([ADR 0011]). Stop this and orders sit in
 * {@code PAYMENT_UNRESOLVED} forever — customers who were charged never get
 * their fish, and customers who were not are never told.
 *
 * <p>The difference is not carelessness, it is the problem: resolving requires
 * <em>asking another party</em>, and no amount of schema design makes that
 * derivable from a clock. What remains true is the safety property — an
 * unresolved order is never treated as paid and never has its stock released,
 * so a stopped reconciler delays the answer rather than producing a wrong one.
 *
 * <p>The gauge {@code orders_payment_unresolved} is the alert. It is a number
 * that must come back to zero.
 */
@Component
public class PaymentReconciler {

    private static final Logger log = LoggerFactory.getLogger(PaymentReconciler.class);

    private final OrderRepository orders;
    private final CheckoutSaga saga;
    private final OrderSteps steps;
    private final PaymentGateway payments;
    private final Counter resolvedCaptured;
    private final Counter resolvedNotTaken;

    public PaymentReconciler(OrderRepository orders, CheckoutSaga saga, OrderSteps steps,
                             PaymentGateway payments, MeterRegistry meters) {
        this.orders = orders;
        this.saga = saga;
        this.steps = steps;
        this.payments = payments;
        this.resolvedCaptured = Counter.builder("orders_payment_resolved_total")
                .tag("outcome", "captured")
                .description("Unresolved payments later found to have been taken.")
                .register(meters);
        this.resolvedNotTaken = Counter.builder("orders_payment_resolved_total")
                .tag("outcome", "not_taken")
                .description("Unresolved payments later found never to have been taken.")
                .register(meters);
        Gauge.builder("orders_payment_unresolved",
                        () -> orders.findUnresolvedPayments(OrderState.PAYMENT_UNRESOLVED).size())
                .description("Orders whose payment outcome is still unknown. Must return to zero.")
                .register(meters);
    }

    @Scheduled(fixedDelayString = "${orders.payment-reconcile-interval-ms:30000}")
    public void scan() {
        List<CustomerOrder> unresolved = orders.findUnresolvedPayments(OrderState.PAYMENT_UNRESOLVED);
        if (unresolved.isEmpty()) {
            return;
        }
        log.info("resolving {} order(s) with an unknown payment outcome", unresolved.size());

        for (CustomerOrder order : unresolved) {
            String key = order.getPaymentIdempotencyKey();
            if (key == null) {
                // Cannot happen through the saga, which writes the key before
                // the state. Loud rather than skipped, because an order nobody
                // can resolve needs a person.
                log.error("order {} is unresolved with no payment key; it needs manual resolution",
                        order.getReference());
                continue;
            }

            PaymentOutcome outcome = payments.resolve(key);
            switch (outcome) {
                case PaymentOutcome.Captured captured -> {
                    log.info("order {} was paid after all; resuming checkout", order.getReference());
                    resolvedCaptured.increment();
                    // Steps 3 and 4, from where the request left off. The holds
                    // have most likely expired by now; the refund branch in the
                    // saga is what that turns into.
                    saga.resumeAfterPayment(order.getId(), captured.paymentRef());
                }
                case PaymentOutcome.NotTaken notTaken -> {
                    log.info("order {} was never charged ({}); releasing the holds",
                            order.getReference(), notTaken.reason());
                    resolvedNotTaken.increment();
                    // Only now is releasing correct: "no money moved" has become
                    // a fact rather than a guess.
                    steps.releaseAll(order.getId(), "payment resolved as never taken");
                    steps.failUnresolved(order.getId(),
                            "payment was never taken: " + notTaken.reason());
                }
                case PaymentOutcome.StillUnresolved ignored ->
                        log.warn("order {} is still unresolved; will ask again", order.getReference());
            }
        }
    }
}
