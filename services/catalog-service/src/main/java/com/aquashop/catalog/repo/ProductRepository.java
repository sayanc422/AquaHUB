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
}
