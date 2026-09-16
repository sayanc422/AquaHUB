package com.aquashop.staffportal.servlet;

import com.aquashop.staffportal.client.BackendException;
import com.aquashop.staffportal.client.OrderClient;
import com.aquashop.staffportal.config.AppInit;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * Lookup, not a list: order-service has no bulk endpoint (confirmed against
 * OrderController -- get-by-id, get-by-reference, events, checkout, nothing
 * else). A staff member finds an order by the reference a customer gives
 * them, or by id.
 */
@WebServlet("/orders")
public class OrderLookupServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        OrderClient orders = (OrderClient) getServletContext().getAttribute(AppInit.ORDER);
        String reference = req.getParameter("reference");
        String id = req.getParameter("id");

        if ((reference == null || reference.isBlank()) && (id == null || id.isBlank())) {
            req.getRequestDispatcher("/jsp/order.jsp").forward(req, resp);
            return;
        }

        try {
            JsonNode order = (id != null && !id.isBlank())
                    ? orders.byId(id.trim())
                    : orders.byReference(reference.trim());
            JsonNode events = orders.events(order.path("id").asText());
            req.setAttribute("order", order);
            req.setAttribute("events", events);
        } catch (BackendException e) {
            req.setAttribute("error", e.isNotFound() ? "No such order." : "order-service is unreachable: " + e.getMessage());
        }
        req.getRequestDispatcher("/jsp/order.jsp").forward(req, resp);
    }
}
