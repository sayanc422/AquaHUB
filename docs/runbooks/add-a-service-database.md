# A new service cannot find its database

**Symptom:** a newly deployed service crash-loops. Its logs show `database "inventory" does not
exist`, or `role "inventory" does not exist`, against a Postgres that is otherwise healthy.

## Why this happens

`platform-repo/dev/postgres/init-configmap.yaml` creates one role and one database per service. The
Postgres image runs that script **once, on an empty data directory**. On a cluster whose PVC
already holds data, adding a service to the ConfigMap changes nothing — the script is never run
again.

This is deliberate. The alternative, a bootstrap that recreates the volume so the init script runs,
would make "add a service" mean "lose every order in dev".

## Fix, on a cluster with data worth keeping

Run the same statements by hand, as the superuser:

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- psql -U postgres <<'SQL'
CREATE ROLE inventory LOGIN PASSWORD 'devinventory';
CREATE DATABASE inventory OWNER inventory;
REVOKE ALL ON DATABASE inventory FROM PUBLIC;
GRANT CONNECT ON DATABASE inventory TO inventory;
SQL
```

The password must match `INVENTORY_PASSWORD` in `platform-repo/dev/postgres/secret.yaml`. The
`REVOKE` matters: without it, `PUBLIC` keeps `CONNECT`, and every other service's role can reach
this database — which is the one property the one-database-per-service rule exists to provide
([ADR 0003](../adr/0003-one-postgres-database-per-service.md)).

The service then starts on its own — it retries the connection with backoff for 60 s, inside its
startup probe window, rather than exiting on the first refusal.

## Fix, on a throwaway cluster

```bash
./scripts/bootstrap.sh --destroy && ./scripts/bootstrap.sh --profile commerce
```

## Verify

```bash
kubectl -n aquashop-dev exec -it statefulset/postgres -- \
  psql -U postgres -c "\l" -c "\du"
kubectl -n aquashop-dev rollout status deployment/inventory-service
```

Schema creation is not part of this. Each service migrates its own database at startup —
`catalog-service` with Flyway, `inventory-service` with the embedded runner in
`internal/store/migrate.go`, which takes a Postgres advisory lock so several starting pods cannot
run `CREATE TABLE` concurrently.

## In the AWS target

This runbook does not exist: each service gets its own RDS instance from Terraform, with credentials
in Secrets Manager read through IRSA. The manual step is an artefact of sharing one Postgres to fit
the memory budget, and it is the clearest day-to-day cost of that decision.
