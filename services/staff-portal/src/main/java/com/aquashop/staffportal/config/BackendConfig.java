package com.aquashop.staffportal.config;

/**
 * Backend base URLs and the upstream timeout, all from the environment -- the
 * ConfigMap in platform-repo/dev/staff-portal/deployment.yaml sets these.
 *
 * <p>2000ms matches storefront's own upstream-call discipline
 * (CATALOG_TIMEOUT_MS in services/storefront/src/catalog-client.ts): a
 * back-office page without a bound inherits the slowest backend's latency.
 */
public final class BackendConfig {

    public final String catalogBaseUrl;
    public final String inventoryBaseUrl;
    public final String orderBaseUrl;
    public final int timeoutMs;

    private BackendConfig(String catalogBaseUrl, String inventoryBaseUrl, String orderBaseUrl, int timeoutMs) {
        this.catalogBaseUrl = catalogBaseUrl;
        this.inventoryBaseUrl = inventoryBaseUrl;
        this.orderBaseUrl = orderBaseUrl;
        this.timeoutMs = timeoutMs;
    }

    public static BackendConfig fromEnv() {
        return new BackendConfig(
                env("CATALOG_BASE_URL", "http://catalog-service:8080"),
                env("INVENTORY_BASE_URL", "http://inventory-service:8081"),
                env("ORDER_BASE_URL", "http://order-service:8082"),
                Integer.parseInt(env("BACKEND_TIMEOUT_MS", "2000")));
    }

    private static String env(String name, String fallback) {
        String v = System.getenv(name);
        return (v == null || v.isBlank()) ? fallback : v;
    }
}
