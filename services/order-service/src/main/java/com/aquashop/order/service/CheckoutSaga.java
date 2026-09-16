package com.aquashop.order.service;

import com.aquashop.order.client.InsufficientStockException;
import com.aquashop.order.client.InventoryUnavailableException;
import com.aquashop.order.client.ReservationExpiredException;
import com.aquashop.order.domain.Cart;
import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.domain.OrderLine;
import com.aquashop.order.domain.OrderState;
import com.aquashop.order.payment.PaymentDeclinedException;
import com.aquashop.order.payment.PaymentGateway;
import com.aquashop.order.payment.PaymentUnresolvedException;
import com.aquashop.order.repo.CartRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Checkout, as a saga.
 *
 * <p>Four steps across two services and a payment provider, with no distributed
 * transaction available:
 *
 * <pre>
 *   1. reserve    one hold per SKU in inventory-service    compensate: release
 *   2. authorise  take the money                           compensate: refund
 *   3. commit     turn every hold into a sale              compensate: refund
 *   4. confirm    fix the dispatch window                  --
 * </pre>
 *
 * <p><b>The ordering is the design.</b> Stock is held before the money is taken,
 * because a customer charged for a fish that was never available is a refund, an
 * apology and a support ticket, while a customer whose card is declined after a
 * hold is a released hold and nothing else. The reverse order is simpler to
 * write and puts the cost of every failure on the customer.
 *
 * <p><b>Every compensation is safe to repeat.</b> Release is a no-op on a hold
 * that has already gone; refund is idempotent on the payment reference. A
 * compensation that fails because the work was already undone leaves the order
 * in exactly the state the compensation existed to prevent.
 *
 * <p>This class is not {@code @Transactional} and must not become so. A database
 * transaction spanning four calls to two other services would hold a Postgres
 * connection open for the duration of the slowest of them, and could not roll
 * back their work anyway — which is the whole reason this is a saga. Each step
 * commits on its own, so the order's state on disk is always one the recovery
 * logic can read.
 *
 * <h2>What this does not do</h2>
 *
 * <p>The saga runs inside one request. If this process dies between step 2 and
 * step 3, the money has been taken, the holds are still held, and nothing
 * resumes: the holds expire by themselves — which returns the stock — but the
 * refund never happens, and only the {@code order_event} trail would show it.
 * A durable saga log with a recovery scan is the fix, and it is Phase 6 work,
 * once NATS is in place to carry the retries. Saying so is better than implying
 * a crash-proof orchestrator.
 */
@Service
public class CheckoutSaga {

    private static final Logger log = LoggerFactory.getLogger(CheckoutSaga.class);

    private final CartRepository carts;
    private final OrderSteps steps;
    private final PaymentGateway payments;
    private final int holdTtlSeconds;
    private final String currency;

    public CheckoutSaga(CartRepository carts, OrderSteps steps, PaymentGateway payments,
                        @Value("${orders.hold-ttl-seconds:900}") int holdTtlSeconds,
                        @Value("${orders.currency:INR}") String currency) {
        this.carts = carts;
        this.steps = steps;
        this.payments = payments;
        this.holdTtlSeconds = holdTtlSeconds;
        this.currency = currency;
    }

    public CustomerOrder checkout(UUID cartId, String email) {
        Cart cart = carts.findWithLines(cartId)
                .orElseThrow(() -> new IllegalArgumentException("no such cart"));
        if (cart.getLines().isEmpty()) {
            throw new IllegalArgumentException("cannot check out an empty cart");
        }

        CustomerOrder order = steps.createOrder(cart, email, currency);
        UUID orderId = order.getId();
        log.info("checkout started order={} lines={} total={}",
                order.getReference(), order.getLines().size(), order.getTotalMinor());

        // ---- step 1: hold the stock --------------------------------------
        //
        // One transaction per line, not one for all of them. A rollback across
        // the whole loop would erase the rows recording holds that already
        // exist in inventory-service, and the compensation would then have
        // nothing to release. See OrderSteps.reserveOneLine.
        int held = 0;
        try {
            for (OrderLine line : order.getLines()) {
                steps.reserveOneLine(orderId, line.getSku(), line.getQuantity(), holdTtlSeconds);
                held++;
            }
        } catch (InsufficientStockException e) {
            // Nothing has been charged. Release whatever this attempt took
            // before it reached the line that failed.
            steps.releaseAll(orderId, "stock unavailable for " + e.getSku());
            steps.fail(orderId, OrderState.STOCK_UNAVAILABLE, e.getMessage());
            return steps.load(orderId);
        } catch (InventoryUnavailableException e) {
            steps.releaseAll(orderId, "inventory unavailable");
            steps.fail(orderId, OrderState.STOCK_UNAVAILABLE, "inventory unavailable: " + e.getMessage());
            return steps.load(orderId);
        }
        steps.advance(orderId, OrderState.STOCK_RESERVED,
                held + " hold(s), ttl " + holdTtlSeconds + "s");

        // ---- step 2: take the money --------------------------------------
        //
        // Three answers, not two. "Unknown" is the one that decides whether
        // this system loses money.
        String paymentKey = paymentKey(order);
        String paymentRef;
        try {
            paymentRef = payments.authorise(paymentKey, order.getReference(), order.getTotalMinor(),
                    order.getCurrency(), order.getEmail());
        } catch (PaymentDeclinedException e) {
            // Declined is a fact: no money moved. The fish go back on sale now,
            // rather than in fifteen minutes when the holds would have expired.
            steps.releaseAll(orderId, "payment declined");
            steps.fail(orderId, OrderState.PAYMENT_FAILED, e.getMessage());
            return steps.load(orderId);
        } catch (PaymentUnresolvedException e) {
            // The provider did not answer. The money may or may not have been
            // taken, so neither compensation is safe:
            //
            //   * releasing the holds and calling it a failure would sell the
            //     stock to somebody else while this customer's money is gone;
            //   * confirming would promise an order that may never be paid for.
            //
            // So: record what is true and ask again later. The holds are
            // deliberately left alone -- they expire on their own, which
            // returns the stock without anybody having decided that the
            // payment failed.
            log.warn("payment unresolved order={} key={} reason={}",
                    order.getReference(), paymentKey, e.getMessage());
            steps.markUnresolved(orderId, paymentKey, e.getMessage());
            return steps.load(orderId);
        }
        steps.recordPayment(orderId, paymentRef, paymentKey);

        // ---- step 3: the stock is ours -----------------------------------
        try {
            steps.commitEveryReservation(orderId);
        } catch (ReservationExpiredException | InventoryUnavailableException e) {
            // Money taken, stock not secured. The only honest outcome is to
            // give it back.
            log.warn("commit failed after payment order={} reason={}",
                    order.getReference(), e.getMessage());
            payments.refund(paymentRef, order.getTotalMinor(), "stock could not be committed");
            steps.releaseAll(orderId, "commit failed after payment");
            steps.fail(orderId, OrderState.REFUNDED, "refunded: " + e.getMessage());
            return steps.load(orderId);
        }

        // ---- step 4: when does it ship -----------------------------------
        steps.confirm(orderId);
        return steps.load(orderId);
    }

    /**
     * Finish a checkout whose payment was unknown at the time and has since
     * been resolved as captured.
     *
     * <p>Steps 3 and 4 of the same saga, reached from the reconciler rather
     * than from the request. The holds have very likely expired by now -- that
     * is the ordinary case here, not an exception -- and the refund branch that
     * already existed handles it, which is why this needed no new failure path.
     */
    public CustomerOrder resumeAfterPayment(UUID orderId, String paymentRef) {
        steps.recordPayment(orderId, paymentRef, null);
        return finishCheckout(orderId, paymentRef);
    }

    /**
     * Steps 3 and 4 for an order whose money is already taken and recorded.
     *
     * <p>Separate from {@link #resumeAfterPayment} because there are two ways to
     * arrive here and only one of them still needs the payment written down.
     * The reconciler resolves an unknown payment and must then record it;
     * {@link SagaRecovery} finds an order that is <em>already</em> {@code PAID}
     * and must not try to record it again -- the state machine would refuse that
     * transition, correctly, and the recovery would look like a bug.
     *
     * <p>Safe to run twice: committing a reservation that is already committed
     * is a no-op in inventory-service, and an order past {@code PAID} is
     * filtered out before it reaches here.
     */
    public CustomerOrder finishCheckout(UUID orderId, String paymentRef) {
        CustomerOrder order = steps.load(orderId);
        try {
            steps.commitEveryReservation(orderId);
        } catch (ReservationExpiredException | InventoryUnavailableException e) {
            log.warn("commit failed after a resolved payment order={} reason={}",
                    order.getReference(), e.getMessage());
            payments.refund(paymentRef, order.getTotalMinor(), "stock could not be committed");
            steps.releaseAll(orderId, "commit failed after a resolved payment");
            steps.fail(orderId, OrderState.REFUNDED, "refunded: " + e.getMessage());
            return steps.load(orderId);
        }
        steps.confirm(orderId);
        return steps.load(orderId);
    }

    /**
     * The key this order pays with.
     *
     * <p>Derived from the order, never random, for the same reason as the
     * reservation keys: a retry must present the same key or it charges twice.
     * It is also the handle by which an unresolved payment is looked up later,
     * so it is written to the order rather than recomputed -- a derivation rule
     * that changes would leave old orders unresolvable.
     */
    static String paymentKey(CustomerOrder order) {
        return "order-" + order.getId();
    }
}
