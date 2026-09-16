package com.aquashop.staffportal.servlet;

import com.aquashop.staffportal.client.CatalogClient;
import com.aquashop.staffportal.client.InventoryClient;
import com.aquashop.staffportal.client.OrderClient;
import com.aquashop.staffportal.config.AppInit;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * Readiness pings all three backends with a short, fixed bound. A staff-portal
 * pod that can't reach any of its backends can't render a single page, so it
 * should leave the Service endpoints rather than serve a wall of errors.
 */
@WebServlet("/readyz")
public class ReadyServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        CatalogClient catalog = (CatalogClient) getServletContext().getAttribute(AppInit.CATALOG);
        InventoryClient inventory = (InventoryClient) getServletContext().getAttribute(AppInit.INVENTORY);
        OrderClient order = (OrderClient) getServletContext().getAttribute(AppInit.ORDER);

        boolean catalogUp = catalog.ping();
        boolean inventoryUp = inventory.ping();
        boolean orderUp = order.ping();
        boolean ready = catalogUp && inventoryUp && orderUp;

        resp.setContentType("application/json");
        resp.setStatus(ready ? HttpServletResponse.SC_OK : HttpServletResponse.SC_SERVICE_UNAVAILABLE);
        resp.getWriter().write(String.format(
                "{\"status\":\"%s\",\"catalog\":%s,\"inventory\":%s,\"order\":%s}",
                ready ? "ready" : "unready", catalogUp, inventoryUp, orderUp));
    }
}
