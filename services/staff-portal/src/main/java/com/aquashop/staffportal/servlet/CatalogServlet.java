package com.aquashop.staffportal.servlet;

import com.aquashop.staffportal.client.BackendException;
import com.aquashop.staffportal.client.CatalogClient;
import com.aquashop.staffportal.config.AppInit;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * Browse only. catalog-service exposes no write endpoint (confirmed --
 * grepped for @PostMapping/@PutMapping/@PatchMapping/@DeleteMapping in
 * CatalogController: none exist), so species content cannot be edited from
 * here despite architecture.md's actor description implying staff "manage"
 * it. See the README's known-gaps section.
 */
@WebServlet("/catalog")
public class CatalogServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        CatalogClient catalog = (CatalogClient) getServletContext().getAttribute(AppInit.CATALOG);
        String slug = req.getParameter("slug");
        String product = req.getParameter("product");

        try {
            if (product != null && !product.isBlank()) {
                req.setAttribute("product", catalog.product(product.trim()));
            } else if (slug != null && !slug.isBlank()) {
                req.setAttribute("category", catalog.category(slug.trim()));
            } else {
                req.setAttribute("roots", catalog.topLevelCategories());
            }
        } catch (BackendException e) {
            req.setAttribute("error", e.isNotFound() ? "Not found." : "catalog-service is unreachable: " + e.getMessage());
        }
        req.getRequestDispatcher("/jsp/catalog.jsp").forward(req, resp);
    }
}
