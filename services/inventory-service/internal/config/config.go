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
	Port           string
	DatabaseURL    string
	DefaultTTL     time.Duration
	MaxTTL         time.Duration
	ReaperInterval time.Duration
	PoolMaxConns   int32
	ShutdownGrace  time.Duration
}

// Load fails fast rather than starting with a half-configured service. A pod
// that crash-loops on a missing variable is a five-second diagnosis; one that
// starts and then answers wrongly is an afternoon.
func Load() (Config, error) {
	c := Config{
		Port:           env("PORT", "8081"),
		DefaultTTL:     dur("RESERVATION_TTL", 15*time.Minute),
		MaxTTL:         dur("RESERVATION_MAX_TTL", 2*time.Hour),
		ReaperInterval: dur("REAPER_INTERVAL", 30*time.Second),
		PoolMaxConns:   int32(num("DB_POOL_MAX", 8)),
		// Longer than the longest expected request so in-flight reservations
		// finish, shorter than the Kubernetes grace period so the process
		// chooses its own exit instead of taking SIGKILL.
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
			env("DB_USER", "inventory"), pw, host, env("DB_PORT", "5432"),
			env("DB_NAME", "inventory"), env("DB_SSLMODE", "disable"))
	}

	if c.MaxTTL < c.DefaultTTL {
		return c, fmt.Errorf("RESERVATION_MAX_TTL (%s) is below RESERVATION_TTL (%s)", c.MaxTTL, c.DefaultTTL)
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
