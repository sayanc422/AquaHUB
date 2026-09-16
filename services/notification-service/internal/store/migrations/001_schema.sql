-- notification-service owns this schema. No other service connects to this
-- database; the `notify` role holds CONNECT on `notify` only.
--
-- One row per (order, event, target) triple. order-service pushes an event
-- once, fire-and-forget, when it already knows something changed (see
-- docs/adr/0020-*.md); this table is the durable record of "we owe a
-- delivery attempt for this", and the unique constraint is what makes a
-- retried push from order-service harmless instead of a duplicate send.

CREATE TABLE outbox (
    id              UUID PRIMARY KEY,
    order_id        UUID         NOT NULL,
    order_reference VARCHAR(64)  NOT NULL,
    event_type      VARCHAR(32)  NOT NULL
                    CHECK (event_type IN ('ORDER_CONFIRMED', 'ORDER_DISPATCHABLE')),
    target_type     VARCHAR(16)  NOT NULL CHECK (target_type IN ('email', 'webhook')),
    target          VARCHAR(320) NOT NULL,
    status          VARCHAR(16)  NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'sent', 'failed')),
    -- Delivery attempts against the target, not ingest retries: an ingest
    -- call that never reaches this service leaves no row at all, and that is
    -- a stated, accepted gap -- see the README and ADR 0020.
    attempts        INT          NOT NULL DEFAULT 0,
    last_error      TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    sent_at         TIMESTAMPTZ,

    UNIQUE (order_id, event_type, target_type)
);

-- The sender's poll query filters on status alone; a partial index keeps it
-- small as sent/failed rows accumulate, the same shape as inventory-service's
-- idx_reservation_held.
CREATE INDEX idx_outbox_pending ON outbox(created_at) WHERE status = 'pending';
