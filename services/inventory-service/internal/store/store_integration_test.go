package store_test

// Integration tests for the parts of this service that only exist under
// concurrency: row locks, the unique idempotency index, and the CHECK that
// stops stock going negative. None of that survives being mocked — a fake that
// returns what the test expects proves the test, not the lock.
//
// They run against a real Postgres, named by INVENTORY_TEST_DSN, and skip
// when it is not set so that `go test ./...` still works on a machine with no
// database:
//
//	export INVENTORY_TEST_DSN='postgres://postgres@127.0.0.1:5432/inventory_test?sslmode=disable'
//	go test ./...
//
// Each test seeds tanks under its own SKU, so the whole file can run in
// parallel against one database without any truncation between tests.

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sayanc422/aquahub/services/inventory-service/internal/inventory"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/store"
)

var pool *pgxpool.Pool

func TestMain(m *testing.M) {
	dsn := os.Getenv("INVENTORY_TEST_DSN")
	if dsn == "" {
		fmt.Fprintln(os.Stderr, "INVENTORY_TEST_DSN is not set; skipping store integration tests")
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

// ---------- fixtures ----------

type tank struct {
	code   string
	onHand int
	status string
}

// seedTanks gives a test its own SKU and its own glass, so tests never contend
// for the same rows and can run in parallel.
func seedTanks(t *testing.T, tanks ...tank) string {
	t.Helper()
	sku := "TEST-" + uuid.NewString()[:8]
	ctx := context.Background()
	for _, tk := range tanks {
		status := tk.status
		if status == "" {
			status = "open"
		}
		_, err := pool.Exec(ctx,
			`INSERT INTO tank (code, sku, quantity_on_hand, status) VALUES ($1, $2, $3, $4)`,
			sku+"/"+tk.code, sku, tk.onHand, status)
		if err != nil {
			t.Fatalf("seed tank %s: %v", tk.code, err)
		}
	}
	return sku
}

func newStore() *store.Store { return store.New(pool) }

func req(sku, key string, qty int, ttl time.Duration) store.NewRequest {
	return store.NewRequest{
		IdempotencyKey: key,
		RequestDigest:  fmt.Sprintf("%064x", len(key)*1000+qty),
		OrderRef:       "ord-" + key,
		SKU:            sku,
		Quantity:       qty,
		TTL:            ttl,
	}
}

func available(t *testing.T, s *store.Store, sku string) int {
	t.Helper()
	tanks, err := s.Stock(context.Background(), sku)
	if err != nil {
		t.Fatalf("stock: %v", err)
	}
	total := 0
	for _, tk := range tanks {
		total += tk.Available
	}
	return total
}

func onHand(t *testing.T, s *store.Store, sku string) int {
	t.Helper()
	tanks, err := s.Stock(context.Background(), sku)
	if err != nil {
		t.Fatalf("stock: %v", err)
	}
	total := 0
	for _, tk := range tanks {
		total += tk.OnHand
	}
	return total
}

// ---------- tests ----------

func TestReserveHoldsStockWithoutRemovingIt(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, replayed, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if replayed {
		t.Fatal("a first reservation must not report as a replay")
	}
	if res.State != store.StateHeld || len(res.Lines) != 1 || res.Lines[0].Quantity != 4 {
		t.Fatalf("unexpected reservation: %+v", res)
	}
	// A hold is a promise, not a sale: availability drops, the tank does not.
	if got := available(t, s, sku); got != 6 {
		t.Fatalf("available = %d, want 6", got)
	}
	if got := onHand(t, s, sku); got != 10 {
		t.Fatalf("onHand = %d, want 10 — a hold must not remove fish from the tank", got)
	}
}

func TestReplayReturnsTheSameReservationAndHoldsStockOnce(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})
	key := uuid.NewString()

	first, _, err := s.Reserve(context.Background(), req(sku, key, 4, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	second, replayed, err := s.Reserve(context.Background(), req(sku, key, 4, time.Minute))
	if err != nil {
		t.Fatalf("replay: %v", err)
	}
	if !replayed {
		t.Fatal("the second call with the same key must report as a replay")
	}
	if second.ID != first.ID {
		t.Fatalf("replay created a new reservation: %s then %s", first.ID, second.ID)
	}
	if got := available(t, s, sku); got != 6 {
		t.Fatalf("available = %d, want 6 — the retry held stock a second time", got)
	}
}

func TestKeyReusedForADifferentRequestIsRejected(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})
	key := uuid.NewString()

	if _, _, err := s.Reserve(context.Background(), req(sku, key, 4, time.Minute)); err != nil {
		t.Fatalf("reserve: %v", err)
	}
	_, _, err := s.Reserve(context.Background(), req(sku, key, 7, time.Minute))
	if !errors.Is(err, store.ErrIdempotencyConflict) {
		t.Fatalf("want ErrIdempotencyConflict, got %v", err)
	}
}

// A refusal must roll back the reservation row with it. If the key were burned,
// the customer who reduces their basket and retries — with the same key, as
// every sane client does — would get a permanent 409.
func TestRefusedReservationDoesNotBurnTheIdempotencyKey(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 5})
	key := uuid.NewString()

	_, _, err := s.Reserve(context.Background(), req(sku, key, 9, time.Minute))
	if !errors.Is(err, inventory.ErrInsufficientStock) {
		t.Fatalf("want ErrInsufficientStock, got %v", err)
	}
	res, replayed, err := s.Reserve(context.Background(), req(sku, key, 3, time.Minute))
	if err != nil {
		t.Fatalf("retry with the same key after a refusal: %v", err)
	}
	if replayed {
		t.Fatal("the retry replayed a reservation that was never created")
	}
	if res.Quantity != 3 {
		t.Fatalf("quantity = %d, want 3", res.Quantity)
	}
}

// The property the whole service rests on: a hold stops holding when it
// expires, whether or not anything has run since.
func TestExpiredHoldReleasesStockWithNoReaperRun(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 10, 1*time.Second))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if got := available(t, s, sku); got != 0 {
		t.Fatalf("available = %d, want 0 while the hold is live", got)
	}

	time.Sleep(1200 * time.Millisecond)

	// No ExpireDue call anywhere above. Availability is computed from the
	// deadline, so the stock is sellable again the moment it passes.
	if got := available(t, s, sku); got != 10 {
		t.Fatalf("available = %d, want 10 after expiry without a reaper pass", got)
	}
	// And the reservation reads as expired even though its row still says held.
	reloaded, err := s.Get(context.Background(), res.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if reloaded.State != store.StateExpired {
		t.Fatalf("state = %s, want expired", reloaded.State)
	}
}

func TestCommitAfterExpiryIsRefused(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, 1*time.Second))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	time.Sleep(1200 * time.Millisecond)

	if _, err := s.Commit(context.Background(), res.ID); !errors.Is(err, store.ErrExpired) {
		t.Fatalf("want ErrExpired, got %v", err)
	}
	if got := onHand(t, s, sku); got != 10 {
		t.Fatalf("onHand = %d, want 10 — an expired hold must not be able to sell stock", got)
	}
}

func TestCommitRemovesStockAndIsIdempotent(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if _, err := s.Commit(context.Background(), res.ID); err != nil {
		t.Fatalf("commit: %v", err)
	}
	if got := onHand(t, s, sku); got != 6 {
		t.Fatalf("onHand = %d, want 6 after the commit", got)
	}

	// The order service retries a timed-out commit. The second call must not
	// take another four fish out of the tank.
	again, err := s.Commit(context.Background(), res.ID)
	if err != nil {
		t.Fatalf("second commit: %v", err)
	}
	if again.State != store.StateCommitted {
		t.Fatalf("state = %s, want committed", again.State)
	}
	if got := onHand(t, s, sku); got != 6 {
		t.Fatalf("onHand = %d, want 6 — the retried commit decremented twice", got)
	}
}

func TestReleaseReturnsStockAndIsIdempotent(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if _, err := s.Release(context.Background(), res.ID); err != nil {
		t.Fatalf("release: %v", err)
	}
	if got := available(t, s, sku); got != 10 {
		t.Fatalf("available = %d, want 10 after release", got)
	}
	if _, err := s.Release(context.Background(), res.ID); err != nil {
		t.Fatalf("second release must be a no-op, got %v", err)
	}
}

func TestCommittedReservationCannotBeReleased(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if _, err := s.Commit(context.Background(), res.ID); err != nil {
		t.Fatalf("commit: %v", err)
	}
	// Reversing a sale is a refund, and refunds belong to payment-service.
	if _, err := s.Release(context.Background(), res.ID); !errors.Is(err, store.ErrStateConflict) {
		t.Fatalf("want ErrStateConflict, got %v", err)
	}
}

func TestQuarantinedTankIsNeverAllocated(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t,
		tank{code: "OPEN", onHand: 3},
		tank{code: "QUAR", onHand: 50, status: "quarantine"},
	)

	if got := available(t, s, sku); got != 3 {
		t.Fatalf("available = %d, want 3 — quarantined stock is not sellable", got)
	}
	if _, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 4, time.Minute)); !errors.Is(err, inventory.ErrInsufficientStock) {
		t.Fatalf("want ErrInsufficientStock, got %v", err)
	}
	// It is still visible: the fish exist, and the person reconciling the
	// count is standing in front of the tank.
	tanks, _ := s.Stock(context.Background(), sku)
	if len(tanks) != 2 {
		t.Fatalf("want both tanks reported, got %d", len(tanks))
	}
}

// The test that justifies the row lock. Twenty goroutines race for eight fish,
// two at a time: exactly four may win. Without `FOR UPDATE` on the tank rows,
// several transactions read the same availability and all of them succeed.
func TestConcurrentReservationsCannotOversell(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 8})

	const racers = 20
	var (
		wg        sync.WaitGroup
		succeeded atomic.Int64
		refused   atomic.Int64
		start     = make(chan struct{})
	)
	for i := 0; i < racers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 2, time.Minute))
			switch {
			case err == nil:
				succeeded.Add(1)
			case errors.Is(err, inventory.ErrInsufficientStock):
				refused.Add(1)
			default:
				t.Errorf("unexpected error: %v", err)
			}
		}()
	}
	close(start)
	wg.Wait()

	if succeeded.Load() != 4 {
		t.Fatalf("%d reservations succeeded, want exactly 4 — stock was oversold", succeeded.Load())
	}
	if refused.Load() != racers-4 {
		t.Fatalf("%d refusals, want %d", refused.Load(), racers-4)
	}
	if got := available(t, s, sku); got != 0 {
		t.Fatalf("available = %d, want 0", got)
	}
}

// The reaper changes bookkeeping, not availability. This test asserts both
// halves: the state column becomes honest, and the number it reports is right.
func TestReaperMarksExpiredHoldsWithoutChangingAvailability(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 10})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 5, 1*time.Second))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	time.Sleep(1200 * time.Millisecond)

	before := available(t, s, sku)
	if _, err := s.ExpireDue(context.Background()); err != nil {
		t.Fatalf("reaper: %v", err)
	}
	if after := available(t, s, sku); after != before {
		t.Fatalf("the reaper changed availability: %d -> %d", before, after)
	}

	var state string
	if err := pool.QueryRow(context.Background(),
		`SELECT state FROM reservation WHERE id = $1`, res.ID).Scan(&state); err != nil {
		t.Fatalf("read state: %v", err)
	}
	if state != store.StateExpired {
		t.Fatalf("stored state = %s, want expired", state)
	}
}

func TestReservationSplitsAcrossTanksWhenNoSingleTankCovers(t *testing.T) {
	t.Parallel()
	s := newStore()
	sku := seedTanks(t, tank{code: "A", onHand: 6}, tank{code: "B", onHand: 9})

	res, _, err := s.Reserve(context.Background(), req(sku, uuid.NewString(), 12, time.Minute))
	if err != nil {
		t.Fatalf("reserve: %v", err)
	}
	if len(res.Lines) != 2 {
		t.Fatalf("want two tank lines, got %+v", res.Lines)
	}
	total := 0
	for _, l := range res.Lines {
		total += l.Quantity
	}
	if total != 12 {
		t.Fatalf("lines total %d, want 12", total)
	}
	if got := available(t, s, sku); got != 3 {
		t.Fatalf("available = %d, want 3", got)
	}

	// And the commit takes the right number out of each piece of glass.
	if _, err := s.Commit(context.Background(), res.ID); err != nil {
		t.Fatalf("commit: %v", err)
	}
	if got := onHand(t, s, sku); got != 3 {
		t.Fatalf("onHand = %d, want 3", got)
	}
}

func TestGetUnknownReservationIsNotFound(t *testing.T) {
	t.Parallel()
	if _, err := newStore().Get(context.Background(), uuid.New()); !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("want ErrNotFound, got %v", err)
	}
}
