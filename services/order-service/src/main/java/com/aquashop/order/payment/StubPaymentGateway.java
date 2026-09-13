package com.aquashop.order.payment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

/**
 * Stands in for payment-service until Phase 4 builds it in Rust.
 *
 * <p>The outcome is configuration, not a field on the request. A test hook in
 * the request body would be a hole in a production API — anyone who can place
 * an order could choose whether to pay. As a property it is set by whoever runs
 * the service, and it is obvious in the logs which mode is live.
 *
 * <p>This is a stub, and its limits should be stated rather than discovered: it
 * has no ledger, no idempotency of its own, no network, and no failure mode
 * between "declined" and "authorised". Nothing here demonstrates that the saga
 * survives a payment provider timing out, which is the failure a real one
 * spends most of its design on.
 */
@Component
@ConfigurationProperties(prefix = "payment.stub")
public class StubPaymentGateway implements PaymentGateway {

    private static final Logger log = LoggerFactory.getLogger(StubPaymentGateway.class);

    public enum Outcome { APPROVE, DECLINE }

    private Outcome outcome = Outcome.APPROVE;
    private final Map<String, Long> refunded = new ConcurrentHashMap<>();

    @Override
    public String authorise(String orderReference, long amountMinor, String currency, String email) {
        if (outcome == Outcome.DECLINE) {
            log.info("stub payment declined order={} amount={} {}", orderReference, amountMinor, currency);
            throw new PaymentDeclinedException("card declined (stub gateway configured to decline)");
        }
        String ref = "pay_" + UUID.randomUUID().toString().replace("-", "").substring(0, 20);
        log.info("stub payment authorised order={} amount={} {} ref={}",
                orderReference, amountMinor, currency, ref);
        return ref;
    }

    @Override
    public void refund(String paymentRef, long amountMinor, String reason) {
        Long previous = refunded.putIfAbsent(paymentRef, amountMinor);
        if (previous != null) {
            log.info("stub refund already performed ref={}", paymentRef);
            return;
        }
        log.info("stub refund ref={} amount={} reason={}", paymentRef, amountMinor, reason);
    }

    public Outcome getOutcome() { return outcome; }
    public void setOutcome(Outcome outcome) { this.outcome = outcome; }
}
