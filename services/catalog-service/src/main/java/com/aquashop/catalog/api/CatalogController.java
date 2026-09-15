package com.aquashop.catalog.api;

import com.aquashop.catalog.domain.Product;
import com.aquashop.catalog.repo.CategoryRepository;
import com.aquashop.catalog.repo.ProductRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api")
public class CatalogController {

    private final ProductRepository products;
    private final CategoryRepository categories;

    public CatalogController(ProductRepository products, CategoryRepository categories) {
        this.products = products;
        this.categories = categories;
    }

    @GetMapping("/categories")
    public List<CatalogDtos.CategoryView> categories() {
        return categories.findAll().stream()
                .sorted((a, b) -> Integer.compare(a.getSortOrder(), b.getSortOrder()))
                .map(CatalogDtos.CategoryView::of)
                .toList();
    }

    @GetMapping("/categories/{slug}/products")
    public List<CatalogDtos.ProductSummary> byCategory(@PathVariable String slug) {
        categories.findBySlug(slug)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "unknown category"));
        return products.findByCategorySlug(slug).stream()
                .map(CatalogDtos.ProductSummary::of)
                .toList();
    }

    @GetMapping("/products/{slug}")
    public CatalogDtos.ProductDetail detail(@PathVariable String slug) {
        Product p = products.findDetailBySlug(slug)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "unknown product"));
        return new CatalogDtos.ProductDetail(
                CatalogDtos.ProductSummary.of(p),
                p.getSpeciesProfile() == null ? null : CatalogDtos.SpeciesView.of(p.getSpeciesProfile()));
    }

    @GetMapping("/products")
    public List<CatalogDtos.ProductSummary> search(@RequestParam(name = "q", defaultValue = "") String q) {
        // findAllWithCategory(), not the inherited findAll(): the latter leaves
        // the category to be lazy-loaded in the DTO, where there is no session.
        return (q.isBlank() ? products.findAllWithCategory() : products.search(q)).stream()
                .map(CatalogDtos.ProductSummary::of)
                .toList();
    }
}
