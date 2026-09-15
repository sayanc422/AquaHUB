package com.aquashop.catalog.repo;

import com.aquashop.catalog.domain.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface ProductRepository extends JpaRepository<Product, Long> {

    // join fetch, not lazy loading: the list view renders the category name for
    // every row, and without this it is one query per product (N+1).
    @Query("""
           select p from Product p
             join fetch p.category c
            where c.slug = :categorySlug
            order by p.name
           """)
    List<Product> findByCategorySlug(String categorySlug);

    @Query("""
           select p from Product p
             join fetch p.category
             left join fetch p.speciesProfile
            where p.slug = :slug
           """)
    Optional<Product> findDetailBySlug(String slug);

    @Query("""
           select p from Product p
             join fetch p.category
            where lower(p.name) like lower(concat('%', :q, '%'))
            order by p.name
           """)
    List<Product> search(String q);

    /**
     * The whole catalog, with categories fetched.
     *
     * <p>This exists because the inherited {@code findAll()} does not fetch the
     * category, and with {@code open-in-view: false} there is no session left
     * by the time the DTO asks for the category name -- so the unfiltered
     * product list threw {@code LazyInitializationException} and returned 500.
     * Every other query here join-fetches; the one method nobody wrote was the
     * one that was wrong.
     */
    @Query("""
           select p from Product p
             join fetch p.category
            order by p.name
           """)
    List<Product> findAllWithCategory();

    /**
     * Products anywhere in a subtree.
     *
     * <p>The ids come from a recursive query in CategoryRepository; this half
     * stays JPQL so it can `join fetch` the category. Splitting it in two is
     * what keeps the category off the lazy path.
     */
    @Query("""
           select p from Product p
             join fetch p.category c
            where c.id in :categoryIds
            order by p.name
           """)
    List<Product> findInCategories(java.util.Collection<Long> categoryIds);
}
