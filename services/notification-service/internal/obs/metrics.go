// Package obs holds the service's metrics.
package obs

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// "Are pushes from order-service arriving, and being queued?"
	EventsIngestedTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "notification_events_ingested_total",
		Help: "POST /v1/events calls by outcome.",
	}, []string{"outcome"})

	// "Are deliveries succeeding, and to which target type?"
	DeliveriesTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "notification_deliveries_total",
		Help: "Delivery attempts by target type and outcome.",
	}, []string{"target_type", "outcome"})

	// "How much is backed up right now?" The gauge worth alerting on: a
	// growing queue with a healthy sender means the target is refusing
	// delivery, not that this service is slow.
	PendingOutbox = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "notification_outbox_pending",
		Help: "Outbox rows still awaiting delivery.",
	})

	RequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "notification_http_request_duration_seconds",
		Help:    "HTTP request duration.",
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.15, 0.3, 1, 3},
	}, []string{"route", "method", "status"})
)
