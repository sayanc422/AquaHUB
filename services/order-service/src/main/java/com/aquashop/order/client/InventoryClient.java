package com.aquashop.order.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.UUID;

/**
 * The order service's view of inventory-service.
 *
 * <p>Three calls, and the failure modes matter more than the happy path:
 *
 * <ul>
 *   <li><b>409 on reserve</b> is a business answer, not an error. The stock is
 *       not there; the order ends as STOCK_UNAVAILABLE and nobody is paged.</li>
 *   <li><b>409 on commit</b> means the hold expired. Payment has already been
 *       taken by then, so this is the branch that has to refund.</li>
 *   <li><b>Anything else</b> is unknown. Reserve is safe to retry because the
 *       idempotency key makes it so; commit and release are idempotent by
 *       design in that service.</li>
 * </ul>
 *
 * <p>Every call is bounded. An unbounded call here would let a slow inventory
 * service hold checkout threads until the pool is exhausted, which turns one
 * degraded dependency into a dead storefront.
 */
@Component
public class InventoryClient {

    private static final Logger log = LoggerFactory.getLogger(InventoryClient.class);

    private final RestClient http;

    public InventoryClient(RestClient inventoryRestClient) {
        this.http = inventoryRestClient;
    }

    /**
     * Hold stock for one SKU.
     *
     * @param idempotencyKey must be derived from the order, not generated per
     *                       attempt: a retry after a timeout has to present the
     *                       same key or it holds a second set of fish.
     */
    public Reservation reserve(String idempotencyKey, String orderRef, String sku, int quantity, int ttlSeconds) {
        return http.post()
                .uri("/v1/reservations")
                .header("Idempotency-Key", idempotencyKey)
                .body(new ReserveRequest(orderRef, sku, quantity, ttlSeconds))
                .exchange((request, response) -> {
                    HttpStatusCode status = response.getStatusCode();
                    if (status.is2xxSuccessful()) {
                        return response.bodyTo(Reservation.class);
                    }
                    if (status.value() == 409) {
                        Problem problem = response.bodyTo(Problem.class);
                        String code = problem == null ? "unknown" : problem.error();
                        log.info("reservation refused sku={} quantity={} reason={}", sku, quantity, code);
                        throw new InsufficientStockException(sku, code);
                    }
                    throw new InventoryUnavailableException(
                            "reserve returned " + status.value() + " for sku " + sku);
                });
    }

    /** Turn a hold into a sale. Idempotent in inventory-service. */
    public void commit(UUID reservationId) {
        http.post()
                .uri("/v1/reservations/{id}/commit", reservationId)
                .exchange((request, response) -> {
                    HttpStatusCode status = response.getStatusCode();
                    if (status.is2xxSuccessful()) {
                        return null;
                    }
                    if (status.value() == 409) {
                        Problem problem = response.bodyTo(Problem.class);
                        String code = problem == null ? "unknown" : problem.error();
                        throw new ReservationExpiredException(reservationId, code);
                    }
                    throw new InventoryUnavailableException(
                            "commit returned " + status.value() + " for reservation " + reservationId);
                });
    }

    /**
     * Give a hold back. This is the compensation, so it must not throw on a
     * hold that is already gone: releasing a released or expired reservation is
     * a no-op in inventory-service, and a compensation that fails because the
     * work was already undone is worse than useless.
     */
    public void release(UUID reservationId) {
        http.delete()
                .uri("/v1/reservations/{id}", reservationId)
                .exchange((request, response) -> {
                    HttpStatusCode status = response.getStatusCode();
                    if (status.is2xxSuccessful() || status.value() == 404) {
                        return null;
                    }
                    if (status.value() == 409) {
                        // Committed, so it cannot be released. Reversing a sale
                        // is a refund, and that is payment-service's job.
                        log.warn("release refused for committed reservation {}", reservationId);
                        return null;
                    }
                    throw new InventoryUnavailableException(
                            "release returned " + status.value() + " for reservation " + reservationId);
                });
    }

    public record ReserveRequest(String orderRef, String sku, int quantity, int ttlSeconds) { }

    public record Reservation(UUID id, String orderRef, String sku, int quantity,
                              String state, String expiresAt) { }

    public record Problem(String error, String message, String requestId) { }
}
