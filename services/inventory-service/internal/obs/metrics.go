// Package obs holds the service's metrics.
//
// Four series, each of which answers a question somebody actually asks during
// an incident. A dashboard of everything the runtime exposes answers none of
// them, and every series costs cardinality in a Prometheus that shares this
// laptop's memory with the thing it is watching.
package obs

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// "Are we refusing reservations, and why?" — outcome, not just a count.
	ReservationsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "inventory_reservations_total",
		Help: "Reservation attempts by outcome.",
	}, []string{"outcome"})

	// "Are carts being abandoned, or is the TTL too short?" A rising expiry
	// rate with flat sales is the signal that the hold window is wrong.
	ExpiredTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "inventory_reservations_expired_total",
		Help: "Holds that reached their deadline without being committed or released.",
	})

	// "How much stock is promised but not sold right now?" The gauge the shop
	// floor cares about, and the one that must fall back to zero overnight.
	ActiveHolds = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "inventory_active_holds",
		Help: "Reservations currently holding stock.",
	})

	// "Is it slow, and is it slow for everyone or only for writes?"
	RequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "inventory_http_request_duration_seconds",
		Help: "HTTP request duration.",
		// Buckets sized for the SLO in docs/slo.md (p99 under 150 ms for a
		// reservation), not for the library default, which has no bucket edge
		// anywhere near the number this service is judged on.
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.15, 0.3, 1, 3},
	}, []string{"route", "method", "status"})
)
