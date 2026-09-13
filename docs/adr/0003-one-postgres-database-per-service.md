# 3. One Postgres instance, one database and login role per service

**Status:** Accepted · **Phase:** 1

## Context

The data-ownership rule is one database per service: no shared schema, no cross-service joins, no
foreign keys across a service boundary. The target is one RDS instance per service. Eight Postgres
StatefulSets would cost roughly 1.1 GB that this machine does not have.

## Decision

One Postgres StatefulSet. One logical database and one login role per service, each role holding
`CONNECT` on its own database only.

## Consequences

The ownership rule is kept where it matters: no service can read another's tables, so no schema
becomes a shared interface by accident. Credential isolation is faithful to the target.

**Cost:** blast-radius isolation is lost. One restart takes every service down, which per-service
RDS would not, and a runaway query in one service competes for the same buffer cache as the rest.
This is the local divergence that would matter most in production.
