package com.aquashop.catalog.repo;

/**
 * A category as a grid tile needs it: itself, plus what is behind it.
 *
 * <p>A projection rather than the entity, because the counts are the reason
 * the query exists. A tile that cannot say "6 fish in stock" is a link into
 * the dark, and computing those counts by loading children and walking them in
 * Java is one query per tile.
 */
public interface CategoryNode {
    String getSlug();
    String getName();
    String getTeaser();
    String getDescription();
    String getStatus();
    String getImageKey();

    /** Sections directly inside this one. */
    long getChildCount();

    /** Products filed directly here, not counting subsections. */
    long getProductCount();

    /**
     * Products anywhere beneath, including here.
     *
     * <p>This is the number a customer wants on a tile: "Cichlids" holds no
     * products of its own and 6 fish below it, and showing 0 would be true and
     * useless.
     */
    long getTotalProducts();
}
