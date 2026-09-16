# staff-portal

Jakarta EE on WildFly. Plain Servlets and JSP, no Spring -- deliberately the odd one out in this
platform. `docs/architecture.md` names the reason directly: this service exists to be "the
slow-start WAR exercise" -- containerising an application server correctly (startup probes, console
logging, a numeric non-root UID, graceful shutdown) is what "connects this project to production
work," and a Spring Boot fat jar would just make this a seventh copy of a pattern the platform
already has six of.

## What it does

Three read-only pages, each a thin JSP over an existing backend read API, called with a bounded
`java.net.http.HttpClient` (JDK-native, no framework) at a 2s timeout matching storefront's own
upstream-call discipline:

- **`/orders`** -- look up one order by reference or id (`OrderClient`), with its line items and
  full event trail.
- **`/stock`** -- tank-by-tank availability for one SKU (`InventoryClient`).
- **`/catalog`** -- browse the category tree and product/species detail (`CatalogClient`).

`/healthz` answers from the process alone (liveness). `/readyz` pings all three backends with a
short bound and fails if any is unreachable (readiness) -- the same liveness-doesn't-call-out /
readiness-does split as storefront's `/healthz` and `/readyz`.

## What it deliberately does not do

`docs/architecture.md`'s actor description says staff "manage tanks, stock, claims and species
content" through this portal. That is the target, not what v1 builds, and the gap is real rather
than glossed over:

- **No stock adjustment.** `inventory-service` has no write endpoint beyond the reservation
  lifecycle (`POST /v1/reservations`, `.../commit`, `.../release`) -- there is no restock/admin
  route to call.
- **No species editing.** `catalog-service` has no write endpoint at all; every product and care
  profile is seeded once by Flyway. There is nothing for a form here to submit to.
- **No claims workflow.** A DOA-claims model (`docs/architecture.md`'s "claims workflow with photo
  evidence and a compensating refund") doesn't exist anywhere in this codebase yet -- it's an
  architecture-doc aspiration, not a built feature on any service. Building it would be new backend
  work on order-service, not a staff-portal page.
- **No order list.** `order-service`'s `OrderController` exposes get-by-id, get-by-reference and
  the event trail -- no endpoint returns "every order." The `/orders` page is lookup-only, by
  design of the backend it calls, not a limitation invented here.

Adding real write capability to any of the above means adding the write endpoint to that service
first. That's future work, named here rather than silently missing.

## Why WildFly, and what that actually costs

Not distroless, and not even `python:3.11-slim`-minimal like `aquatics-advisor`. A full JBoss/WildFly
install ships a shell and a package manager -- the largest attack surface in this platform. The
`securityContext` compensates as far as it can (non-root, `allowPrivilegeEscalation: false`, all
capabilities dropped), but unlike every distroless Go/Rust service here, its root filesystem is
**not** read-only: WildFly writes deployment markers and runtime state under its own install
directory even after the logging change below, the same way the JVM services need a writable
`/tmp` and the Go services don't.

**Console logging is not automatic.** WildFly's default `standalone.xml` logs to
`standalone/log/server.log`, not stdout -- Kubernetes only ever sees container stdout/stderr, so
without the `jboss-cli.sh` logging-subsystem change baked into the Dockerfile, every log line this
service ever wrote would be invisible to `kubectl logs`. This is the concrete thing
"stdout logging" in `docs/architecture.md`'s phase description means, not a given.

**Boot time is measured standalone, not yet in k3d; memory is still unmeasured anywhere.** Run
directly with `docker run` (not through Kubernetes), this image boots cleanly in **~2.8 s** -- one
data point, not a load test, and not the "slow-start" `docs/architecture.md`'s framing implied.
Memory has never been measured, in or out of a cluster. The startup probe (`40 x 5s`) and the
resource requests/limits in `platform-repo/dev/staff-portal/deployment.yaml` remain first estimates,
explicitly marked as such in that file's comments -- correct them against `kubectl top pods` /
`kubectl rollout status` once `full-app` actually runs in k3d, the same way `catalog-service`'s JVM
figures were corrected after its first one. As of this writing `full-app` has not: three attempts
were blocked by this machine's unconfigured WSL2 memory ceiling before a single pod deployed (see
`RELEASE-NOTES.md`), so this container's in-cluster behaviour is still unverified.

## Configuration

| Variable | Default | |
|---|---|---|
| `CATALOG_BASE_URL` | `http://catalog-service:8080` | |
| `INVENTORY_BASE_URL` | `http://inventory-service:8081` | |
| `ORDER_BASE_URL` | `http://order-service:8082` | |
| `BACKEND_TIMEOUT_MS` | `2000` | connect + request timeout for every upstream call |

## Tests

```bash
mvn test   # BackendClientTest: JSON parsing, 404 -> BackendException.notFound, a downed
           # backend surfacing as a caught exception rather than an uncaught IOException a
           # servlet would 500 on. Stubbed with a plain com.sun.net.httpserver.HttpServer,
           # no mock framework.
```

No test exercises the servlets or JSPs themselves -- that needs a running WildFly (Arquillian or
similar), which this service does not have set up. Verified by hand instead: deployed and clicked
through, the same "verified by hand, not in CI" gap this repository already states plainly for
`aquatics-advisor`'s HTTP layer and `payment-service`'s original database constraints.
