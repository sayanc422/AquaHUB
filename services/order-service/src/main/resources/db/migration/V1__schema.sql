-- order-service owns this schema. No other service connects to this database,
-- and nothing here references a catalog or inventory table: the SKU is a
-- string, and the reservation id is a UUID this service was handed by
-- inventory-service. A foreign key across a service boundary would make the
-- boundary a lie.

CREATE TABLE cart (
    id         UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cart_line (
    cart_id          UUID        NOT NULL REFERENCES cart(id) ON DELETE CASCADE,
    sku              VARCHAR(32) NOT NULL,
    name             VARCHAR(160) NOT NULL,
    quantity         INT         NOT NULL CHECK (quantity > 0),
    -- Price is captured into the cart, not read from the catalog at checkout.
    -- A price that changes between "add to basket" and "pay" is a support
    -- ticket; the catalog remains the owner of the price, this is the quote.
    unit_price_minor BIGINT      NOT NULL CHECK (unit_price_minor >= 0),
    is_livestock     BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (cart_id, sku)
);

CREATE TABLE customer_order (
    id              UUID PRIMARY KEY,
    reference       VARCHAR(24)  NOT NULL UNIQUE,
    state           VARCHAR(24)  NOT NULL CHECK (state IN (
                        'PENDING', 'STOCK_RESERVED', 'PAID', 'CONFIRMED', 'SHIPPED',
                        'STOCK_UNAVAILABLE', 'PAYMENT_FAILED', 'REFUNDED', 'CANCELLED')),
    email           VARCHAR(190) NOT NULL,
    currency        VARCHAR(3)   NOT NULL,
    total_minor     BIGINT       NOT NULL CHECK (total_minor >= 0),
    -- Whether the order contains anything alive. It decides the dispatch
    -- calendar, and it is captured at checkout rather than re-derived, because
    -- the answer must not change if the catalog reclassifies a product later.
    has_livestock   BOOLEAN      NOT NULL,
    payment_ref     VARCHAR(64),
    -- When this order may physically leave the building. Set at confirmation
    -- and never recomputed. Whether the order is *shippable* is not a state:
    -- it is `now() >= dispatch_at`, which is the same lesson as
    -- inventory-service's hold expiry -- see ADR 0008 and ADR 0011.
    dispatch_at     TIMESTAMPTZ,
    -- Set once, when a waiting order first becomes dispatchable. It records an
    -- observation for the notification service; nothing reads it to decide
    -- whether the order may ship.
    dispatchable_seen_at TIMESTAMPTZ,
    failure_reason  VARCHAR(200),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- A confirmed order that cannot say when it ships is a data defect.
    CONSTRAINT confirmed_has_dispatch_at
        CHECK (state NOT IN ('CONFIRMED', 'SHIPPED') OR dispatch_at IS NOT NULL),
    -- Money must not have been taken without a reference to the payment.
    CONSTRAINT paid_has_payment_ref
        CHECK (state NOT IN ('PAID', 'CONFIRMED', 'SHIPPED', 'REFUNDED') OR payment_ref IS NOT NULL)
);

CREATE INDEX idx_order_state ON customer_order(state);
CREATE INDEX idx_order_email ON customer_order(email);
-- The dispatch watcher scans exactly this set and nothing else.
CREATE INDEX idx_order_awaiting_dispatch ON customer_order(dispatch_at)
    WHERE state = 'CONFIRMED' AND dispatchable_seen_at IS NULL;

CREATE TABLE order_line (
    order_id         UUID        NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
    sku              VARCHAR(32) NOT NULL,
    name             VARCHAR(160) NOT NULL,
    quantity         INT         NOT NULL CHECK (quantity > 0),
    unit_price_minor BIGINT      NOT NULL CHECK (unit_price_minor >= 0),
    is_livestock     BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (order_id, sku)
);

-- One row per SKU per order, because inventory-service reserves per SKU. An
-- order for three species is three reservations, and a saga that fails on the
-- third must release the first two.
CREATE TABLE order_reservation (
    order_id       UUID        NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
    sku            VARCHAR(32) NOT NULL,
    reservation_id UUID        NOT NULL,
    quantity       INT         NOT NULL CHECK (quantity > 0),
    state          VARCHAR(16) NOT NULL CHECK (state IN ('HELD', 'COMMITTED', 'RELEASED')),
    PRIMARY KEY (order_id, sku)
);

-- Every transition, in order. This is the audit trail a support question is
-- answered from, and the only place a compensation is visible after the fact:
-- a released hold leaves no trace on the order itself.
CREATE TABLE order_event (
    id         BIGSERIAL PRIMARY KEY,
    order_id   UUID        NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
    at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    from_state VARCHAR(24),
    to_state   VARCHAR(24) NOT NULL,
    detail     VARCHAR(500)
);

CREATE INDEX idx_order_event_order ON order_event(order_id, id);
