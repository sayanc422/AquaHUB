package store

import (
	"context"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"log/slog"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

// Migrate applies every unapplied migration in filename order.
//
// catalog-service uses Flyway; this is the same contract in 60 lines of Go
// rather than a 15 MB dependency: an ordered, immutable, checksummed history
// table, applied inside one transaction per file.
//
// The advisory lock matters. Migrations run at pod startup, and a rolling
// update or a replicas>1 deployment starts several pods at once. Without the
// lock two pods run CREATE TABLE concurrently and one crash-loops on
// "relation already exists" — which reads as a broken image, not a race.
func Migrate(ctx context.Context, pool *pgxpool.Pool, log *slog.Logger) error {
	conn, err := pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("acquire migration connection: %w", err)
	}
	defer conn.Release()

	const lockID = 0x4151_5548 // "AQUH"
	if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock($1)`, lockID); err != nil {
		return fmt.Errorf("take migration lock: %w", err)
	}
	defer func() {
		if _, err := conn.Exec(context.WithoutCancel(ctx), `SELECT pg_advisory_unlock($1)`, lockID); err != nil {
			log.Error("release migration lock", "error", err)
		}
	}()

	if _, err := conn.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename    TEXT PRIMARY KEY,
			checksum    CHAR(64)    NOT NULL,
			applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
		)`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	applied := map[string]string{}
	rows, err := conn.Query(ctx, `SELECT filename, checksum FROM schema_migrations`)
	if err != nil {
		return fmt.Errorf("read schema_migrations: %w", err)
	}
	for rows.Next() {
		var name, sum string
		if err := rows.Scan(&name, &sum); err != nil {
			rows.Close()
			return err
		}
		applied[name] = sum
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	entries, err := migrationFS.ReadDir("migrations")
	if err != nil {
		return err
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)

	for _, name := range names {
		body, err := migrationFS.ReadFile("migrations/" + name)
		if err != nil {
			return err
		}
		sum := sha256.Sum256(body)
		checksum := hex.EncodeToString(sum[:])

		if prev, ok := applied[name]; ok {
			// An edited migration means the running schema and the repository
			// have diverged. Continuing would apply later files onto a schema
			// nobody can describe, so refuse to start.
			if prev != checksum {
				return fmt.Errorf("migration %s was modified after it was applied (checksum %s, expected %s)", name, checksum, prev)
			}
			continue
		}

		log.Info("applying migration", "file", name)
		err = pgx.BeginFunc(ctx, conn, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, string(body)); err != nil {
				return fmt.Errorf("apply %s: %w", name, err)
			}
			_, err := tx.Exec(ctx,
				`INSERT INTO schema_migrations (filename, checksum) VALUES ($1, $2)`, name, checksum)
			return err
		})
		if err != nil {
			return err
		}
	}
	return nil
}
