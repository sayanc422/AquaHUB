-- Custom tank-setup enquiries: a visitor describes the tank they want and
-- leaves an email and a phone number so the shop can call them back.
--
-- This table is deliberately unrelated to customer_order, order_line and
-- order_reservation. An enquiry is not a checkout: nothing is reserved, nothing
-- is charged, no saga runs, and no state machine advances. It lives in
-- order-service because order-service already owns "a customer told us what
-- they want" and already has a database, a migration sequence and a login role
-- -- see ADR 0021 for why that beat a ninth service.
--
-- Contact details are stored encrypted, by the database, not by the
-- application. payment-service already pushes an invariant it cannot afford to
-- lose (append-only) into Postgres as a trigger rather than trusting callers to
-- behave; this is the same instinct applied to secrecy. A future service, a
-- future migration, or a hand-typed SELECT cannot read these columns without
-- the key, because the plaintext was never written down.

-- pgcrypto is a trusted extension since PostgreSQL 13, so the database owner
-- (`orders`) can create it without superuser -- verified against this project's
-- own postgres:16-alpine, as the `orders` role, before this migration was
-- written. On a Postgres where it is not trusted, this line fails and the
-- service will not start, which is the correct outcome: a silently-unencrypted
-- table would be worse than no table.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE tank_inquiry (
    id            UUID PRIMARY KEY,

    -- pgp_sym_encrypt output. BYTEA, not TEXT: this is ciphertext, not a
    -- string, and typing it as TEXT invites someone to `LIKE` it one day.
    --
    -- pgp_sym_encrypt is non-deterministic -- a fresh session key and IV per
    -- call -- so two enquiries from the same address produce different bytes.
    -- That is the property that makes the ciphertext safe to store and also
    -- the reason there is no unique constraint and no index on these columns:
    -- equality is not visible without the key, so deduplicating by email or
    -- looking one up by address is not possible here. Accepted; see ADR 0021.
    email_enc     BYTEA        NOT NULL,
    phone_enc     BYTEA        NOT NULL,

    -- The free text is encrypted too. It is the field most likely to carry
    -- identifying detail the form never asked for -- "deliver to 14 Park
    -- Street, ask for Priya" -- and a column that is plaintext because nobody
    -- expected PII in it is how PII ends up in plaintext.
    message_enc   BYTEA        NOT NULL,

    -- Length, in characters of the original message, kept in the clear on
    -- purpose. It is the only thing about a submission that can be seen
    -- without the key, and it exists so that "are enquiries arriving, and are
    -- they empty?" can be answered by an operator who is not entitled to read
    -- them. It leaks message size and nothing else.
    message_chars INT          NOT NULL CHECK (message_chars > 0),

    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- The only access pattern this table has: newest first, whenever a read path
-- finally exists. There is no read endpoint today (ADR 0021) -- the index is
-- here because it belongs with the table, not because anything uses it yet.
CREATE INDEX idx_tank_inquiry_created ON tank_inquiry(created_at DESC);
