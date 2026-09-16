package store_test

// Integration tests for the parts of this service that only exist under a
// real Postgres: the unique constraint that makes a retried ingest push
// idempotent, and the attempts/status bookkeeping the sender depends on.
//
// They run against NOTIFICATION_TEST_DSN and skip when it is not set, the
// same convention inventory-service's store_integration_test.go uses:
//
//	export NOTIFICATION_TEST_DSN='postgres://postgres@127.0.0.1:5432/notify_test?sslmode=disable'
//	go test ./...

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sayanc422/aquahub/services/notification-service/internal/store"
)

var pool *pgxpool.Pool

func TestMain(m *testing.M) {
	dsn := os.Getenv("NOTIFICATION_TEST_DSN")
	if dsn == "" {
		fmt.Fprintln(os.Stderr, "NOTIFICATION_TEST_DSN is not set; skipping store integration tests")
		os.Exit(0)
	}
	ctx := context.Background()
	p, err := pgxpool.New(ctx, dsn)
	if err != nil {
		fmt.Fprintln(os.Stderr, "connect:", err)
		os.Exit(1)
	}
	if err := store.Migrate(ctx, p, slog.New(slog.NewTextHandler(io.Discard, nil))); err != nil {
		fmt.Fprintln(os.Stderr, "migrate:", err)
		os.Exit(1)
	}
	pool = p
	code := m.Run()
	p.Close()
	os.Exit(code)
}

func newStore() *store.Store { return store.New(pool) }

func TestEnqueueInsertsOneRowPerTarget(t *testing.T) {
	t.Parallel()
	s := newStore()
	orderID := uuid.New()

	n, err := s.Enqueue(context.Background(), []store.NewEntry{
		{OrderID: orderID, OrderReference: "ord-1", EventType: store.EventOrderConfirmed,
			TargetType: store.TargetEmail, Target: "a@example.com"},
		{OrderID: orderID, OrderReference: "ord-1", EventType: store.EventOrderConfirmed,
			TargetType: store.TargetWebhook, Target: "http://example.invalid/hook"},
	})
	if err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	if n != 2 {
		t.Fatalf("inserted = %d, want 2", n)
	}
	count, err := s.CountByOrderAndEvent(context.Background(), orderID, store.EventOrderConfirmed)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 2 {
		t.Fatalf("count = %d, want 2", count)
	}
}

// The property the whole ingest-idempotency story rests on: order-service's
// push is fire-and-forget and may be retried by whatever called it, and a
// retry must not queue a second delivery for a target that already has one.
func TestEnqueueIsIdempotentPerOrderEventTarget(t *testing.T) {
	t.Parallel()
	s := newStore()
	orderID := uuid.New()
	entry := store.NewEntry{OrderID: orderID, OrderReference: "ord-2", EventType: store.EventOrderConfirmed,
		TargetType: store.TargetEmail, Target: "a@example.com"}

	first, err := s.Enqueue(context.Background(), []store.NewEntry{entry})
	if err != nil {
		t.Fatalf("first enqueue: %v", err)
	}
	if first != 1 {
		t.Fatalf("first enqueue inserted = %d, want 1", first)
	}

	second, err := s.Enqueue(context.Background(), []store.NewEntry{entry})
	if err != nil {
		t.Fatalf("second enqueue: %v", err)
	}
	if second != 0 {
		t.Fatalf("retry inserted = %d, want 0 — a retried push must not double-queue", second)
	}

	count, err := s.CountByOrderAndEvent(context.Background(), orderID, store.EventOrderConfirmed)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("count = %d, want 1 after a retried push", count)
	}
}

// A different event on the same order is a different obligation, not a
// duplicate — ORDER_CONFIRMED and ORDER_DISPATCHABLE for the same order must
// both queue.
func TestEnqueueTreatsDifferentEventTypesAsDistinct(t *testing.T) {
	t.Parallel()
	s := newStore()
	orderID := uuid.New()

	if _, err := s.Enqueue(context.Background(), []store.NewEntry{
		{OrderID: orderID, OrderReference: "ord-3", EventType: store.EventOrderConfirmed,
			TargetType: store.TargetEmail, Target: "a@example.com"},
	}); err != nil {
		t.Fatalf("enqueue confirmed: %v", err)
	}
	n, err := s.Enqueue(context.Background(), []store.NewEntry{
		{OrderID: orderID, OrderReference: "ord-3", EventType: store.EventOrderDispatchable,
			TargetType: store.TargetEmail, Target: "a@example.com"},
	})
	if err != nil {
		t.Fatalf("enqueue dispatchable: %v", err)
	}
	if n != 1 {
		t.Fatalf("a different event type must queue its own row, inserted = %d", n)
	}
}

func TestClaimPendingSkipsSentAndFailedRows(t *testing.T) {
	t.Parallel()
	s := newStore()
	orderID := uuid.New()

	if _, err := s.Enqueue(context.Background(), []store.NewEntry{
		{OrderID: orderID, OrderReference: "ord-4", EventType: store.EventOrderConfirmed,
			TargetType: store.TargetEmail, Target: "a@example.com"},
	}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}

	claimed, err := s.ClaimPending(context.Background(), 10)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	var id uuid.UUID
	found := false
	for _, e := range claimed {
		if e.OrderID == orderID {
			id, found = e.ID, true
		}
	}
	if !found {
		t.Fatal("newly enqueued row was not claimable as pending")
	}

	if err := s.MarkSent(context.Background(), id); err != nil {
		t.Fatalf("mark sent: %v", err)
	}

	claimedAgain, err := s.ClaimPending(context.Background(), 10)
	if err != nil {
		t.Fatalf("claim again: %v", err)
	}
	for _, e := range claimedAgain {
		if e.ID == id {
			t.Fatal("a sent row must not be claimable as pending again")
		}
	}
}

func TestMarkAttemptFailedMovesToFailedAfterMaxAttempts(t *testing.T) {
	t.Parallel()
	s := newStore()
	orderID := uuid.New()

	if _, err := s.Enqueue(context.Background(), []store.NewEntry{
		{OrderID: orderID, OrderReference: "ord-5", EventType: store.EventOrderConfirmed,
			TargetType: store.TargetEmail, Target: "a@example.com"},
	}); err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	claimed, err := s.ClaimPending(context.Background(), 10)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	var id uuid.UUID
	for _, e := range claimed {
		if e.OrderID == orderID {
			id = e.ID
		}
	}
	if id == uuid.Nil {
		t.Fatal("row was not claimed")
	}

	const maxAttempts = 2
	if err := s.MarkAttemptFailed(context.Background(), id, "boom", maxAttempts); err != nil {
		t.Fatalf("first failure: %v", err)
	}
	mid, err := s.Get(context.Background(), id)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if mid.Status != store.StatusPending {
		t.Fatalf("status after attempt 1 of %d = %s, want pending", maxAttempts, mid.Status)
	}

	if err := s.MarkAttemptFailed(context.Background(), id, "boom again", maxAttempts); err != nil {
		t.Fatalf("second failure: %v", err)
	}
	final, err := s.Get(context.Background(), id)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if final.Status != store.StatusFailed {
		t.Fatalf("status after attempt %d of %d = %s, want failed", maxAttempts, maxAttempts, final.Status)
	}
	if final.Attempts != maxAttempts {
		t.Fatalf("attempts = %d, want %d", final.Attempts, maxAttempts)
	}
}
