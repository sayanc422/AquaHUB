// Command inventory-service holds stock in physical tanks, on behalf of orders
// that have not been paid for yet.
//
// The whole service is one idea: a promise about stock is time-bounded. Nothing
// here can hold a fish indefinitely, and no background job has to be healthy for
// that to be true.
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

	"github.com/sayanc422/aquahub/services/inventory-service/internal/api"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/config"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/obs"
	"github.com/sayanc422/aquahub/services/inventory-service/internal/store"
)

func main() {
	// JSON to stdout. The container writes to stdout and the platform owns
	// collection; a service that manages its own log files needs a writable
	// filesystem and a rotation policy, and this one has neither.
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

	// SIGTERM is what Kubernetes sends first. Everything below hangs off this
	// context, so one signal unwinds the reaper, the pool and the server.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return err
	}
	poolCfg.MaxConns = cfg.PoolMaxConns
	// Well under Postgres's own idle timeout, so the pool closes connections
	// before the server does and no request ever picks up a dead one.
	poolCfg.MaxConnIdleTime = 5 * time.Minute
	poolCfg.MaxConnLifetime = time.Hour

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	// Startup blocks on the database. The startup probe carries this window;
	// a service that starts without its schema only fails later, in a request.
	startupCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	if err := waitForDatabase(startupCtx, pool, log); err != nil {
		return err
	}
	if err := store.Migrate(startupCtx, pool, log); err != nil {
		return err
	}

	st := store.New(pool)
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: api.New(st, cfg, log).Routes(),
		// A client that opens a connection and sends nothing must not be able
		// to hold a file descriptor open forever.
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	reaperDone := make(chan struct{})
	go func() {
		defer close(reaperDone)
		runReaper(ctx, st, cfg.ReaperInterval, log)
	}()

	serverErr := make(chan error, 1)
	go func() {
		log.Info("listening", "port", cfg.Port, "defaultTTL", cfg.DefaultTTL.String(),
			"reaperInterval", cfg.ReaperInterval.String())
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

	// context.WithoutCancel: the signal has already cancelled ctx, and the
	// shutdown must still get its full grace period to drain in-flight
	// reservations. Deriving from a cancelled context would make this return
	// instantly and cut those requests.
	shutdownCtx, cancelShutdown := context.WithTimeout(context.WithoutCancel(ctx), cfg.ShutdownGrace)
	defer cancelShutdown()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown timed out; connections were cut", "error", err)
	}
	<-reaperDone
	log.Info("stopped")
	return nil
}

// waitForDatabase retries until the pod's startup probe window runs out.
//
// Postgres and this service come up together, and a pod that exits because its
// database was two seconds behind is a crash loop that looks like a bug.
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

// runReaper marks expired holds expired, on a tick.
//
// It is deliberately not load-bearing. Availability already ignores a hold past
// its deadline, so a reaper that is stopped, slow or crash-looping cannot cause
// stock to be double-sold or stranded — it only makes the state column and the
// gauge stale. That is the property that makes this safe to run in every
// replica: two reapers doing the same UPDATE is a wasted write, not a race.
func runReaper(ctx context.Context, st *store.Store, interval time.Duration, log *slog.Logger) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			runCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			n, err := st.ExpireDue(runCtx)
			if err != nil {
				cancel()
				log.Error("reaper pass failed", "error", err)
				continue
			}
			if n > 0 {
				obs.ExpiredTotal.Add(float64(n))
				log.Info("expired holds returned to stock", "count", n)
			}
			if held, err := st.ActiveHolds(runCtx); err == nil {
				obs.ActiveHolds.Set(float64(held))
			}
			cancel()
		}
	}
}
