package inventory

import (
	"errors"
	"testing"
)

func tanks(pairs ...any) []TankAvailability {
	out := make([]TankAvailability, 0, len(pairs)/2)
	for i := 0; i < len(pairs); i += 2 {
		out = append(out, TankAvailability{
			TankID:    int64(i/2 + 1),
			Code:      pairs[i].(string),
			Available: pairs[i+1].(int),
		})
	}
	return out
}

func totalOf(plan []Allocation) int {
	n := 0
	for _, a := range plan {
		n += a.Quantity
	}
	return n
}

func TestPlanPrefersTheSmallestTankThatCoversTheWholeOrder(t *testing.T) {
	plan, err := Plan(6, tanks("T-01", 40, "T-02", 8, "T-03", 25))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(plan) != 1 {
		t.Fatalf("want one line, got %d: %+v", len(plan), plan)
	}
	if plan[0].Code != "T-02" {
		t.Fatalf("want the smallest covering tank T-02, got %s", plan[0].Code)
	}
}

func TestPlanSplitsLargestFirstWhenNoSingleTankCovers(t *testing.T) {
	plan, err := Plan(30, tanks("T-01", 12, "T-02", 9, "T-03", 20))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if totalOf(plan) != 30 {
		t.Fatalf("plan does not cover the order: %+v", plan)
	}
	if len(plan) != 2 {
		t.Fatalf("want the fewest tanks (2), got %d: %+v", len(plan), plan)
	}
	if plan[0].Code != "T-03" || plan[0].Quantity != 20 {
		t.Fatalf("want the largest tank drained first, got %+v", plan[0])
	}
	if plan[1].Code != "T-01" || plan[1].Quantity != 10 {
		t.Fatalf("want the remainder from T-01, got %+v", plan[1])
	}
}

func TestPlanRefusesWhenTotalAvailabilityIsShort(t *testing.T) {
	_, err := Plan(50, tanks("T-01", 12, "T-02", 9))
	if !errors.Is(err, ErrInsufficientStock) {
		t.Fatalf("want ErrInsufficientStock, got %v", err)
	}
}

// A quarantined tank never reaches Plan; a tank whose stock is entirely held
// arrives with Available == 0 and must be skipped rather than producing a
// zero-quantity line that would violate the reservation_line CHECK.
func TestPlanIgnoresTanksWithNothingAvailable(t *testing.T) {
	plan, err := Plan(5, tanks("T-01", 0, "T-02", 5))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(plan) != 1 || plan[0].Code != "T-02" {
		t.Fatalf("want the single line from T-02, got %+v", plan)
	}
	for _, a := range plan {
		if a.Quantity <= 0 {
			t.Fatalf("zero-quantity line in plan: %+v", plan)
		}
	}
}

func TestPlanExactlyDrainsEveryTankWhenTheOrderTakesAllStock(t *testing.T) {
	plan, err := Plan(21, tanks("T-01", 12, "T-02", 9))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if totalOf(plan) != 21 || len(plan) != 2 {
		t.Fatalf("want both tanks fully drained, got %+v", plan)
	}
}

func TestPlanIsDeterministicForEqualTanks(t *testing.T) {
	in := tanks("T-09", 10, "T-02", 10, "T-05", 10)
	first, err := Plan(4, in)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	for i := 0; i < 20; i++ {
		again, err := Plan(4, in)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if again[0].Code != first[0].Code {
			t.Fatalf("plan is not deterministic: %s then %s", first[0].Code, again[0].Code)
		}
	}
	if first[0].Code != "T-02" {
		t.Fatalf("want the tie broken on tank code, got %s", first[0].Code)
	}
}

func TestPlanRejectsNonPositiveQuantity(t *testing.T) {
	if _, err := Plan(0, tanks("T-01", 5)); err == nil {
		t.Fatal("want an error for a zero-quantity reservation")
	}
}
