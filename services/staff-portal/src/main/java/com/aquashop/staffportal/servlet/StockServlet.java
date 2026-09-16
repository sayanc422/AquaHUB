package com.aquashop.staffportal.servlet;

import com.aquashop.staffportal.client.BackendException;
import com.aquashop.staffportal.client.InventoryClient;
import com.aquashop.staffportal.config.AppInit;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/** Stock levels per SKU, tank by tank -- read-only, see README for why there's no adjustment form here. */
@WebServlet("/stock")
public class StockServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        InventoryClient inventory = (InventoryClient) getServletContext().getAttribute(AppInit.INVENTORY);
        String sku = req.getParameter("sku");

        if (sku != null && !sku.isBlank()) {
            try {
                JsonNode stock = inventory.stock(sku.trim());
                req.setAttribute("stock", stock);
            } catch (BackendException e) {
                req.setAttribute("error", e.isNotFound()
                        ? "No tank holds SKU " + sku + "."
                        : "inventory-service is unreachable: " + e.getMessage());
            }
        }
        req.getRequestDispatcher("/jsp/stock.jsp").forward(req, resp);
    }
}
