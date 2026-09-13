// Package store is the only place in this service that knows SQL.
//
// Every rule that must hold under concurrency is enforced by Postgres — a row
// lock, a unique index or a CHECK — not by Go. Two pods, a retry storm and a
// reaper all run against the same tables, and application-level "check then
// write" loses that race every time.
package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sayanc422/aquahub/services/inventory-service/internal/inventory"
)

var (
	// ErrNotFound — no reservation with that id.
	ErrNotFound = errors.New("reservation not found")
	// ErrIdempotencyConflict — the key has been used for a different request.
	ErrIdempotencyConflict = errors.New("idempotency key reused with a different request")
	// ErrStateConflict — the reservation cannot make this transition.
	ErrStateConflict = errors.New("reservation is not in a state that allows this")
	// ErrExpired — the hold ran out before the caller committed it.
	ErrExpired = errors.New("reservation expired")
)

// States of a reservation. A hold is the only state that subtracts from
// availability, and it is the only state with a deadline.
const (
	StateHeld      = "held"
	StateCommitted = "committed"
	StateReleased  = "released"
	StateExpired   = "expired"
)

type Store struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) *Store { return &Store{pool: pool} }

// Line is one tank's contribution to a reservation.
type Line struct {
	TankID   int64  `json:"-"`
	TankCode string `json:"tank"`
	Quantity int    `json:"quantity"`
}

// Reservation is the stored form. The API shape lives in the api package; this
// is the service's own record.
type Reservation struct {
	ID        uuid.UUID
	OrderRef  string
	SKU       string
	Quantity  int
	State     string
	ExpiresAt time.Time
	CreatedAt time.Time
	Lines     []Line
}

// NewRequest is one attempt to hold stock.
type NewRequest struct {
	IdempotencyKey string
	RequestDigest  string
	OrderRef       string
	SKU            string
	Quantity       int
	TTL            time.Duration
}

// TankStock is the per-tank view returned by the stock endpoint.
type TankStock struct {
	Code      string `json:"tank"`
	Status    string `json:"status"`
	OnHand    int    `json:"onHand"`
	Held      int    `json:"held"`
	Available int    `json:"available"`
	Note      string `json:"note,omitempty"`
}

// Availability is read through this expression everywhere, and `now()` is the
// reason the service is correct without the reaper: an expired hold stops
// subtracting the instant it expires, not when a background job notices. The
// reaper only tidies the state column so the table reads honestly.
const availableExpr = `
	t.quantity_on_hand - COALESCE((
		SELECT SUM(l.quantity)
		  FROM reservation_line l
		  JOIN reservation r ON r.id = l.reservation_id
		 WHERE l.tank_id = t.id
		   AND r.state = 'held'
		   AND r.expires_at > now()
	), 0)`

// Reserve creates a hold, or replays the one this idempotency key already made.
//
// The second return value is true when the call was a replay: the caller turns
// that into 200 rather than 201, so a client that retries through a lost
// response can tell a fresh hold from an echo of its own.
func (s *Store) Reserve(ctx context.Context, req NewRequest) (*Reservation, bool, error) {
	var (
		res      *Reservation
		replayed bool
	)
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		id := uuid.New()
		var (
			existingID     uuid.UUID
			existingDigest string
			inserted       bool
		)
		// ON CONFLICT DO UPDATE, not DO NOTHING. DO NOTHING returns no row when
		// the conflicting insert is still uncommitted in another transaction,
		// and the follow-up SELECT cannot see it either — the retry would look
		// like a lost key. DO UPDATE takes the row lock and waits for that
		// transaction to finish, so the loser of the race always ends up
		// holding the winner's row. `xmax = 0` distinguishes the two: on a
		// genuine insert the row has no updating transaction id.
		err := tx.QueryRow(ctx, `
			INSERT INTO reservation
			    (id, idempotency_key, request_digest, order_ref, sku, quantity, state, expires_at)
			VALUES ($1, $2, $3, $4, $5, $6, 'held', now() + $7::interval)
			ON CONFLICT (idempotency_key)
			    DO UPDATE SET updated_at = reservation.updated_at
			RETURNING id, request_digest, (xmax = 0) AS inserted`,
			id, req.IdempotencyKey, req.RequestDigest, req.OrderRef, req.SKU, req.Quantity,
			fmt.Sprintf("%d seconds", int(req.TTL.Seconds())),
		).Scan(&existingID, &existingDigest, &inserted)
		if err != nil {
			return fmt.Errorf("insert reservation: %w", err)
		}

		if !inserted {
			if existingDigest != req.RequestDigest {
				return ErrIdempotencyConflict
			}
			loaded, err := loadReservation(ctx, tx, existingID)
			if err != nil {
				return err
			}
			res, replayed = loaded, true
			return nil
		}

		// Locking and reading availability are two statements, deliberately.
		//
		// Under READ COMMITTED a statement's snapshot is taken when the statement
		// begins — before it blocks on a row lock. Doing both in one
		// `SELECT ... FOR UPDATE` therefore returns availability as it looked
		// *before* the transaction ahead of it inserted its lines, and two
		// reservations promise the same fish. The test that proves it is
		// TestConcurrentReservationsCannotOversell, and it failed against exactly
		// that one-statement version.
		//
		// So: take the locks first, then read in a second statement, whose fresh
		// snapshot includes everything the transaction we waited for committed.
		//
		// `ORDER BY id` makes the lock order total, so two reservations that
		// overlap on two tanks cannot deadlock. The tank row is the concurrency
		// unit even though this transaction never updates it: it is the row that
		// names the resource being promised.
		var tankIDs []int64
		lockRows, err := tx.Query(ctx, `
			SELECT id FROM tank
			 WHERE sku = $1 AND status = 'open'
			 ORDER BY id
			   FOR UPDATE`, req.SKU)
		if err != nil {
			return fmt.Errorf("lock tanks: %w", err)
		}
		for lockRows.Next() {
			var id int64
			if err := lockRows.Scan(&id); err != nil {
				lockRows.Close()
				return err
			}
			tankIDs = append(tankIDs, id)
		}
		lockRows.Close()
		if err := lockRows.Err(); err != nil {
			return err
		}
		if len(tankIDs) == 0 {
			return inventory.ErrInsufficientStock
		}

		// Only the tanks actually locked above. A tank added for this SKU between
		// the two statements is not covered by our locks, so allocating from it
		// would reopen the same race on a new row.
		rows, err := tx.Query(ctx, `
			SELECT t.id, t.code, `+availableExpr+`
			  FROM tank t
			 WHERE t.id = ANY($1)
			 ORDER BY t.id`, tankIDs)
		if err != nil {
			return fmt.Errorf("read availability: %w", err)
		}
		var avail []inventory.TankAvailability
		for rows.Next() {
			var a inventory.TankAvailability
			if err := rows.Scan(&a.TankID, &a.Code, &a.Available); err != nil {
				rows.Close()
				return err
			}
			avail = append(avail, a)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}

		plan, err := inventory.Plan(req.Quantity, avail)
		if err != nil {
			// Rolls back the reservation row with it. A refused reservation
			// must not burn the idempotency key: the customer adds one fewer
			// fish and retries with the same key, and that has to work.
			return err
		}

		batch := &pgx.Batch{}
		for _, line := range plan {
			batch.Queue(`INSERT INTO reservation_line (reservation_id, tank_id, quantity)
			             VALUES ($1, $2, $3)`, id, line.TankID, line.Quantity)
		}
		if err := tx.SendBatch(ctx, batch).Close(); err != nil {
			return fmt.Errorf("insert reservation lines: %w", err)
		}

		loaded, err := loadReservation(ctx, tx, id)
		if err != nil {
			return err
		}
		res = loaded
		return nil
	})
	if err != nil {
		return nil, false, err
	}
	return res, replayed, nil
}

// Commit turns a hold into a sale: the stock leaves the tank for good.
//
// Idempotent — committing an already-committed reservation returns it
// unchanged, because the order service will retry this call after a timeout and
// must not be told its own completed work failed.
func (s *Store) Commit(ctx context.Context, id uuid.UUID) (*Reservation, error) {
	var res *Reservation
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		var state string
		var expiresAt time.Time
		err := tx.QueryRow(ctx,
			`SELECT state, expires_at FROM reservation WHERE id = $1 FOR UPDATE`, id).
			Scan(&state, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}

		switch state {
		case StateCommitted:
			loaded, err := loadReservation(ctx, tx, id)
			res = loaded
			return err
		case StateReleased:
			return ErrStateConflict
		case StateExpired:
			return ErrExpired
		}

		// A hold whose deadline has passed is expired whether or not the reaper
		// has been round yet. Committing it would sell stock the availability
		// query has already promised to somebody else.
		if !expiresAt.After(time.Now()) {
			if _, err := tx.Exec(ctx,
				`UPDATE reservation SET state = 'expired', updated_at = now() WHERE id = $1`, id); err != nil {
				return err
			}
			return ErrExpired
		}

		// Locking order matches Reserve: tanks ascending by id.
		if _, err := tx.Exec(ctx, `
			UPDATE tank t
			   SET quantity_on_hand = t.quantity_on_hand - l.quantity
			  FROM reservation_line l
			 WHERE l.reservation_id = $1 AND t.id = l.tank_id`, id); err != nil {
			// quantity_on_hand >= 0 is a CHECK. If this ever fires, the bug is
			// in this service, and a violated constraint is the correct outcome:
			// a refused commit beats a tank holding minus four fish.
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23514" {
				return fmt.Errorf("commit would drive stock negative: %w", err)
			}
			return err
		}

		if _, err := tx.Exec(ctx,
			`UPDATE reservation SET state = 'committed', updated_at = now() WHERE id = $1`, id); err != nil {
			return err
		}
		loaded, err := loadReservation(ctx, tx, id)
		res = loaded
		return err
	})
	if err != nil {
		return nil, err
	}
	return res, nil
}

// Release returns a hold to stock early — an abandoned cart, a failed payment.
// Releasing an already-released or already-expired hold is a no-op, so the
// caller's retry and the reaper cannot fight over it.
func (s *Store) Release(ctx context.Context, id uuid.UUID) (*Reservation, error) {
	var res *Reservation
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		var state string
		err := tx.QueryRow(ctx, `SELECT state FROM reservation WHERE id = $1 FOR UPDATE`, id).Scan(&state)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if state == StateCommitted {
			// Undoing a sale is a refund, and refunds belong to
			// payment-service. This service will not silently reverse one.
			return ErrStateConflict
		}
		if state == StateHeld {
			if _, err := tx.Exec(ctx,
				`UPDATE reservation SET state = 'released', updated_at = now() WHERE id = $1`, id); err != nil {
				return err
			}
		}
		loaded, err := loadReservation(ctx, tx, id)
		res = loaded
		return err
	})
	if err != nil {
		return nil, err
	}
	return res, nil
}

// Get returns one reservation.
func (s *Store) Get(ctx context.Context, id uuid.UUID) (*Reservation, error) {
	return loadReservation(ctx, s.pool, id)
}

// ExpireDue marks every hold past its deadline as expired and returns how many.
//
// This changes no availability — the availability query already ignores them.
// It exists so the table says what is true, so the active-holds gauge is not
// permanently wrong, and so a support question ("what happened to this hold?")
// has an answer other than arithmetic on a timestamp.
func (s *Store) ExpireDue(ctx context.Context) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		UPDATE reservation
		   SET state = 'expired', updated_at = now()
		 WHERE state = 'held' AND expires_at <= now()`)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ActiveHolds counts holds that still subtract from availability.
func (s *Store) ActiveHolds(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx,
		`SELECT count(*) FROM reservation WHERE state = 'held' AND expires_at > now()`).Scan(&n)
	return n, err
}

// Stock reports every tank holding a SKU, quarantined tanks included.
//
// A quarantined tank shows its count and contributes nothing to availability.
// Hiding it would make the shop floor and the API disagree, and the person
// reconciling them is standing in front of the tank.
func (s *Store) Stock(ctx context.Context, sku string) ([]TankStock, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT t.code, t.status, t.quantity_on_hand, COALESCE(t.note, ''),
		       COALESCE((
		           SELECT SUM(l.quantity)
		             FROM reservation_line l
		             JOIN reservation r ON r.id = l.reservation_id
		            WHERE l.tank_id = t.id AND r.state = 'held' AND r.expires_at > now()
		       ), 0) AS held
		  FROM tank t
		 WHERE t.sku = $1
		 ORDER BY t.code`, sku)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []TankStock{}
	for rows.Next() {
		var ts TankStock
		if err := rows.Scan(&ts.Code, &ts.Status, &ts.OnHand, &ts.Note, &ts.Held); err != nil {
			return nil, err
		}
		if ts.Status == "open" {
			ts.Available = ts.OnHand - ts.Held
		}
		out = append(out, ts)
	}
	return out, rows.Err()
}

// Ping is the readiness check: a pool that cannot reach Postgres must leave the
// Service endpoints rather than serve 500s.
func (s *Store) Ping(ctx context.Context) error { return s.pool.Ping(ctx) }

// querier is satisfied by both *pgxpool.Pool and pgx.Tx, so reservations load
// the same way inside and outside a transaction.
type querier interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}

func loadReservation(ctx context.Context, q querier, id uuid.UUID) (*Reservation, error) {
	var r Reservation
	err := q.QueryRow(ctx, `
		SELECT id, order_ref, sku, quantity, state, expires_at, created_at
		  FROM reservation WHERE id = $1`, id).
		Scan(&r.ID, &r.OrderRef, &r.SKU, &r.Quantity, &r.State, &r.ExpiresAt, &r.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	// A hold past its deadline reads as expired even before the reaper has
	// updated the row, so the API never reports a hold the availability query
	// has already stopped honouring.
	if r.State == StateHeld && !r.ExpiresAt.After(time.Now()) {
		r.State = StateExpired
	}

	rows, err := q.Query(ctx, `
		SELECT t.code, l.tank_id, l.quantity
		  FROM reservation_line l JOIN tank t ON t.id = l.tank_id
		 WHERE l.reservation_id = $1
		 ORDER BY t.code`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	r.Lines = []Line{}
	for rows.Next() {
		var l Line
		if err := rows.Scan(&l.TankCode, &l.TankID, &l.Quantity); err != nil {
			return nil, err
		}
		r.Lines = append(r.Lines, l)
	}
	return &r, rows.Err()
}
