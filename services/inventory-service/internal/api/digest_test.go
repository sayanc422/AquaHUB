package api

import (
	"testing"
	"time"
)

// Idempotency is only as good as the digest: if a reformatted retry produced a
// different digest, every client behind a JSON-normalising proxy would see
// spurious 409s.
func TestDigestIsStableForTheSameIntent(t *testing.T) {
	a := reservationRequest{OrderRef: "ord-1", SKU: "FSH-NEON-TETRA", Quantity: 6}
	b := reservationRequest{SKU: "FSH-NEON-TETRA", OrderRef: "ord-1", Quantity: 6}
	if digest(a, time.Minute) != digest(b, time.Minute) {
		t.Fatal("same intent produced different digests")
	}
}

func TestDigestChangesWithEveryFieldThatChangesTheOutcome(t *testing.T) {
	base := reservationRequest{OrderRef: "ord-1", SKU: "FSH-NEON-TETRA", Quantity: 6}
	ttl := 15 * time.Minute
	cases := map[string]struct {
		req reservationRequest
		ttl time.Duration
	}{
		"quantity": {reservationRequest{OrderRef: "ord-1", SKU: "FSH-NEON-TETRA", Quantity: 7}, ttl},
		"sku":      {reservationRequest{OrderRef: "ord-1", SKU: "FSH-CORY-PANDA", Quantity: 6}, ttl},
		"orderRef": {reservationRequest{OrderRef: "ord-2", SKU: "FSH-NEON-TETRA", Quantity: 6}, ttl},
		"ttl":      {base, 30 * time.Minute},
	}
	for name, c := range cases {
		if digest(base, ttl) == digest(c.req, c.ttl) {
			t.Fatalf("a change of %s did not change the digest", name)
		}
	}
}

// The separator exists so that field boundaries cannot be forged by field
// content: without it, ("ord-1", "X") and ("ord", "1X") would hash the same.
func TestDigestSeparatesFields(t *testing.T) {
	a := reservationRequest{OrderRef: "ord-1", SKU: "X", Quantity: 1}
	b := reservationRequest{OrderRef: "ord", SKU: "1X", Quantity: 1}
	if digest(a, time.Minute) == digest(b, time.Minute) {
		t.Fatal("field boundaries are not encoded in the digest")
	}
}
