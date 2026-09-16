package api

import (
	"testing"

	"github.com/google/uuid"

	"github.com/sayanc422/aquahub/services/notification-service/internal/store"
)

func TestBuildEntriesAlwaysQueuesEmailWhenPresent(t *testing.T) {
	req := eventRequest{OrderReference: "ord-1", EventType: store.EventOrderConfirmed, Email: "a@example.com"}
	entries := buildEntries(req, uuid.New(), "")
	if len(entries) != 1 || entries[0].TargetType != store.TargetEmail {
		t.Fatalf("want exactly one email entry, got %+v", entries)
	}
}

func TestBuildEntriesSkipsEmailWhenAbsent(t *testing.T) {
	req := eventRequest{OrderReference: "ord-1", EventType: store.EventOrderConfirmed}
	entries := buildEntries(req, uuid.New(), "")
	if len(entries) != 0 {
		t.Fatalf("want no entries with no email and no webhook configured, got %+v", entries)
	}
}

func TestBuildEntriesAddsWebhookOnlyWhenConfigured(t *testing.T) {
	req := eventRequest{OrderReference: "ord-1", EventType: store.EventOrderConfirmed, Email: "a@example.com"}

	withoutWebhook := buildEntries(req, uuid.New(), "")
	if len(withoutWebhook) != 1 {
		t.Fatalf("want one entry with no webhook URL configured, got %d", len(withoutWebhook))
	}

	withWebhook := buildEntries(req, uuid.New(), "http://staff-notify.internal/hooks")
	if len(withWebhook) != 2 {
		t.Fatalf("want two entries (email + webhook), got %d", len(withWebhook))
	}
	var sawEmail, sawWebhook bool
	for _, e := range withWebhook {
		sawEmail = sawEmail || e.TargetType == store.TargetEmail
		sawWebhook = sawWebhook || e.TargetType == store.TargetWebhook
	}
	if !sawEmail || !sawWebhook {
		t.Fatalf("want one email and one webhook entry, got %+v", withWebhook)
	}
}

// The unique constraint on (order_id, event_type, target_type) is what
// actually makes a retried push idempotent — this only asserts that a retry
// produces the *same* candidate entries, so the DB-level ON CONFLICT has
// something identical to deduplicate. The conflict behaviour itself needs a
// real Postgres and is covered by the store integration test.
func TestBuildEntriesIsDeterministicForARetry(t *testing.T) {
	orderID := uuid.New()
	req := eventRequest{OrderReference: "ord-1", EventType: store.EventOrderConfirmed, Email: "a@example.com"}

	first := buildEntries(req, orderID, "http://staff-notify.internal/hooks")
	second := buildEntries(req, orderID, "http://staff-notify.internal/hooks")
	if len(first) != len(second) {
		t.Fatalf("a retry produced a different number of candidate entries: %d vs %d", len(first), len(second))
	}
	for i := range first {
		if first[i] != second[i] {
			t.Fatalf("entry %d differs between calls: %+v vs %+v", i, first[i], second[i])
		}
	}
}
