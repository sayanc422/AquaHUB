package com.aquashop.order;

import com.aquashop.order.payment.*;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The gateway against a real HTTP server.
 *
 * <p>What is under test is the mapping from what payment-service says to what
 * the saga then does, and that mapping is where money is lost or kept. A mocked
 * client would assert that the mock returns what the test told it to.
 */
class HttpPaymentGatewayTest {

    private HttpServer server;
    private HttpPaymentGateway gateway;
    private final AtomicInteger status = new AtomicInteger(201);
    private final AtomicReference<String> body = new AtomicReference<>("{}");
    private final AtomicLong delayMs = new AtomicLong(0);

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            try {
                Thread.sleep(delayMs.get());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            byte[] out = body.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(status.get(), out.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(out);
            }
        });
        server.setExecutor(java.util.concurrent.Executors.newFixedThreadPool(2));
        server.start();

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofMillis(500));
        // Short, so the client-timeout case is a test rather than a wait.
        factory.setReadTimeout(Duration.ofMillis(300));
        gateway = new HttpPaymentGateway(RestClient.builder()
                .baseUrl("http://127.0.0.1:" + server.getAddress().getPort())
                .requestFactory(factory)
                .build());
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private void respond(int code, String json) {
        status.set(code);
        body.set(json);
    }

    @Test
    void a_captured_payment_returns_its_reference() {
        respond(201, "{\"id\":\"pay-1\",\"state\":\"captured\",\"balanceMinor\":1000,"
                + "\"holdsMoney\":true,\"resolved\":true}");
        assertThat(gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isEqualTo("pay-1");
    }

    @Test
    void a_replay_is_a_success_not_a_second_charge() {
        respond(200, "{\"id\":\"pay-1\",\"state\":\"captured\",\"balanceMinor\":1000,"
                + "\"holdsMoney\":true,\"resolved\":true}");
        assertThat(gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isEqualTo("pay-1");
    }

    @Test
    void a_decline_is_a_decline() {
        respond(402, "{\"error\":\"declined\",\"message\":\"card refused\"}");
        assertThatThrownBy(() -> gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isInstanceOf(PaymentDeclinedException.class);
    }

    /**
     * The distinction the whole phase turns on: a 504 is not a failure. Treating
     * it as one releases the stock while the customer's money is gone.
     */
    @Test
    void a_gateway_timeout_is_unresolved_never_declined() {
        respond(504, "{\"error\":\"acquirer_timeout\",\"message\":\"no answer\"}");
        assertThatThrownBy(() -> gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isInstanceOf(PaymentUnresolvedException.class)
                .isNotInstanceOf(PaymentDeclinedException.class)
                .extracting(e -> ((PaymentUnresolvedException) e).getIdempotencyKey())
                .isEqualTo("key-1");
    }

    /**
     * Our own client giving up means exactly what the server's 504 means: we
     * stopped waiting, and that says nothing about whether the charge happened.
     */
    @Test
    void our_own_read_timeout_is_also_unresolved() {
        delayMs.set(1500);
        respond(201, "{\"id\":\"pay-1\",\"state\":\"captured\",\"holdsMoney\":true}");
        assertThatThrownBy(() -> gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isInstanceOf(PaymentUnresolvedException.class);
    }

    @Test
    void an_unexpected_status_is_unresolved_rather_than_assumed_failed() {
        respond(500, "{}");
        assertThatThrownBy(() -> gateway.authorise("key-1", "AQ-1", 1000, "INR", "a@example.com"))
                .isInstanceOf(PaymentUnresolvedException.class);
    }

    // ------------------------------------------------------------- resolve

    @Test
    void resolve_reports_money_held_as_captured() {
        respond(200, "{\"id\":\"pay-7\",\"state\":\"captured\",\"balanceMinor\":1000,"
                + "\"holdsMoney\":true,\"resolved\":true}");
        assertThat(gateway.resolve("key-1"))
                .isEqualTo(new PaymentOutcome.Captured("pay-7"));
    }

    @Test
    void resolve_reports_a_declined_payment_as_not_taken() {
        respond(402, "{\"id\":\"pay-7\",\"state\":\"declined\",\"balanceMinor\":0,"
                + "\"holdsMoney\":false,\"resolved\":true}");
        assertThat(gateway.resolve("key-1")).isInstanceOf(PaymentOutcome.NotTaken.class);
    }

    /** payment-service never saw the key, so no charge was ever started. */
    @Test
    void resolve_reports_an_unknown_key_as_not_taken() {
        respond(404, "{\"error\":\"not_found\"}");
        assertThat(gateway.resolve("key-1")).isInstanceOf(PaymentOutcome.NotTaken.class);
    }

    /**
     * payment-service saying "still unknown" must not be flattened into "not
     * taken" — that is the same mistake as treating a timeout as a decline, one
     * service further along.
     */
    @Test
    void resolve_keeps_still_unknown_distinct_from_not_taken() {
        respond(504, "{\"error\":\"still_unresolved\"}");
        assertThat(gateway.resolve("key-1")).isInstanceOf(PaymentOutcome.StillUnresolved.class);
    }

    @Test
    void resolve_treats_an_unreachable_payment_service_as_still_unknown() {
        server.stop(0);
        assertThat(gateway.resolve("key-1")).isInstanceOf(PaymentOutcome.StillUnresolved.class);
    }
}
