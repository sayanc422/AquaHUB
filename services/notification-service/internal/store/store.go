// Package store is the only place in this service that knows SQL.
package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNotFound — no outbox row with that id.
var ErrNotFound = errors.New("outbox row not found")

const (
	StatusPending = "pending"
	StatusSent    = "sent"
	StatusFailed  = "failed"

	TargetEmail   = "email"
	TargetWebhook = "webhook"

	EventOrderConfirmed    = "ORDER_CONFIRMED"
	EventOrderDispatchable = "ORDER_DISPATCHABLE"
)

type Store struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) *Store { return &Store{pool: pool} }

// Entry is one delivery obligation: one target for one event on one order.
type Entry struct {
	ID             uuid.UUID
	OrderID        uuid.UUID
	OrderReference string
	EventType      string
	TargetType     string
	Target         string
	Status         string
	Attempts       int
	LastError      string
	CreatedAt      time.Time
	SentAt         *time.Time
}

// NewEntry is one row this service has been asked to queue.
type NewEntry struct {
	OrderID        uuid.UUID
	OrderReference string
	EventType      string
	TargetType     string
	Target         string
}

// Enqueue inserts one row per target, ignoring silently any target whose
// (order, event, target type) triple has already been queued.
//
// This is the service's whole idempotency mechanism: order-service's push is
// fire-and-forget and may be retried by whatever called it, and a retried
// push must queue a second delivery attempt, not a second delivery.
func (s *Store) Enqueue(ctx context.Context, entries []NewEntry) (int, error) {
	if len(entries) == 0 {
		return 0, nil
	}
	var inserted int
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		for _, e := range entries {
			tag, err := tx.Exec(ctx, `
				INSERT INTO outbox (id, order_id, order_reference, event_type, target_type, target)
				VALUES ($1, $2, $3, $4, $5, $6)
				ON CONFLICT (order_id, event_type, target_type) DO NOTHING`,
				uuid.New(), e.OrderID, e.OrderReference, e.EventType, e.TargetType, e.Target)
			if err != nil {
				return err
			}
			inserted += int(tag.RowsAffected())
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return inserted, nil
}

// ClaimPending locks up to limit pending rows for delivery, oldest first.
//
// FOR UPDATE SKIP LOCKED, not a plain SELECT: a single replica never needs
// it, but a second replica polling the same table must not wait on rows the
// first is already sending — it should just take the next batch. Matches the
// concurrency discipline the rest of this repository puts in Postgres rather
// than in application code.
func (s *Store) ClaimPending(ctx context.Context, limit int) ([]Entry, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, order_id, order_reference, event_type, target_type, target,
		       status, attempts, COALESCE(last_error, ''), created_at, sent_at
		  FROM outbox
		 WHERE status = 'pending'
		 ORDER BY created_at
		 LIMIT $1
		   FOR UPDATE SKIP LOCKED`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Entry
	for rows.Next() {
		var e Entry
		if err := rows.Scan(&e.ID, &e.OrderID, &e.OrderReference, &e.EventType, &e.TargetType,
			&e.Target, &e.Status, &e.Attempts, &e.LastError, &e.CreatedAt, &e.SentAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// MarkSent records a successful delivery.
func (s *Store) MarkSent(ctx context.Context, id uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE outbox SET status = 'sent', sent_at = now(), attempts = attempts + 1
		 WHERE id = $1`, id)
	return err
}

// MarkAttemptFailed records a failed delivery attempt. Once attempts reaches
// maxAttempts the row moves to 'failed' and the sender stops retrying it —
// this service's own retry budget, separate from and on top of the ingest
// gap described in the README.
func (s *Store) MarkAttemptFailed(ctx context.Context, id uuid.UUID, cause string, maxAttempts int) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE outbox
		   SET attempts = attempts + 1,
		       last_error = $2,
		       status = CASE WHEN attempts + 1 >= $3 THEN 'failed' ELSE 'pending' END
		 WHERE id = $1`, id, cause, maxAttempts)
	return err
}

// Get returns one outbox row, for tests and operational lookup.
func (s *Store) Get(ctx context.Context, id uuid.UUID) (*Entry, error) {
	var e Entry
	err := s.pool.QueryRow(ctx, `
		SELECT id, order_id, order_reference, event_type, target_type, target,
		       status, attempts, COALESCE(last_error, ''), created_at, sent_at
		  FROM outbox WHERE id = $1`, id).
		Scan(&e.ID, &e.OrderID, &e.OrderReference, &e.EventType, &e.TargetType,
			&e.Target, &e.Status, &e.Attempts, &e.LastError, &e.CreatedAt, &e.SentAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &e, err
}

// CountByOrderAndEvent supports the idempotency tests: how many rows this
// (order, event) pair actually produced, regardless of target count.
func (s *Store) CountByOrderAndEvent(ctx context.Context, orderID uuid.UUID, eventType string) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx,
		`SELECT count(*) FROM outbox WHERE order_id = $1 AND event_type = $2`, orderID, eventType).Scan(&n)
	return n, err
}

// Ping is the readiness check.
func (s *Store) Ping(ctx context.Context) error { return s.pool.Ping(ctx) }
