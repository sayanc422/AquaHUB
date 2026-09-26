package com.aquashop.catalog.repo;

/**
 * One row of {@link CategoryRepository#everyNode()}: a tile's worth of data
 * plus where it hangs. {@code parentSlug} is null for the four roots.
 */
public interface CategoryTreeRow extends CategoryNode {
    String getParentSlug();
}
