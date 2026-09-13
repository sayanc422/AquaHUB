// Package api is the HTTP surface. It translates between JSON and the domain
// and decides status codes; it contains no stock rules of its own.
package api

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/sayanc422/aquahub/services/inventory-service/internal/config"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/inventory"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/obs"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/store"
)

type API struct {
	store *store.Store
	cfg   config.Config
	log   *slog.Logger
}

func New(s *store.Store, cfg config.Config, log *slog.Logger) *API {
	return &API{store: s, cfg: cfg, log: log}
}

// Routes builds the mux. Patterns carry the method (Go 1.22 routing), so a GET
// to a POST-only path is a 405 from the router rather than a handler that has
// to check.
func (a *API) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /v1/reservations", a.create)
	mux.HandleFunc("GET /v1/reservations/{id}", a.get)
	mux.HandleFunc("POST /v1/reservations/{id}/commit", a.commit)
	mux.HandleFunc("POST /v1/reservations/{id}/release", a.release)
	mux.HandleFunc("DELETE /v1/reservations/{id}", a.release)
	mux.HandleFunc("GET /v1/stock/{sku}", a.stock)

	// Liveness answers from the process alone. It must not touch Postgres: if
	// it did, a database outage would make Kubernetes restart every healthy
	// pod in a loop and turn a degraded service into a missing one. Readiness
	// does check, because a pod that cannot reach its database should leave
	// the Service endpoints.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /readyz", a.ready)
	mux.Handle("GET /metrics", promhttp.Handler())

	return a.withRequestID(a.withObservability(mux))
}

// ---------- request and response shapes ----------

// reservationRequest is the published contract. The JSON is a contract other
// services depend on; the table behind it is this service's private business.
type reservationRequest struct {
	OrderRef   string `json:"orderRef"`
	SKU        string `json:"sku"`
	Quantity   int    `json:"quantity"`
	TTLSeconds int    `json:"ttlSeconds,omitempty"`
}

type reservationResponse struct {
	ID        string       `json:"id"`
	OrderRef  string       `json:"orderRef"`
	SKU       string       `json:"sku"`
	Quantity  int          `json:"quantity"`
	State     string       `json:"state"`
	ExpiresAt time.Time    `json:"expiresAt"`
	CreatedAt time.Time    `json:"createdAt"`
	Lines     []store.Line `json:"tanks"`
}

func view(r *store.Reservation) reservationResponse {
	return reservationResponse{
		ID:        r.ID.String(),
		OrderRef:  r.OrderRef,
		SKU:       r.SKU,
		Quantity:  r.Quantity,
		State:     r.State,
		ExpiresAt: r.ExpiresAt.UTC(),
		CreatedAt: r.CreatedAt.UTC(),
		Lines:     r.Lines,
	}
}

// ---------- handlers ----------

func (a *API) create(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" {
		// Mandatory, not optional. A reservation is not safe to repeat, the
		// network will repeat it, and a caller that has not thought about its
		// retry key has not thought about double-booking a fish.
		writeProblem(w, r, http.StatusBadRequest, "missing_idempotency_key",
			"the Idempotency-Key header is required on reservation requests")
		return
	}
	if len(key) > 128 {
		writeProblem(w, r, http.StatusBadRequest, "idempotency_key_too_long",
			"Idempotency-Key must be 128 characters or fewer")
		return
	}

	var req reservationRequest
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeProblem(w, r, http.StatusBadRequest, "malformed_request", err.Error())
		return
	}
	if req.OrderRef == "" || req.SKU == "" {
		writeProblem(w, r, http.StatusBadRequest, "invalid_request", "orderRef and sku are required")
		return
	}
	if req.Quantity <= 0 || req.Quantity > 500 {
		writeProblem(w, r, http.StatusBadRequest, "invalid_quantity",
			"quantity must be between 1 and 500")
		return
	}

	ttl := a.cfg.DefaultTTL
	if req.TTLSeconds > 0 {
		ttl = time.Duration(req.TTLSeconds) * time.Second
	}
	if ttl > a.cfg.MaxTTL {
		// An unbounded hold is stock nobody can sell and nobody will reclaim.
		writeProblem(w, r, http.StatusBadRequest, "ttl_too_long",
			fmt.Sprintf("ttlSeconds must not exceed %d", int(a.cfg.MaxTTL.Seconds())))
		return
	}

	res, replayed, err := a.store.Reserve(r.Context(), store.NewRequest{
		IdempotencyKey: key,
		RequestDigest:  digest(req, ttl),
		OrderRef:       req.OrderRef,
		SKU:            req.SKU,
		Quantity:       req.Quantity,
		TTL:            ttl,
	})
	switch {
	case errors.Is(err, inventory.ErrInsufficientStock):
		obs.ReservationsTotal.WithLabelValues("insufficient_stock").Inc()
		writeProblem(w, r, http.StatusConflict, "insufficient_stock",
			"not enough unreserved stock in open tanks for this sku")
		return
	case errors.Is(err, store.ErrIdempotencyConflict):
		obs.ReservationsTotal.WithLabelValues("idempotency_conflict").Inc()
		writeProblem(w, r, http.StatusConflict, "idempotency_key_reused",
			"this Idempotency-Key was used for a different request")
		return
	case err != nil:
		a.fail(w, r, "reserve", err)
		return
	}

	if replayed {
		obs.ReservationsTotal.WithLabelValues("replayed").Inc()
		writeJSON(w, http.StatusOK, view(res))
		return
	}
	obs.ReservationsTotal.WithLabelValues("created").Inc()
	w.Header().Set("Location", "/v1/reservations/"+res.ID.String())
	writeJSON(w, http.StatusCreated, view(res))
}

func (a *API) get(w http.ResponseWriter, r *http.Request) {
	id, ok := a.pathID(w, r)
	if !ok {
		return
	}
	res, err := a.store.Get(r.Context(), id)
	if err != nil {
		a.fail(w, r, "get", err)
		return
	}
	writeJSON(w, http.StatusOK, view(res))
}

func (a *API) commit(w http.ResponseWriter, r *http.Request) {
	id, ok := a.pathID(w, r)
	if !ok {
		return
	}
	res, err := a.store.Commit(r.Context(), id)
	switch {
	case errors.Is(err, store.ErrExpired):
		obs.ReservationsTotal.WithLabelValues("commit_expired").Inc()
		writeProblem(w, r, http.StatusConflict, "reservation_expired",
			"the hold expired before it was committed; reserve again")
		return
	case errors.Is(err, store.ErrStateConflict):
		writeProblem(w, r, http.StatusConflict, "invalid_state",
			"a released reservation cannot be committed")
		return
	case err != nil:
		a.fail(w, r, "commit", err)
		return
	}
	obs.ReservationsTotal.WithLabelValues("committed").Inc()
	writeJSON(w, http.StatusOK, view(res))
}

func (a *API) release(w http.ResponseWriter, r *http.Request) {
	id, ok := a.pathID(w, r)
	if !ok {
		return
	}
	res, err := a.store.Release(r.Context(), id)
	switch {
	case errors.Is(err, store.ErrStateConflict):
		writeProblem(w, r, http.StatusConflict, "invalid_state",
			"a committed reservation cannot be released; a reversal is a refund, not a release")
		return
	case err != nil:
		a.fail(w, r, "release", err)
		return
	}
	obs.ReservationsTotal.WithLabelValues("released").Inc()
	writeJSON(w, http.StatusOK, view(res))
}

func (a *API) stock(w http.ResponseWriter, r *http.Request) {
	sku := r.PathValue("sku")
	tanks, err := a.store.Stock(r.Context(), sku)
	if err != nil {
		a.fail(w, r, "stock", err)
		return
	}
	if len(tanks) == 0 {
		writeProblem(w, r, http.StatusNotFound, "unknown_sku", "no tank holds this sku")
		return
	}
	total := 0
	for _, t := range tanks {
		total += t.Available
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"sku":            sku,
		"totalAvailable": total,
		"tanks":          tanks,
	})
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

func (a *API) pathID(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeProblem(w, r, http.StatusBadRequest, "invalid_id", "reservation id must be a uuid")
		return uuid.Nil, false
	}
	return id, true
}

// fail is the single place an unexpected error becomes a response. The detail
// goes to the log with the request id; the client gets the id and nothing else,
// because a database error message is a map of the schema.
func (a *API) fail(w http.ResponseWriter, r *http.Request, op string, err error) {
	if errors.Is(err, store.ErrNotFound) {
		writeProblem(w, r, http.StatusNotFound, "not_found", "no such reservation")
		return
	}
	a.log.Error("request failed", "op", op, "error", err, "requestId", requestID(r.Context()))
	obs.ReservationsTotal.WithLabelValues("error").Inc()
	writeProblem(w, r, http.StatusInternalServerError, "internal_error",
		"the request could not be completed")
}

// digest binds an idempotency key to the request it was used for. Canonical
// form, not the raw bytes: the same intent re-serialised with different key
// order or whitespace is still the same intent, and a retry through a proxy
// that reformats JSON must not read as a conflict.
func digest(req reservationRequest, ttl time.Duration) string {
	canonical := strings.Join([]string{
		req.OrderRef, req.SKU,
		strconv.Itoa(req.Quantity),
		strconv.Itoa(int(ttl.Seconds())),
	}, "\x1f")
	sum := sha256.Sum256([]byte(canonical))
	return hex.EncodeToString(sum[:])
}

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
