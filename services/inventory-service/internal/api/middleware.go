package api

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/sayanc422/aquahub/services/inventory-service/internal/obs"
)

type ctxKey int

const requestIDKey ctxKey = iota

// withRequestID honours an inbound X-Request-Id and mints one otherwise.
//
// The storefront BFF already propagates this header, so one customer action can
// be followed across the BFF, the order service and this one in a log query.
// Phase 6 replaces the header with a W3C traceparent and real spans; until
// then this is the cheapest thing that makes logs joinable.
func (a *API) withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if id == "" || len(id) > 64 {
			id = uuid.NewString()
		}
		w.Header().Set("X-Request-Id", id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), requestIDKey, id)))
	})
}

func requestID(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}

type recorder struct {
	http.ResponseWriter
	status int
}

func (rec *recorder) WriteHeader(code int) {
	rec.status = code
	rec.ResponseWriter.WriteHeader(code)
}

func (a *API) withObservability(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/metrics" || r.URL.Path == "/healthz" {
			// Probes and scrapes outnumber real traffic on an idle service and
			// would dominate both the histogram and the log.
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		rec := &recorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		elapsed := time.Since(start)

		// The route *pattern*, never the raw path. Labelling by path would put
		// one time series per reservation uuid into Prometheus, which is how a
		// metrics backend dies on a laptop.
		route := r.Pattern
		if route == "" {
			route = "unmatched"
		}
		obs.RequestDuration.
			WithLabelValues(route, r.Method, strconv.Itoa(rec.status)).
			Observe(elapsed.Seconds())

		a.log.Info("request",
			"method", r.Method, "route", route, "status", rec.status,
			"durationMs", elapsed.Milliseconds(), "requestId", requestID(r.Context()))
	})
}
