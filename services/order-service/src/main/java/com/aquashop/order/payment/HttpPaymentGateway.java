package com.aquashop.order.payment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

/**
 * payment-service, over HTTP.
 *
 * <p>The status codes it returns are decisions, not noise, and each maps to a
 * different branch of the saga:
 *
 * <ul>
 *   <li><b>201 / 200</b> — the money was taken (200 means this key had already
 *       taken it; a replay, not a second charge).</li>
 *   <li><b>402</b> — declined. No money moved, and the holds can be released
 *       immediately.</li>
 *   <li><b>504</b> — <b>unknown.</b> The acquirer did not answer. The money may
 *       or may not have been taken, and the only correct response is to say so
 *       and ask again later.</li>
 * </ul>
 *
 * <p>A client-side timeout is treated exactly like a 504, because it means the
 * same thing: this service stopped waiting, which tells it nothing about
 * whether the charge happened.
 */
@Component
@ConditionalOnProperty(name = "payment.gateway", havingValue = "http")
public class HttpPaymentGateway implements PaymentGateway {

    private static final Logger log = LoggerFactory.getLogger(HttpPaymentGateway.class);

    private final RestClient http;

    public HttpPaymentGateway(RestClient paymentRestClient) {
        this.http = paymentRestClient;
        log.info("payment gateway: payment-service over HTTP");
    }

    @Override
    public String authorise(String idempotencyKey, String orderReference, long amountMinor,
                            String currency, String email) {
        try {
            return http.post()
                    .uri("/v1/payments")
                    .header("Idempotency-Key", idempotencyKey)
                    .body(new CreatePayment(orderReference, amountMinor, currency))
                    .exchange((request, response) -> {
                        HttpStatusCode status = response.getStatusCode();
                        if (status.is2xxSuccessful()) {
                            PaymentView view = response.bodyTo(PaymentView.class);
                            if (view == null || view.id() == null) {
                                throw new PaymentUnresolvedException(idempotencyKey,
                                        "payment-service answered 2xx with no payment");
                            }
                            return view.id();
                        }
                        if (status.value() == 402) {
                            throw new PaymentDeclinedException(describe(response.bodyTo(Problem.class)));
                        }
                        if (status.value() == 504) {
                            throw new PaymentUnresolvedException(idempotencyKey,
                                    describe(response.bodyTo(Problem.class)));
                        }
                        // 409 (key reused for a different request) and anything
                        // else are bugs here, not payment outcomes -- but the
                        // money status is still unknown, so they are not
                        // failures either.
                        throw new PaymentUnresolvedException(idempotencyKey,
                                "payment-service returned " + status.value());
                    });
        } catch (ResourceAccessException e) {
            // A read timeout or a refused connection. We stopped waiting; that
            // says nothing about whether the customer was charged.
            throw new PaymentUnresolvedException(idempotencyKey,
                    "payment-service did not answer: " + e.getMessage());
        }
    }

    @Override
    public PaymentOutcome resolve(String idempotencyKey) {
        try {
            return http.get()
                    .uri("/v1/payments/by-key/{key}", idempotencyKey)
                    .exchange((request, response) -> {
                        HttpStatusCode status = response.getStatusCode();
                        if (status.is2xxSuccessful()) {
                            PaymentView view = response.bodyTo(PaymentView.class);
                            if (view != null && view.holdsMoney()) {
                                return new PaymentOutcome.Captured(view.id());
                            }
                            return new PaymentOutcome.NotTaken(
                                    view == null ? "unreadable" : view.state());
                        }
                        if (status.value() == 402) {
                            // Resolved, and resolved to "no money moved".
                            PaymentView view = response.bodyTo(PaymentView.class);
                            return new PaymentOutcome.NotTaken(
                                    view == null ? "declined" : view.state());
                        }
                        if (status.value() == 404) {
                            // payment-service never saw this key, so no charge
                            // was ever started. Safe to treat as not taken.
                            return new PaymentOutcome.NotTaken("no payment was started");
                        }
                        // 504 here means payment-service itself still does not
                        // know. Asking again later is the only correct answer.
                        return new PaymentOutcome.StillUnresolved();
                    });
        } catch (ResourceAccessException e) {
            log.warn("could not reach payment-service to resolve {}: {}", idempotencyKey, e.getMessage());
            return new PaymentOutcome.StillUnresolved();
        }
    }

    @Override
    public void refund(String paymentRef, long amountMinor, String reason) {
        // The refund key is derived from the payment, so a retried refund is
        // recognised by payment-service and pays out once.
        http.post()
                .uri("/v1/payments/{id}/refund", paymentRef)
                .header("Idempotency-Key", "refund-" + paymentRef)
                .body(new RefundBody(amountMinor, reason))
                .exchange((request, response) -> {
                    HttpStatusCode status = response.getStatusCode();
                    if (status.is2xxSuccessful()) {
                        return null;
                    }
                    // A refused refund is loud. Money the customer is owed and
                    // has not been given back is the one thing that must never
                    // be swallowed.
                    log.error("refund refused for payment {}: HTTP {}", paymentRef, status.value());
                    throw new IllegalStateException(
                            "refund refused for payment " + paymentRef + ": HTTP " + status.value());
                });
    }

    private static String describe(Problem problem) {
        return problem == null ? "no detail" : problem.error() + ": " + problem.message();
    }

    record CreatePayment(String orderReference, long amountMinor, String currency) { }

    record RefundBody(long amountMinor, String reason) { }

    record PaymentView(String id, String state, long balanceMinor, boolean holdsMoney, boolean resolved) { }

    record Problem(String error, String message) { }
}
