// Package notify delivers one outbox entry to its target.
//
// Both senders here are stubs. "Email and webhook targets — external,
// stubbed locally" is the design stated in docs/architecture.md's actor
// list, not a shortcut taken here: this service has no SMTP relay and no
// real downstream webhook consumer to call, the same honesty
// payment-service applies to its acquirer.
package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/sayanc422/aquahub/services/notification-service/internal/store"
)

// Sender delivers one entry and returns an error if delivery did not happen.
type Sender interface {
	Send(ctx context.Context, e store.Entry) error
}

// LoggingEmailSender "delivers" an email by writing a structured log line.
// There is no SMTP relay configured anywhere in this repository; pretending
// to send a real email would be a claim nothing here can back up.
type LoggingEmailSender struct {
	Log *slog.Logger
}

func (s *LoggingEmailSender) Send(_ context.Context, e store.Entry) error {
	s.Log.Info("email delivered (stub)",
		"order", e.OrderReference, "event", e.EventType, "to", e.Target)
	return nil
}

// WebhookSender POSTs a small JSON payload to a configured URL. With no URL
// configured it behaves exactly like the email stub — a log line and
// nothing else — because there is no external webhook consumer in this
// repository to call by default.
type WebhookSender struct {
	Log    *slog.Logger
	HTTP   *http.Client
	Target string // empty means "log only", same as the email stub
}

type webhookPayload struct {
	OrderReference string `json:"orderReference"`
	EventType      string `json:"eventType"`
}

func (s *WebhookSender) Send(ctx context.Context, e store.Entry) error {
	if s.Target == "" {
		s.Log.Info("webhook delivered (stub, no target configured)",
			"order", e.OrderReference, "event", e.EventType)
		return nil
	}

	body, err := json.Marshal(webhookPayload{OrderReference: e.OrderReference, EventType: e.EventType})
	if err != nil {
		return fmt.Errorf("encode webhook payload: %w", err)
	}
	reqCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, s.Target, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build webhook request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("webhook post: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("webhook target returned %d", resp.StatusCode)
	}
	s.Log.Info("webhook delivered", "order", e.OrderReference, "event", e.EventType, "target", s.Target)
	return nil
}
