package com.aquashop.staffportal.client;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Duration;

/** Read-only: catalog-service exposes no write endpoint for staff to call. */
public class CatalogClient extends BackendClient {

    private final String baseUrl;

    public CatalogClient(String baseUrl, Duration timeout) {
        super(timeout);
        this.baseUrl = baseUrl;
    }

    /** Roots only -- same reason CatalogController.topLevel() gives: a menu, not a dump of the tree. */
    public JsonNode topLevelCategories() {
        return getJson(baseUrl + "/api/categories");
    }

    public JsonNode category(String slug) {
        return getJson(baseUrl + "/api/categories/" + slug);
    }

    public JsonNode product(String slug) {
        return getJson(baseUrl + "/api/products/" + slug);
    }

    public boolean ping() {
        return ping(baseUrl, "/actuator/health/readiness");
    }
}
