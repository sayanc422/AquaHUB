package com.aquashop.staffportal.client;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Duration;

/**
 * Read-only. inventory-service has no restock/admin write endpoint -- only
 * reservation lifecycle (POST /v1/reservations, .../commit, .../release) and
 * GET /v1/stock/{sku}. Staff cannot adjust stock through this portal; there
 * is nothing on the other end to call. See the README's known-gaps section.
 */
public class InventoryClient extends BackendClient {

    private final String baseUrl;

    public InventoryClient(String baseUrl, Duration timeout) {
        super(timeout);
        this.baseUrl = baseUrl;
    }

    /** {sku, totalAvailable, tanks:[{tank, status, onHand, held, available, note}]}. */
    public JsonNode stock(String sku) {
        return getJson(baseUrl + "/v1/stock/" + sku);
    }

    public boolean ping() {
        return ping(baseUrl, "/readyz");
    }
}
