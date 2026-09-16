package com.aquashop.staffportal.config;

import com.aquashop.staffportal.client.CatalogClient;
import com.aquashop.staffportal.client.InventoryClient;
import com.aquashop.staffportal.client.OrderClient;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import java.time.Duration;

/** Builds the backend clients once at deploy time and hangs them on the ServletContext. */
@WebListener
public class AppInit implements ServletContextListener {

    public static final String CATALOG = "catalogClient";
    public static final String INVENTORY = "inventoryClient";
    public static final String ORDER = "orderClient";

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        BackendConfig cfg = BackendConfig.fromEnv();
        Duration timeout = Duration.ofMillis(cfg.timeoutMs);
        sce.getServletContext().setAttribute(CATALOG, new CatalogClient(cfg.catalogBaseUrl, timeout));
        sce.getServletContext().setAttribute(INVENTORY, new InventoryClient(cfg.inventoryBaseUrl, timeout));
        sce.getServletContext().setAttribute(ORDER, new OrderClient(cfg.orderBaseUrl, timeout));
    }
}
