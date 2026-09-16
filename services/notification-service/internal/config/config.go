// Package config reads the service's settings from the environment.
//
// Everything is a ConfigMap key except the password, which is a Secret key, and
// nothing is read from a file on disk: the container's root filesystem is
// read-only and a config file would need a writable mount to be useful.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Port          string
	DatabaseURL   string
	WebhookURL    string
	PollInterval  time.Duration
	MaxAttempts   int
	PoolMaxConns  int32
	ShutdownGrace time.Duration
}

// Load fails fast rather than starting with a half-configured service. A pod
// that crash-loops on a missing variable is a five-second diagnosis; one that
// starts and then answers wrongly is an afternoon.
func Load() (Config, error) {
	c := Config{
		Port:         env("PORT", "8085"),
		WebhookURL:   env("NOTIFICATION_WEBHOOK_URL", ""),
		PollInterval: dur("NOTIFICATION_POLL_INTERVAL", 5*time.Second),
		MaxAttempts:  num("NOTIFICATION_MAX_ATTEMPTS", 5),
		PoolMaxConns: int32(num("DB_POOL_MAX", 4)),
		// Longer than the longest expected request so in-flight sends finish,
		// shorter than the Kubernetes grace period so the process chooses its
		// own exit instead of taking SIGKILL.
		ShutdownGrace: dur("SHUTDOWN_GRACE", 15*time.Second),
	}

	host := env("DB_HOST", "")
	if url := os.Getenv("DATABASE_URL"); url != "" {
		c.DatabaseURL = url
	} else {
		if host == "" {
			return c, fmt.Errorf("either DATABASE_URL or DB_HOST must be set")
		}
		pw := os.Getenv("DB_PASSWORD")
		if pw == "" {
			return c, fmt.Errorf("DB_PASSWORD is not set")
		}
		c.DatabaseURL = fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=%s",
			env("DB_USER", "notify"), pw, host, env("DB_PORT", "5432"),
			env("DB_NAME", "notify"), env("DB_SSLMODE", "disable"))
	}

	if c.MaxAttempts < 1 {
		return c, fmt.Errorf("NOTIFICATION_MAX_ATTEMPTS must be at least 1")
	}
	return c, nil
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func dur(k string, def time.Duration) time.Duration {
	if v := os.Getenv(k); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}

func num(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
