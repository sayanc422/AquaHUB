package com.aquashop.staffportal.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.*;

/**
 * No mock backend framework here -- a plain com.sun.net.httpserver.HttpServer
 * stub is enough to prove the 404/timeout/JSON-parsing behaviour that
 * BackendClient's callers (CatalogClient, InventoryClient, OrderClient) all
 * depend on, without pulling in a dependency for it.
 */
class BackendClientTest {

    private HttpServer server;

    @AfterEach
    void stop() {
        if (server != null) {
            server.stop(0);
        }
    }

    private String startServer(int status, String body) throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/thing", exchange -> {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    @Test
    void parsesAJsonBody() throws IOException {
        String base = startServer(200, "{\"sku\":\"INV-AMA-01\",\"totalAvailable\":7}");
        BackendClient client = new BackendClient(Duration.ofSeconds(2)) { };
        JsonNode node = client.getJson(base + "/thing");
        assertEquals("INV-AMA-01", node.path("sku").asText());
        assertEquals(7, node.path("totalAvailable").asInt());
    }

    @Test
    void a404BecomesANotFoundBackendException() throws IOException {
        String base = startServer(404, "{}");
        BackendClient client = new BackendClient(Duration.ofSeconds(2)) { };
        BackendException e = assertThrows(BackendException.class, () -> client.getJson(base + "/thing"));
        assertTrue(e.isNotFound());
    }

    @Test
    void aConnectionRefusedIsABackendExceptionNotAnUncaughtOne() {
        // Nothing listening on this port -- proves a downed backend surfaces
        // as BackendException, not a raw IOException a servlet would 500 on.
        BackendClient client = new BackendClient(Duration.ofMillis(500)) { };
        assertThrows(BackendException.class, () -> client.getJson("http://127.0.0.1:1/thing"));
    }
}
