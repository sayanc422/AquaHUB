-- inventory-service owns this schema. No other service connects to this
-- database; the `inventory` role holds CONNECT on `inventory` only.
--
-- The two invariants this schema enforces, so that no application bug can
-- violate them:
--   * stock never goes negative              -> CHECK (quantity_on_hand >= 0)
--   * one idempotency key, one reservation   -> UNIQUE (idempotency_key)

CREATE TABLE tank (
    id               BIGSERIAL PRIMARY KEY,
    code             VARCHAR(32) NOT NULL UNIQUE,
    sku              VARCHAR(32) NOT NULL,
    quantity_on_hand INT         NOT NULL CHECK (quantity_on_hand >= 0),
    -- A tank under treatment still physically holds fish, so it is not empty,
    -- but nothing in it may be sold. Deleting the row would lose the count.
    status           VARCHAR(16) NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open', 'quarantine')),
    note             TEXT
);

CREATE INDEX idx_tank_sku_open ON tank(sku) WHERE status = 'open';

CREATE TABLE reservation (
    id              UUID PRIMARY KEY,
    -- The client's retry key. UNIQUE is the whole idempotency mechanism: two
    -- concurrent retries race to INSERT and exactly one wins, decided by
    -- Postgres rather than by a read-then-write in application code.
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    -- SHA-256 of the canonical request body. Same key, different body means the
    -- caller reused a key for a different intent: that is a 409, not a replay.
    request_digest  CHAR(64)     NOT NULL,
    order_ref       VARCHAR(64)  NOT NULL,
    sku             VARCHAR(32)  NOT NULL,
    quantity        INT          NOT NULL CHECK (quantity > 0),
    state           VARCHAR(16)  NOT NULL
                    CHECK (state IN ('held', 'committed', 'released', 'expired')),
    -- Every hold is time-bounded. There is no such thing as an open-ended
    -- reservation here: a checkout that is abandoned must return its fish to
    -- stock without anyone being asked to clean up.
    expires_at      TIMESTAMPTZ  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Availability is read on every reservation. Only held rows can subtract from
-- it, so the index covers only those: a partial index stays small as committed
-- and released rows accumulate.
CREATE INDEX idx_reservation_held ON reservation(sku) WHERE state = 'held';
CREATE INDEX idx_reservation_expiry ON reservation(expires_at) WHERE state = 'held';
CREATE INDEX idx_reservation_order ON reservation(order_ref);

CREATE TABLE reservation_line (
    reservation_id UUID   NOT NULL REFERENCES reservation(id) ON DELETE CASCADE,
    tank_id        BIGINT NOT NULL REFERENCES tank(id),
    quantity       INT    NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (reservation_id, tank_id)
);

CREATE INDEX idx_reservation_line_tank ON reservation_line(tank_id);
