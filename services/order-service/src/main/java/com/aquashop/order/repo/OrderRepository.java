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
     * Put an order back into an earlier state. **Tests only.**
     *
     * <p>Native and modifying, because the state machine forbids going
     * backwards -- which is correct, and is why simulating a crashed checkout
     * cannot go through the domain. The alternative is a back door in
     * production code, and then the tests would be exercising the back door.
     */
    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = """
           UPDATE customer_order
              SET state = :state, updated_at = now() - interval '1 hour',
                  dispatch_at = NULL, dispatchable_seen_at = NULL
            WHERE id = :orderId
           """, nativeQuery = true)
    void rewindForTest(UUID orderId, String state);

    /**
     * Put the holds back to HELD. **Tests only.**
     *
     * <p>Needed alongside {@link #rewindForTest}: a process that died before
     * committing left its reservations held, and an order rewound without them
     * has nothing left to commit -- so the commit step would quietly succeed
     * and the refund path could never be reached.
     */
    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = "UPDATE order_reservation SET state = 'HELD' WHERE order_id = :orderId",
           nativeQuery = true)
    void rewindReservationsForTest(UUID orderId);

    /**
     * Orders that stopped in the middle of a checkout.
     *
     * <p>{@code updatedAt} rather than {@code createdAt}: what matters is how
     * long the order has sat at this step, not how long ago somebody started
     * shopping. A saga that is merely slow must not be picked up from
     * underneath the request still running it.
     */
    @Query("""
           select o from CustomerOrder o
           where o.state = :state and o.updatedAt < :stuckSince
           order by o.updatedAt
           """)
    List<CustomerOrder> findStuckIn(OrderState state, java.time.Instant stuckSince);

    /** Orders whose payment outcome is still unknown. Matches the partial index. */
    @Query("select o from CustomerOrder o where o.state = :state order by o.updatedAt")
    List<CustomerOrder> findUnresolvedPayments(OrderState state);

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
