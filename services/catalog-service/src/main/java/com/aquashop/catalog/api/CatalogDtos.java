package com.aquashop.catalog.api;

import com.aquashop.catalog.domain.Category;
import com.aquashop.catalog.domain.Product;
import com.aquashop.catalog.domain.SpeciesProfile;

import java.math.BigDecimal;

/**
 * Wire contract. Deliberately separate from the entities: the database schema
 * is an implementation detail of this service, and the JSON is a published
 * contract other services depend on. Leaking entities makes every column
 * rename a breaking API change.
 */
public final class CatalogDtos {

    private CatalogDtos() { }

    public record CategoryView(String slug, String name, String description) {
        public static CategoryView of(Category c) {
            return new CategoryView(c.getSlug(), c.getName(), c.getDescription());
        }
    }

    public record ProductSummary(
            String sku, String slug, String name, String summary,
            BigDecimal price, String currency, boolean livestock, String categorySlug) {

        public static ProductSummary of(Product p) {
            return new ProductSummary(
                    p.getSku(), p.getSlug(), p.getName(), p.getSummary(),
                    p.getPriceMajor(), p.getCurrency(), p.isLivestock(),
                    p.getCategory().getSlug());
        }
    }

    public record Range(double min, double max) { }

    public record SpeciesView(
            String scientificName, String commonName,
            double maxSizeCm, int minTankLitres, int minGroupSize,
            Range temperatureC, Range ph, Range dgh,
            String temperament, String careLevel, String diet,
            boolean plantSafe, String careNotes) {

        public static SpeciesView of(SpeciesProfile s) {
            return new SpeciesView(
                    s.getScientificName(), s.getCommonName(),
                    s.getMaxSizeCm(), s.getMinTankLitres(), s.getMinGroupSize(),
                    new Range(s.getTempMinC(), s.getTempMaxC()),
                    new Range(s.getPhMin(), s.getPhMax()),
                    new Range(s.getDghMin(), s.getDghMax()),
                    s.getTemperament().name(), s.getCareLevel().name(),
                    s.getDiet(), s.isPlantSafe(), s.getCareNotes());
        }
    }

    public record ProductDetail(ProductSummary product, SpeciesView species) { }
}
