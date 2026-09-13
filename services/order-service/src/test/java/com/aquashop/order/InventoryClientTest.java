package com.aquashop.order;

import com.aquashop.order.client.*;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThatNoException;

/**
 * The client against a real HTTP server, because what is being tested is the
 * mapping from status codes to decisions the saga makes — and a mocked client
 * would assert that the mock returns what the test told it to.
 */
class InventoryClientTest {

    private HttpServer server;
    private InventoryClient client;
    private final AtomicReference<String> nextBody = new AtomicReference<>("{}");
    private final AtomicInteger nextStatus = new AtomicInteger(200);
    private final List<String> receivedIdempotencyKeys = new ArrayList<>();

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            String key = exchange.getRequestHeaders().getFirst("Idempotency-Key");
            if (key != null) {
                receivedIdempotencyKeys.add(key);
            }
            byte[] body = nextBody.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(nextStatus.get(), body.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(body);
            }
        });
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        client = new InventoryClient(RestClient.builder().baseUrl(base).build());
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    @Test
    void aSuccessfulReservationIsReturnedAndCarriesTheIdempotencyKey() {
        UUID id = UUID.randomUUID();
        nextStatus.set(201);
        nextBody.set("""
            {"id":"%s","orderRef":"AQ-1","sku":"FSH-NEO-01","quantity":6,
             "state":"held","expiresAt":"2026-09-13T12:00:00Z"}""".formatted(id));

        InventoryClient.Reservation reservation =
                client.reserve("order-1-FSH-NEO-01", "AQ-1", "FSH-NEO-01", 6, 900);

        assertThat(reservation.id()).isEqualTo(id);
        assertThat(reservation.state()).isEqualTo("held");
        assertThat(receivedIdempotencyKeys).containsExactly("order-1-FSH-NEO-01");
    }

    /**
     * 409 on reserve is a business answer, not a failure: the order ends as
     * STOCK_UNAVAILABLE and nobody is paged.
     */
    @Test
    void insufficientStockIsADistinctException() {
        nextStatus.set(409);
        nextBody.set("""
            {"error":"insufficient_stock","message":"not enough","requestId":"r1"}""");

        assertThatThrownBy(() -> client.reserve("k", "AQ-1", "FSH-NEO-01", 600, 900))
                .isInstanceOf(InsufficientStockException.class)
                .hasMessageContaining("FSH-NEO-01");
    }

    /** 409 on commit means the hold expired — and by then the money is taken. */
    @Test
    void anExpiredHoldOnCommitIsADistinctException() {
        nextStatus.set(409);
        nextBody.set("""
            {"error":"reservation_expired","message":"gone","requestId":"r1"}""");

        assertThatThrownBy(() -> client.commit(UUID.randomUUID()))
                .isInstanceOf(ReservationExpiredException.class);
    }

    @Test
    void anUnexpectedStatusIsUnknownNotABusinessDecision() {
        nextStatus.set(503);
        nextBody.set("{}");

        assertThatThrownBy(() -> client.reserve("k", "AQ-1", "FSH-NEO-01", 1, 900))
                .isInstanceOf(InventoryUnavailableException.class);
    }

    /**
     * Release is the compensation, so it must not throw on a hold that has
     * already gone. A compensation that fails because the work was already
     * undone is worse than useless.
     */
    @Test
    void releasingAHoldThatIsAlreadyGoneIsNotAFailure() {
        nextStatus.set(404);
        nextBody.set("{\"error\":\"not_found\",\"message\":\"no such reservation\"}");
        assertThatNoException().isThrownBy(() -> client.release(UUID.randomUUID()));

        nextStatus.set(409);
        nextBody.set("{\"error\":\"invalid_state\",\"message\":\"already committed\"}");
        assertThatNoException().isThrownBy(() -> client.release(UUID.randomUUID()));
    }

    @Test
    void releaseStillReportsAnUnreachableService() {
        nextStatus.set(500);
        nextBody.set("{}");
        assertThatThrownBy(() -> client.release(UUID.randomUUID()))
                .isInstanceOf(InventoryUnavailableException.class);
    }
}
