package com.aquashop.order.payment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
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
 * has no ledger, no network, and no failure mode between "declined" and
 * "authorised" — in particular it cannot time out, which is the failure a real
 * provider spends most of its design on. {@code HttpPaymentGateway} against the
 * real payment-service is what exercises that path; this one exists so the
 * suite and the core profile can run without a second service.
 */
@Component
@ConditionalOnProperty(name = "payment.gateway", havingValue = "stub", matchIfMissing = true)
@ConfigurationProperties(prefix = "payment.stub")
public class StubPaymentGateway implements PaymentGateway {

    private static final Logger log = LoggerFactory.getLogger(StubPaymentGateway.class);

    public enum Outcome {
        APPROVE,
        DECLINE,
        /**
         * The provider did not answer. Only reachable by configuration, and
         * only so the unknown-outcome path can be exercised without running a
         * second service -- the real one arrives through HttpPaymentGateway.
         */
        UNRESOLVED
    }

    private Outcome outcome = Outcome.APPROVE;
    private final Map<String, Long> refunded = new ConcurrentHashMap<>();
    private final Map<String, String> authorised = new ConcurrentHashMap<>();

    @Override
    public String authorise(String idempotencyKey, String orderReference, long amountMinor,
                            String currency, String email) {
        if (outcome == Outcome.DECLINE) {
            log.info("stub payment declined order={} amount={} {}", orderReference, amountMinor, currency);
            throw new PaymentDeclinedException("card declined (stub gateway configured to decline)");
        }
        if (outcome == Outcome.UNRESOLVED) {
            log.info("stub payment unresolved order={} key={}", orderReference, idempotencyKey);
            throw new PaymentUnresolvedException(idempotencyKey,
                    "the stub gateway is configured not to answer");
        }
        String ref = "pay_" + UUID.randomUUID().toString().replace("-", "").substring(0, 20);
        authorised.put(idempotencyKey, ref);
        log.info("stub payment authorised order={} amount={} {} ref={}",
                orderReference, amountMinor, currency, ref);
        return ref;
    }

    @Override
    public PaymentOutcome resolve(String idempotencyKey) {
        if (outcome == Outcome.UNRESOLVED) {
            // A provider that will not answer an authorisation will not answer
            // a lookup either. Without this the stub could never produce
            // StillUnresolved, and the one path that exists for "we do not
            // know" would be untestable through it.
            return new PaymentOutcome.StillUnresolved();
        }
        String ref = authorised.get(idempotencyKey);
        return ref == null
                ? new PaymentOutcome.NotTaken("the stub gateway has no record of this key")
                : new PaymentOutcome.Captured(ref);
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

    /**
     * Forget every authorisation. Models a process that died before the card
     * was ever charged, which the real gateway expresses by simply having no
     * record of the key.
     */
    public void forget() { authorised.clear(); }

    public Outcome getOutcome() { return outcome; }
    public void setOutcome(Outcome outcome) { this.outcome = outcome; }
}
