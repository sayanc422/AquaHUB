package com.aquashop.catalog.api;

import com.fasterxml.jackson.annotation.JsonUnwrapped;
import com.aquashop.catalog.domain.Category;
import com.aquashop.catalog.domain.CategoryStatus;
import com.aquashop.catalog.repo.CategoryNode;
import com.aquashop.catalog.domain.Product;
import com.aquashop.catalog.domain.SpeciesProfile;

import java.math.BigDecimal;
import java.util.List;

/**
 * Wire contract. Deliberately separate from the entities: the database schema
 * is an implementation detail of this service, and the JSON is a published
 * contract other services depend on. Leaking entities makes every column
 * rename a breaking API change.
 */
public final class CatalogDtos {

    private CatalogDtos() { }

    /**
     * A category as a navigation tile.
     *
     * <p>`totalProducts` counts the whole subtree, not just this level. A
     * "Cichlids" tile holds no products of its own and six fish below it, and
     * a count of 0 on that tile would be true and useless.
     *
     * <p>`browsable` is derived from the status rather than being the status,
     * so the storefront does not have to know which values are enterable. A
     * client that has to maintain its own list of "statuses that mean yes"
     * goes out of date the first time one is added.
     */
    public record CategoryView(
            String slug, String name, String teaser, String description,
            String status, boolean browsable, String imageKey,
            long childCount, long productCount, long totalProducts) {

        public static CategoryView of(CategoryNode n) {
            CategoryStatus status = CategoryStatus.valueOf(n.getStatus());
            return new CategoryView(
                    n.getSlug(), n.getName(), n.getTeaser(), n.getDescription(),
                    status.name(), status.isBrowsable(), n.getImageKey(),
                    n.getChildCount(), n.getProductCount(), n.getTotalProducts());
        }

        /** The thin form used for a breadcrumb, where only the label matters. */
        public static CategoryView crumb(CategoryNode n) {
            return new CategoryView(n.getSlug(), n.getName(), null, null,
                    "ACTIVE", true, null, 0, 0, 0);
        }

        public static CategoryView of(Category c) {
            return new CategoryView(c.getSlug(), c.getName(), c.getTeaser(), c.getDescription(),
                    c.getStatus().name(), c.getStatus().isBrowsable(), c.getImageKey(), 0, 0, 0);
        }
    }

    /**
     * The whole category tree, for a navigation sidebar.
     *
     * <p>Unwrapped, so each node is a {@link CategoryView} with a
     * {@code children} array beside its own fields rather than nested inside a
     * {@code category} key. A client reads a node exactly as it reads a tile.
     */
    public record CategoryTreeNode(
            @JsonUnwrapped CategoryView category,
            List<CategoryTreeNode> children) { }

    /**
     * Everything one category page needs, in one response.
     *
     * <p>Assembled here rather than left to the caller to stitch from three
     * endpoints: the storefront renders breadcrumb, subsections and products
     * together, and three round trips to draw one page is how a BFF ends up
     * slower than the service behind it.
     */
    public record CategoryPage(
            CategoryView category,
            List<CategoryView> breadcrumb,
            List<CategoryView> children,
            List<ProductSummary> products) { }

    public record ProductSummary(
            String sku, String slug, String name, String summary,
            BigDecimal price, String currency, boolean livestock,
            String categorySlug, String imageKey) {

        public static ProductSummary of(Product p) {
            return new ProductSummary(
                    p.getSku(), p.getSlug(), p.getName(), p.getSummary(),
                    p.getPriceMajor(), p.getCurrency(), p.isLivestock(),
                    p.getCategory().getSlug(), p.getImageKey());
        }
    }

    /**
     * The wire keeps plain numbers. The entity holds BigDecimal because the
     * column is NUMERIC and the advisor compares these for range overlap;
     * converting here, at the edge, keeps that decision out of the published
     * contract.
     */
    public record Range(double min, double max) {
        static Range of(BigDecimal min, BigDecimal max) {
            return new Range(min.doubleValue(), max.doubleValue());
        }
    }

    public record SpeciesView(
            String scientificName, String commonName,
            double maxSizeCm, int minTankLitres, int minGroupSize,
            Range temperatureC, Range ph, Range dgh,
            String temperament, String careLevel, String diet,
            boolean plantSafe, String animalGroup, String careNotes, String description) {

        public static SpeciesView of(SpeciesProfile s) {
            return new SpeciesView(
                    s.getScientificName(), s.getCommonName(),
                    s.getMaxSizeCm().doubleValue(), s.getMinTankLitres(), s.getMinGroupSize(),
                    Range.of(s.getTempMinC(), s.getTempMaxC()),
                    Range.of(s.getPhMin(), s.getPhMax()),
                    Range.of(s.getDghMin(), s.getDghMax()),
                    s.getTemperament().name(), s.getCareLevel().name(),
                    s.getDiet(), s.isPlantSafe(), s.getAnimalGroup().name(),
                    s.getCareNotes(), s.getDescription());
        }
    }

    public record ProductDetail(ProductSummary product, SpeciesView species) { }
}
