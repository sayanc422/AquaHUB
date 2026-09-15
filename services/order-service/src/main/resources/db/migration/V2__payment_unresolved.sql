-- An order can now be in a state that says "we do not know whether the customer
-- was charged".
--
-- This is not a nicety. Before it, an acquirer that took the money and did not
-- answer left only two choices: call it a failure and release the stock (while
-- the customer's money is gone), or call it a success and confirm an order that
-- may never have been paid for. Both are wrong, and the state that says so is
-- the only honest third option.
--
-- PAYMENT_UNRESOLVED deliberately does NOT release the holds. They expire on
-- their own within the TTL, which returns the stock without anyone deciding
-- that the payment failed.

ALTER TABLE customer_order DROP CONSTRAINT customer_order_state_check;

ALTER TABLE customer_order ADD CONSTRAINT customer_order_state_check
    CHECK (state IN (
        'PENDING', 'STOCK_RESERVED', 'PAYMENT_UNRESOLVED', 'PAID', 'CONFIRMED', 'SHIPPED',
        'STOCK_UNAVAILABLE', 'PAYMENT_FAILED', 'REFUNDED', 'CANCELLED'));

-- The key this order used to ask for payment. It is how an unresolved payment
-- is looked up again later, so it has to be written down rather than derived at
-- the point of need -- a derivation rule that changes leaves old orders
-- unresolvable.
ALTER TABLE customer_order ADD COLUMN payment_idempotency_key VARCHAR(128);

-- The reconciler scans exactly this set.
CREATE INDEX idx_order_payment_unresolved ON customer_order(updated_at)
    WHERE state = 'PAYMENT_UNRESOLVED';
