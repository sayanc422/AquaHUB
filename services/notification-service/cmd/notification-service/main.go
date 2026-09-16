// Command notification-service delivers email and webhook notifications for
// events order-service has already decided happened.
//
// It is pushed to, not subscribed to a broker: order-service calls this
// service's ingest endpoint, fire-and-forget, at the moment it already knows
// something changed (an order confirmed, a dispatch window opened). See
// docs/adr/0020-push-not-subscribe-until-phase-6.md for why, and what
// replaces this once NATS exists.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sayanc422/aquahub/services/notification-service/internal/api"
	"github.com/sayanc422/aquahub/services/notification-service/internal/config"
	"github.com/sayanc422/aquahub/services/notification-service/internal/notify"
	"github.com/sayanc422/aquahub/services/notification-service/internal/obs"
	"github.com/sayanc422/aquahub/services/notification-service/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(log)

	if err := run(log); err != nil {
		log.Error("fatal", "error", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return err
	}
	poolCfg.MaxConns = cfg.PoolMaxConns
	poolCfg.MaxConnIdleTime = 5 * time.Minute
	poolCfg.MaxConnLifetime = time.Hour

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	startupCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	if err := waitForDatabase(startupCtx, pool, log); err != nil {
		return err
	}
	if err := store.Migrate(startupCtx, pool, log); err != nil {
		return err
	}

	st := store.New(pool)
	senders := map[string]notify.Sender{
		store.TargetEmail:   &notify.LoggingEmailSender{Log: log},
		store.TargetWebhook: &notify.WebhookSender{Log: log, HTTP: &http.Client{}, Target: cfg.WebhookURL},
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           api.New(st, cfg, log).Routes(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	senderDone := make(chan struct{})
	go func() {
		defer close(senderDone)
		runSender(ctx, st, senders, cfg.PollInterval, cfg.MaxAttempts, log)
	}()

	serverErr := make(chan error, 1)
	go func() {
		log.Info("listening", "port", cfg.Port, "pollInterval", cfg.PollInterval.String(),
			"webhookConfigured", cfg.WebhookURL != "")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	select {
	case err := <-serverErr:
		return err
	case <-ctx.Done():
		log.Info("shutting down", "grace", cfg.ShutdownGrace.String())
	}

	shutdownCtx, cancelShutdown := context.WithTimeout(context.WithoutCancel(ctx), cfg.ShutdownGrace)
	defer cancelShutdown()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown timed out; connections were cut", "error", err)
	}
	<-senderDone
	log.Info("stopped")
	return nil
}

func waitForDatabase(ctx context.Context, pool *pgxpool.Pool, log *slog.Logger) error {
	backoff := 500 * time.Millisecond
	for attempt := 1; ; attempt++ {
		if err := pool.Ping(ctx); err == nil {
			return nil
		} else if ctx.Err() != nil {
			return errors.New("database not reachable within the startup window: " + err.Error())
		} else {
			log.Warn("database not ready", "attempt", attempt, "error", err, "retryIn", backoff.String())
		}
		select {
		case <-ctx.Done():
			return errors.New("database not reachable within the startup window")
		case <-time.After(backoff):
		}
		if backoff < 5*time.Second {
			backoff *= 2
		}
	}
}

// runSender is the only thing in this service that is even close to
// load-bearing, and it still isn't: per ADR 0011's reasoning, a stopped
// sender delays a notification, it never corrupts an order. It claims a
// batch of pending rows, hands each to the sender for its target type, and
// records the outcome.
func runSender(ctx context.Context, st *store.Store, senders map[string]notify.Sender,
	interval time.Duration, maxAttempts int, log *slog.Logger) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			runCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			deliverBatch(runCtx, st, senders, maxAttempts, log)
			cancel()
		}
	}
}

func deliverBatch(ctx context.Context, st *store.Store, senders map[string]notify.Sender,
	maxAttempts int, log *slog.Logger) {
	entries, err := st.ClaimPending(ctx, 50)
	if err != nil {
		log.Error("claim pending outbox rows failed", "error", err)
		return
	}
	obs.PendingOutbox.Set(float64(len(entries)))

	for _, e := range entries {
		sender, ok := senders[e.TargetType]
		if !ok {
			log.Error("no sender configured for target type", "targetType", e.TargetType, "id", e.ID)
			continue
		}
		if err := sender.Send(ctx, e); err != nil {
			obs.DeliveriesTotal.WithLabelValues(e.TargetType, "failed").Inc()
			if markErr := st.MarkAttemptFailed(ctx, e.ID, err.Error(), maxAttempts); markErr != nil {
				log.Error("record delivery failure failed", "error", markErr, "id", e.ID)
			}
			log.Warn("delivery failed", "id", e.ID, "order", e.OrderReference,
				"targetType", e.TargetType, "attempt", e.Attempts+1, "error", err)
			continue
		}
		obs.DeliveriesTotal.WithLabelValues(e.TargetType, "sent").Inc()
		if err := st.MarkSent(ctx, e.ID); err != nil {
			log.Error("record delivery success failed", "error", err, "id", e.ID)
		}
	}
}
