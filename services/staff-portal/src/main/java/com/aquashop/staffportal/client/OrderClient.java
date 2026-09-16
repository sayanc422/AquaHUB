package com.aquashop.staffportal.client;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Duration;

/**
 * Read-only, and lookup-only: OrderController exposes GET /v1/orders/{id},
 * GET /v1/orders/by-reference/{reference} and GET /v1/orders/{id}/events, but
 * no bulk list endpoint -- there is no "show me every order" query to call.
 * The order page is therefore search-by-reference-or-id, not a list, and the
 * README says so rather than implying a browse feature that isn't there.
 */
public class OrderClient extends BackendClient {

    private final String baseUrl;

    public OrderClient(String baseUrl, Duration timeout) {
        super(timeout);
        this.baseUrl = baseUrl;
    }

    public JsonNode byReference(String reference) {
        return getJson(baseUrl + "/v1/orders/by-reference/" + reference);
    }

    public JsonNode byId(String id) {
        return getJson(baseUrl + "/v1/orders/" + id);
    }

    public JsonNode events(String id) {
        return getJson(baseUrl + "/v1/orders/" + id + "/events");
    }

    public boolean ping() {
        return ping(baseUrl, "/actuator/health/readiness");
    }
}
