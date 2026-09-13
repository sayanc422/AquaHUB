// Package inventory holds the domain rules of stock allocation.
//
// Nothing in this file touches a database or an HTTP request. Allocation is the
// part of the service that is worth reasoning about carefully, so it is a pure
// function over a snapshot of tank availability: the tests below it need no
// Postgres, and a failing test names a rule rather than a fixture.
package inventory

import (
	"errors"
	"sort"
)

// ErrInsufficientStock is returned when the open tanks for a SKU cannot cover
// the requested quantity. It is a domain outcome, not a failure: the caller
// turns it into 409, not 500.
var ErrInsufficientStock = errors.New("insufficient stock")

// TankAvailability is what one physical tank can still promise: its quantity on
// hand minus every hold against it that has not yet expired.
type TankAvailability struct {
	TankID    int64
	Code      string
	Available int
}

// Allocation is one line of a reservation: how much is taken from which tank.
type Allocation struct {
	TankID   int64
	Code     string
	Quantity int
}

// Plan decides which tanks a reservation draws from.
//
// The rule is best-fit, then largest-first:
//
//  1. If any single tank can cover the whole quantity, use the *smallest* such
//     tank. Livestock from one tank ships as one bag: fewer tanks means less
//     handling, and it leaves the larger tanks intact for larger orders.
//  2. Otherwise split across tanks largest-first, so the split uses as few
//     tanks as possible.
//
// Cost: best-fit fragments stock. Repeated small orders leave many tanks with a
// few fish each, and a later large order splits across more tanks than a
// first-fit policy would have needed. That is the trade accepted here — a
// livestock order that arrives as one bag is worth more than a tidy ledger.
//
// Ties break on tank code so the plan is deterministic; an allocator that
// returns a different plan for the same input is untestable and makes an
// incident unreproducible.
func Plan(quantity int, tanks []TankAvailability) ([]Allocation, error) {
	if quantity <= 0 {
		return nil, errors.New("quantity must be positive")
	}

	usable := make([]TankAvailability, 0, len(tanks))
	total := 0
	for _, t := range tanks {
		if t.Available > 0 {
			usable = append(usable, t)
			total += t.Available
		}
	}
	if total < quantity {
		return nil, ErrInsufficientStock
	}

	// Ascending by availability, then by code for a stable order.
	sort.Slice(usable, func(i, j int) bool {
		if usable[i].Available != usable[j].Available {
			return usable[i].Available < usable[j].Available
		}
		return usable[i].Code < usable[j].Code
	})

	// Best fit: the smallest tank that covers the whole request.
	for _, t := range usable {
		if t.Available >= quantity {
			return []Allocation{{TankID: t.TankID, Code: t.Code, Quantity: quantity}}, nil
		}
	}

	// No single tank covers it. Split largest-first.
	plan := make([]Allocation, 0, 2)
	remaining := quantity
	for i := len(usable) - 1; i >= 0 && remaining > 0; i-- {
		t := usable[i]
		take := t.Available
		if take > remaining {
			take = remaining
		}
		plan = append(plan, Allocation{TankID: t.TankID, Code: t.Code, Quantity: take})
		remaining -= take
	}
	if remaining > 0 {
		// Unreachable: total was checked above. Kept because a silent partial
		// allocation would be worse than a loud error.
		return nil, ErrInsufficientStock
	}
	return plan, nil
}
