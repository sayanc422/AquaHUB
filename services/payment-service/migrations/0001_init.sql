-- payment-service owns this schema. No other service connects to this
-- database; the `payments` role holds CONNECT on `payments` only.
--
-- The rules the database enforces, so that no application bug can break them:
--   * one idempotency key, one payment      -> UNIQUE (idempotency_key)
--   * a balance is never negative           -> CHECK (balance_minor >= 0)
--   * the ledger is append-only             -> a trigger that refuses UPDATE
--     and DELETE, rather than a convention everyone agrees to follow

CREATE TABLE payment (
    id              UUID PRIMARY KEY,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    order_reference VARCHAR(32)  NOT NULL,
    -- Minor units, always. A float cannot hold 0.1, and a ledger that is out
    -- by a rounding error is a ledger nobody can reconcile.
    amount_minor    BIGINT       NOT NULL CHECK (amount_minor > 0),
    currency        VARCHAR(3)   NOT NULL,
    state           VARCHAR(24)  NOT NULL CHECK (state IN (
                        'pending', 'captured', 'declined',
                        'partially_refunded', 'refunded', 'failed')),
    -- What is still held from the customer: the capture, less every refund.
    balance_minor   BIGINT       NOT NULL DEFAULT 0 CHECK (balance_minor >= 0),
    acquirer_ref    VARCHAR(64),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- A pending payment has not been charged, so it can hold no balance. This
    -- is the invariant that lets the rest of the system treat `pending` as
    -- "no money taken" without qualification.
    CONSTRAINT pending_holds_nothing
        CHECK (state <> 'pending' OR balance_minor = 0),
    CONSTRAINT resolved_states_have_no_balance
        CHECK (state NOT IN ('declined', 'failed', 'refunded') OR balance_minor = 0)
);

CREATE INDEX idx_payment_order_reference ON payment(order_reference);
-- The reconciler scans exactly this set: payments the acquirer never answered
-- for. A partial index keeps it small as settled payments accumulate.
CREATE INDEX idx_payment_pending ON payment(created_at) WHERE state = 'pending';

CREATE TABLE ledger_entry (
    payment_id    UUID        NOT NULL REFERENCES payment(id),
    seq           INT         NOT NULL,
    kind          VARCHAR(16) NOT NULL CHECK (kind IN (
                      'authorise', 'capture', 'decline', 'refund', 'void')),
    amount_minor  BIGINT      NOT NULL CHECK (amount_minor >= 0),
    balance_after BIGINT      NOT NULL CHECK (balance_after >= 0),
    detail        VARCHAR(200),
    at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (payment_id, seq)
);

-- Append-only, enforced rather than agreed. A refund is a new entry, never an
-- edit of the capture it reverses: the balance is a fold over these rows, and
-- history that can be rewritten is not history.
CREATE FUNCTION ledger_is_append_only() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'ledger_entry is append-only: % is not permitted', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_entry_no_update
    BEFORE UPDATE OR DELETE ON ledger_entry
    FOR EACH ROW EXECUTE FUNCTION ledger_is_append_only();

-- A refund can be retried like anything else on a network, and a retried
-- refund must not pay out twice. The key is the caller's; the row remembers
-- which ledger entry it produced.
CREATE TABLE refund_request (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    payment_id      UUID        NOT NULL REFERENCES payment(id),
    amount_minor    BIGINT      NOT NULL CHECK (amount_minor > 0),
    seq             INT         NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (payment_id, seq) REFERENCES ledger_entry(payment_id, seq)
);
