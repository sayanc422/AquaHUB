// Package api is the HTTP surface. It translates between JSON and the
// store, and decides which targets an event fans out to; it contains no
// delivery logic of its own — that is internal/notify's job.
package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/sayanc422/aquahub/services/notification-service/internal/config"
	"github.com/sayanc422/aquahub/services/notification-service/internal/obs"
	"github.com/sayanc422/aquahub/services/notification-service/internal/store"
)

type API struct {
	store *store.Store
	cfg   config.Config
	log   *slog.Logger
}

func New(s *store.Store, cfg config.Config, log *slog.Logger) *API {
	return &API{store: s, cfg: cfg, log: log}
}

func (a *API) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /v1/events", a.ingest)

	// Liveness answers from the process alone, the same convention every
	// other service here uses: a database outage must not turn Kubernetes
	// loose restarting every healthy pod.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /readyz", a.ready)
	mux.Handle("GET /metrics", promhttp.Handler())

	return a.withRequestID(a.withObservability(mux))
}

// ---------- request and response shapes ----------

// eventRequest is the published contract with order-service. The JSON is a
// contract another service depends on; the outbox table behind it is this
// service's private business.
type eventRequest struct {
	OrderID        string `json:"orderId"`
	OrderReference string `json:"orderReference"`
	EventType      string `json:"eventType"`
	Email          string `json:"email"`
}

func (a *API) ingest(w http.ResponseWriter, r *http.Request) {
	var req eventRequest
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		obs.EventsIngestedTotal.WithLabelValues("malformed").Inc()
		writeProblem(w, r, http.StatusBadRequest, "malformed_request", err.Error())
		return
	}

	orderID, err := uuid.Parse(req.OrderID)
	if err != nil {
		obs.EventsIngestedTotal.WithLabelValues("invalid_order_id").Inc()
		writeProblem(w, r, http.StatusBadRequest, "invalid_order_id", "orderId must be a uuid")
		return
	}
	if req.OrderReference == "" {
		obs.EventsIngestedTotal.WithLabelValues("invalid_request").Inc()
		writeProblem(w, r, http.StatusBadRequest, "invalid_request", "orderReference is required")
		return
	}
	switch req.EventType {
	case store.EventOrderConfirmed, store.EventOrderDispatchable:
	default:
		obs.EventsIngestedTotal.WithLabelValues("invalid_event_type").Inc()
		writeProblem(w, r, http.StatusBadRequest, "invalid_event_type",
			"eventType must be ORDER_CONFIRMED or ORDER_DISPATCHABLE")
		return
	}

	entries := buildEntries(req, orderID, a.cfg.WebhookURL)
	if len(entries) == 0 {
		// Not an error: order-service always sends an email, but a request
		// with neither an email nor a configured webhook target has nothing
		// to queue, and that is a valid, empty outcome.
		obs.EventsIngestedTotal.WithLabelValues("no_targets").Inc()
		writeJSON(w, http.StatusAccepted, map[string]any{"queued": 0})
		return
	}

	queued, err := a.store.Enqueue(r.Context(), entries)
	if err != nil {
		a.log.Error("enqueue failed", "error", err, "requestId", requestID(r.Context()))
		obs.EventsIngestedTotal.WithLabelValues("error").Inc()
		writeProblem(w, r, http.StatusInternalServerError, "internal_error",
			"the request could not be completed")
		return
	}
	obs.EventsIngestedTotal.WithLabelValues("accepted").Inc()
	writeJSON(w, http.StatusAccepted, map[string]any{"queued": queued})
}

// buildEntries decides which targets one event fans out to. Pure and
// DB-free on purpose: this is the one piece of ingest logic worth a unit
// test on its own, separate from the idempotent-insert behaviour that
// internal/store's ON CONFLICT clause provides and only an integration test
// against real Postgres can actually exercise.
func buildEntries(req eventRequest, orderID uuid.UUID, webhookURL string) []store.NewEntry {
	var entries []store.NewEntry
	if req.Email != "" {
		entries = append(entries, store.NewEntry{
			OrderID: orderID, OrderReference: req.OrderReference,
			EventType: req.EventType, TargetType: store.TargetEmail, Target: req.Email,
		})
	}
	if webhookURL != "" {
		entries = append(entries, store.NewEntry{
			OrderID: orderID, OrderReference: req.OrderReference,
			EventType: req.EventType, TargetType: store.TargetWebhook, Target: webhookURL,
		})
	}
	return entries
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := a.store.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "unready", "reason": "database unreachable",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ---------- helpers ----------

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

type problem struct {
	Error     string `json:"error"`
	Message   string `json:"message"`
	RequestID string `json:"requestId,omitempty"`
}

func writeProblem(w http.ResponseWriter, r *http.Request, status int, code, msg string) {
	writeJSON(w, status, problem{Error: code, Message: msg, RequestID: requestID(r.Context())})
}
