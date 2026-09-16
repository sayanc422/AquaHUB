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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Finishes checkouts whose process died half way through.
 *
 * <p>This closes the gap every release note since Phase 3 has named: the saga
 * runs inside one request, and if this service dies between taking the money
 * and committing the holds, the holds expire on their own — so the stock comes
 * back — but <b>the refund never happens</b>. Until now the only thing that
 * found those orders was a human running a SQL query out of a runbook.
 *
 * <h2>Why this is not an outbox</h2>
 *
 * <p>{@link com.aquashop.order.service.CheckoutSaga} was going to get an outbox
 * table, and on reflection that would have been ceremony. An outbox exists to
 * record an intention that is otherwise nowhere on disk — which is exactly
 * payment-service's problem, where the charge does not exist until the intent
 * row is written.
 *
 * <p>Here the intention is already stored, in full: an order in {@code PAID}
 * with a payment reference and no dispatch window <em>is</em> the record of
 * "money taken, work unfinished". A parallel table would duplicate the order
 * row and then have to be kept consistent with it. What was missing was never
 * the record. It was something to read the record and act.
 *
 * <p>An outbox still earns its place when this service starts publishing events
 * to other systems, because a published event genuinely has no other home. That
 * is the messaging phase, not this one.
 *
 * <h2>Two ways to be stuck</h2>
 *
 * <ul>
 *   <li>{@code PAID} — money taken and recorded, holds not committed. Finish the
 *       saga: commit, or refund if the holds have since expired.</li>
 *   <li>{@code STOCK_RESERVED} — died during authorisation, so whether the money
 *       moved is unknown. Ask payment-service, and hand the order to the state
 *       that already exists for an unknown answer rather than guessing.</li>
 * </ul>
 *
 * <p>Unlike the reaper and the dispatch watcher, this one is load-bearing: stop
 * it and money stays taken for orders that will never ship. It is still safe —
 * every order it touches is already in a state that is correct and merely
 * unfinished, so a stopped recovery delays an outcome rather than corrupting
 * one. {@code orders_stuck} is the gauge that has to come back to zero.
 */
@Component
public class SagaRecovery {

    private static final Logger log = LoggerFactory.getLogger(SagaRecovery.class);

    private final OrderRepository orders;
    private final CheckoutSaga saga;
    private final OrderSteps steps;
    private final PaymentGateway payments;
    private final Clock clock;
    private final Duration stuckAfter;
    private final Counter finished;
    private final Counter refunded;
    private final Counter neverPaid;
    private final Counter handedOff;

    public SagaRecovery(OrderRepository orders, CheckoutSaga saga, OrderSteps steps,
                        PaymentGateway payments, Clock clock, MeterRegistry meters,
                        @Value("${orders.stuck-after-ms:120000}") long stuckAfterMs) {
        this.orders = orders;
        this.saga = saga;
        this.steps = steps;
        this.payments = payments;
        this.clock = clock;
        // Longer than the slowest checkout that could still be in flight, or
        // the recovery races the request that is already finishing the job.
        this.stuckAfter = Duration.ofMillis(stuckAfterMs);

        this.finished = counter(meters, "finished");
        this.refunded = counter(meters, "refunded");
        this.neverPaid = counter(meters, "never_paid");
        this.handedOff = counter(meters, "handed_to_reconciler");

        Gauge.builder("orders_stuck", this::stuckCount)
                .description("Orders sitting mid-checkout for longer than the recovery threshold. Must return to zero.")
                .register(meters);
    }

    private static Counter counter(MeterRegistry meters, String outcome) {
        return Counter.builder("orders_saga_recovered_total")
                .tag("outcome", outcome)
                .description("Checkouts finished by the recovery scan rather than by the request that started them.")
                .register(meters);
    }

    private int stuckCount() {
        Instant threshold = clock.instant().minus(stuckAfter);
        return orders.findStuckIn(OrderState.PAID, threshold).size()
                + orders.findStuckIn(OrderState.STOCK_RESERVED, threshold).size();
    }

    @Scheduled(fixedDelayString = "${orders.recovery-scan-interval-ms:60000}")
    public void scan() {
        Instant threshold = clock.instant().minus(stuckAfter);
        recoverPaid(orders.findStuckIn(OrderState.PAID, threshold));
        recoverReserved(orders.findStuckIn(OrderState.STOCK_RESERVED, threshold));
    }

    /**
     * Money taken, work unfinished. The most expensive state to leave alone,
     * and the one this class exists for.
     */
    private void recoverPaid(List<CustomerOrder> stuck) {
        for (CustomerOrder order : stuck) {
            if (order.getPaymentRef() == null) {
                // Unreachable through the saga -- a CHECK constraint requires a
                // payment reference at PAID. Loud rather than skipped, because
                // an order nobody can finish needs a person.
                log.error("order {} is PAID with no payment reference; it needs manual resolution",
                        order.getReference());
                continue;
            }
            // How long the money has been sitting taken is the number worth
            // seeing in the log; the dispatch window is null by definition here.
            log.warn("resuming a checkout that never finished: order={} stuck for {}s",
                    order.getReference(),
                    Duration.between(order.getUpdatedAt(), clock.instant()).toSeconds());

            CustomerOrder done = saga.finishCheckout(order.getId(), order.getPaymentRef());
            if (done.getState() == OrderState.REFUNDED) {
                refunded.increment();
                log.info("order {} refunded: the holds expired while it was stuck", done.getReference());
            } else {
                finished.increment();
                log.info("order {} finished, dispatch {}", done.getReference(), done.getDispatchAt());
            }
        }
    }

    /**
     * Died during authorisation, so whether the customer was charged is
     * unknown — which is a question this system already has an answer shape for.
     */
    private void recoverReserved(List<CustomerOrder> stuck) {
        for (CustomerOrder order : stuck) {
            // The key the saga would have used. Derived rather than read,
            // because an order that died here never got as far as storing it.
            String key = order.getPaymentIdempotencyKey() != null
                    ? order.getPaymentIdempotencyKey()
                    : CheckoutSaga.paymentKey(order);

            PaymentOutcome outcome = payments.resolve(key);
            switch (outcome) {
                case PaymentOutcome.Captured captured -> {
                    log.warn("order {} was charged before the process died; finishing it",
                            order.getReference());
                    steps.recordPayment(order.getId(), captured.paymentRef(), key);
                    CustomerOrder done = saga.finishCheckout(order.getId(), captured.paymentRef());
                    if (done.getState() == OrderState.REFUNDED) {
                        refunded.increment();
                    } else {
                        finished.increment();
                    }
                }
                case PaymentOutcome.NotTaken notTaken -> {
                    log.info("order {} was never charged ({}); releasing the holds",
                            order.getReference(), notTaken.reason());
                    neverPaid.increment();
                    steps.releaseAll(order.getId(), "abandoned mid-checkout, payment never taken");
                    steps.fail(order.getId(), OrderState.PAYMENT_FAILED,
                            "checkout did not complete and no payment was taken");
                }
                case PaymentOutcome.StillUnresolved ignored -> {
                    // Do not guess. Move it into the state that exists for this
                    // exact answer, and let PaymentReconciler own it from here.
                    log.warn("order {} is stuck and its payment is still unknown; handing it to the reconciler",
                            order.getReference());
                    handedOff.increment();
                    steps.markUnresolved(order.getId(), key,
                            "checkout did not complete and the payment outcome is unknown");
                }
            }
        }
    }
}
