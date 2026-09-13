package com.aquashop.order.repo;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.domain.OrderState;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OrderRepository extends JpaRepository<CustomerOrder, UUID> {

    Optional<CustomerOrder> findByReference(String reference);

    /**
     * Lines and reservations are fetched with the order: the saga touches both
     * on every step, and the API renders both, so lazy loading here is one
     * query per collection per order for data that is always needed.
     */
    @Query("""
           select distinct o from CustomerOrder o
           left join fetch o.lines
           where o.id = :id
           """)
    Optional<CustomerOrder> findWithLines(UUID id);

    List<CustomerOrder> findByEmailOrderByCreatedAtDesc(String email);

    /**
     * Orders that have become dispatchable and have not been noticed yet.
     * Matches the partial index exactly, so the watcher's scan stays cheap as
     * shipped orders accumulate.
     */
    @Query("""
           select o from CustomerOrder o
           where o.state = :state
             and o.dispatchAt <= :now
             and o.dispatchableSeenAt is null
           order by o.dispatchAt
           """)
    List<CustomerOrder> findNewlyDispatchable(OrderState state, Instant now);
}
