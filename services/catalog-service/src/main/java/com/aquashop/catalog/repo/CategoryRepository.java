package com.aquashop.catalog.repo;

import com.aquashop.catalog.domain.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CategoryRepository extends JpaRepository<Category, Long> {

    Optional<Category> findBySlug(String slug);

    /**
     * The node's own row with its parent fetched, so a breadcrumb or a "back"
     * link does not trip over a lazy proxy outside the session.
     */
    @Query("select c from Category c left join fetch c.parent where c.slug = :slug")
    Optional<Category> findWithParent(String slug);

    /**
     * The tiles directly under a category — or the top of the shop when
     * {@code parentSlug} is null.
     *
     * <p>Native, because the descendant count is a recursive CTE and JPQL has
     * no recursion. The alternative is loading the subtree into Java on every
     * page render to count it.
     *
     * <p>The `sub` term builds every (ancestor, descendant) pair once; at this
     * catalogue's size that is cheaper than one query per tile, and it stays
     * correct however deep the tree grows.
     */
    @Query(value = """
        WITH RECURSIVE sub AS (
            SELECT id AS root_id, id FROM category
            UNION ALL
            SELECT s.root_id, c.id FROM category c JOIN sub s ON c.parent_id = s.id
        )
        SELECT c.slug          AS slug,
               c.name          AS name,
               c.teaser        AS teaser,
               c.description   AS description,
               c.status        AS status,
               c.image_key     AS imageKey,
               (SELECT count(*) FROM category k WHERE k.parent_id = c.id)        AS childCount,
               (SELECT count(*) FROM product p WHERE p.category_id = c.id)       AS productCount,
               (SELECT count(*) FROM product p JOIN sub s ON s.id = p.category_id
                 WHERE s.root_id = c.id)                                         AS totalProducts
          FROM category c
         WHERE (:parentSlug IS NULL AND c.parent_id IS NULL)
            OR c.parent_id = (SELECT id FROM category WHERE slug = :parentSlug)
         ORDER BY c.sort_order, c.name
        """, nativeQuery = true)
    List<CategoryNode> childrenOf(@Param("parentSlug") String parentSlug);

    /**
     * Every category, with the same counts as {@link #childrenOf}, plus the
     * parent's slug so the caller can assemble the tree.
     *
     * <p>This is what the storefront's sidebar draws from. One query for the
     * whole tree, rather than the storefront walking it one
     * {@code /categories/{slug}} call per node -- forty round trips to draw a
     * menu. Ordered so that siblings come out in display order; the grouping
     * into a tree happens in the controller.
     */
    @Query(value = """
        WITH RECURSIVE sub AS (
            SELECT id AS root_id, id FROM category
            UNION ALL
            SELECT s.root_id, c.id FROM category c JOIN sub s ON c.parent_id = s.id
        )
        SELECT c.slug          AS slug,
               c.name          AS name,
               c.teaser        AS teaser,
               c.description   AS description,
               c.status        AS status,
               c.image_key     AS imageKey,
               p.slug          AS parentSlug,
               (SELECT count(*) FROM category k WHERE k.parent_id = c.id)        AS childCount,
               (SELECT count(*) FROM product x WHERE x.category_id = c.id)       AS productCount,
               (SELECT count(*) FROM product x JOIN sub s ON s.id = x.category_id
                 WHERE s.root_id = c.id)                                         AS totalProducts
          FROM category c
          LEFT JOIN category p ON p.id = c.parent_id
         ORDER BY c.sort_order, c.name
        """, nativeQuery = true)
    List<CategoryTreeRow> everyNode();

    /**
     * Every category with its parent fetched, for walking ancestors in memory.
     *
     * <p>All forty rows come back in one persistence context, so every
     * {@code getParent()} resolves to an instance already in this list rather
     * than a proxy that would need a session later.
     */
    @Query("select c from Category c left join fetch c.parent")
    List<Category> findAllWithParent();

    /**
     * The trail from the shop front down to this category, excluding it.
     *
     * <p>Six levels deep, a customer without a breadcrumb has no way back and
     * no idea where they are. Walking parents in Java is one query per level;
     * this is one query.
     */
    @Query(value = """
        WITH RECURSIVE up AS (
            SELECT id, parent_id, slug, name, 0 AS depth
              FROM category WHERE slug = :slug
            UNION ALL
            SELECT c.id, c.parent_id, c.slug, c.name, up.depth + 1
              FROM category c JOIN up ON up.parent_id = c.id
        )
        SELECT slug AS slug, name AS name, '' AS teaser, '' AS description,
               'ACTIVE' AS status, NULL AS imageKey,
               0 AS childCount, 0 AS productCount, 0 AS totalProducts
          FROM up WHERE slug <> :slug
         ORDER BY depth DESC
        """, nativeQuery = true)
    List<CategoryNode> ancestorsOf(@Param("slug") String slug);

    /**
     * Every category id in this subtree, the node included.
     *
     * <p>Returned as ids rather than entities on purpose: the products are then
     * loaded by a JPQL query that can `join fetch` the category. A native query
     * returning `product.*` maps the entity with a lazy category proxy, and with
     * `open-in-view: false` that becomes a LazyInitializationException at
     * render time — which is exactly the defect that took down
     * `GET /api/products`.
     */
    @Query(value = """
        WITH RECURSIVE sub AS (
            SELECT id FROM category WHERE slug = :slug
            UNION ALL
            SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id
        )
        SELECT id FROM sub
        """, nativeQuery = true)
    List<Long> subtreeIds(@Param("slug") String slug);
}
