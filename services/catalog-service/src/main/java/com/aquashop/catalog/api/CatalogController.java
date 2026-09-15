package com.aquashop.catalog.api;

import com.aquashop.catalog.domain.Category;
import com.aquashop.catalog.domain.Product;
import com.aquashop.catalog.repo.CategoryNode;
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

    /**
     * The top of the shop: Live Fishes, Live Plants, Aquarium Supplies.
     *
     * <p>Roots only, not every category. This is what a navigation bar wants,
     * and returning all twenty-nine would make the caller filter — which means
     * the caller has to understand the tree to draw a menu.
     */
    @GetMapping("/categories")
    public List<CatalogDtos.CategoryView> topLevel() {
        return categories.childrenOf(null).stream().map(CatalogDtos.CategoryView::of).toList();
    }

    /**
     * One category page: where you are, how you got here, what is inside, and
     * what is for sale at this level.
     */
    @GetMapping("/categories/{slug}")
    public CatalogDtos.CategoryPage category(@PathVariable String slug) {
        Category self = categories.findWithParent(slug)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "unknown category"));

        List<CategoryNode> children = categories.childrenOf(slug);
        List<CategoryNode> ancestors = categories.ancestorsOf(slug);

        return new CatalogDtos.CategoryPage(
                CatalogDtos.CategoryView.of(self),
                ancestors.stream().map(CatalogDtos.CategoryView::crumb).toList(),
                children.stream().map(CatalogDtos.CategoryView::of).toList(),
                products.findByCategorySlug(slug).stream().map(CatalogDtos.ProductSummary::of).toList());
    }

    /**
     * Products in a category.
     *
     * @param deep when true, everything in the subtree rather than only what is
     *             filed at this level. Six levels of tree is five correct
     *             guesses before a customer sees a fish, so every level offers
     *             "browse all" — and this is the query behind it.
     */
    @GetMapping("/categories/{slug}/products")
    public List<CatalogDtos.ProductSummary> byCategory(
            @PathVariable String slug,
            @RequestParam(name = "deep", defaultValue = "false") boolean deep) {

        categories.findBySlug(slug)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "unknown category"));

        List<Product> found;
        if (deep) {
            List<Long> ids = categories.subtreeIds(slug);
            found = ids.isEmpty() ? List.of() : products.findInCategories(ids);
        } else {
            found = products.findByCategorySlug(slug);
        }
        return found.stream().map(CatalogDtos.ProductSummary::of).toList();
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
