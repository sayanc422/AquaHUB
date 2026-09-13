package com.aquashop.order.repo;

import com.aquashop.order.domain.Cart;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;
import java.util.UUID;

public interface CartRepository extends JpaRepository<Cart, UUID> {

    @Query("select distinct c from Cart c left join fetch c.lines where c.id = :id")
    Optional<Cart> findWithLines(UUID id);
}
