# aquatics-advisor

Whether a tank will work, and why not.

## Why Python, and why it deploys on its own cadence

The rules change far more often than the code that applies them, and they are meant to be edited by
somebody who keeps fish rather than somebody who writes Python. `rules/rules.yaml` holds every
threshold with a sentence of justification beside it; `advisor/rules.py` decides *what* to check and
never *how much is too much*.

Changing "how narrow a pH overlap is acceptable" should be a pull request against a YAML file,
reviewed by the person who runs the shop. That is the whole arrangement, and it is why this is a
separate service with a separate release rhythm.

## It has no database

Deliberately. The advisor owns **rules**; it owns no data. Species care profiles belong to
`catalog-service`, and a copy here would be a second source of truth that drifts the first time
somebody corrects a pH range in one place. What it keeps is a 5-minute cache, because care profiles
change a few times a year and a tank check makes one upstream call per species.

**Cost:** the advisor cannot answer anything when the catalog is down. Readiness fails so the pod
leaves the Service endpoints; liveness does **not** check the catalog, or an upstream outage would
restart every healthy pod in a loop.

## Three verdicts, not two

`ok` · `caution` · `refused`

A binary answer forces every judgement into an extreme, and most real stocking questions are
neither obviously fine nor obviously wrong — they are "this will work if you stay on top of it",
which is what someone in a shop would actually say.

The distinction that matters: **no overlap at all is a refusal** (there is no number the tank can be
set to), **a narrow overlap is a caution** (achievable, with no margin left). Those are different
problems and the customer deserves to be told which one they have.

## What it checks

| | |
|---|---|
| **Water** | Temperature, pH and hardness intervals must leave a band every inhabitant can live in. pH is a log scale, so the tolerance is tighter than the numbers look. |
| **Capacity** | Adult size, not the size in the bag — plus each species' own minimum volume, which no arithmetic can argue with. |
| **Temperament** | Aggressive with peaceful; two aggressives; two territorials. And the same species with itself, because two male bettas is the most common fatal mistake in the hobby and pairwise checks never compare a species to itself. |
| **Predation** | Adult size ratio, applied only to aggressive and semi-aggressive species — see the known gap below. |
| **Fin-nipping** | Named species, because it is a property of the animal rather than of any field the catalog has. |
| **Shoal size** | A shoaling fish below its minimum group is not a smaller shoal, it is a stressed animal. |
| **Plants** | A caution, never a refusal. It is the customer's tank. |

Every finding names the species, the rule, and quotes the rule's own justification. A customer told
"no" can look up the threshold at `GET /v1/rules`.

## The known gap, left visible

What actually predicts predation is **mouth gape**, and `catalog-service` does not record it. Adult
length is the available stand-in and it is wrong in both directions:

- A kuhli loach reaches 10 cm against a neon tetra's 3.5 cm and eats nothing in midwater — it is
  eel-shaped with a mouth built for hunting in gravel. The first version of the rule refused that
  tank; `test_a_kuhli_loach_is_not_treated_as_a_predator` exists because of it.
- An angelfish is called peaceful by every source and is the classic reason a tank of neon tetras
  becomes a tank of one angelfish.

Limiting the rule to aggressive and semi-aggressive species avoids the first error and accepts the
second. Closing it properly means adding a gape or body-shape field to the catalog, which is a
change to somebody else's service and a conversation rather than an edit here.

## API

| | | |
|---|---|---|
| `POST` | `/v1/tank/check` | Assess a tank as described |
| `POST` | `/v1/tank/can-i-add` | The question customers actually ask. Separates what the candidate *introduces* from what the tank already had — refusing a sale over a pre-existing fault would be unfair |
| `GET` | `/v1/rules` | The thresholds, published. A shop that cannot show its own rule is asking to be trusted rather than read |
| `GET` | `/healthz` `/readyz` `/metrics` | |

```console
$ curl -s localhost:8084/v1/tank/can-i-add -d '{"volumeLitres":60,
    "inhabitants":[{"sku":"FSH-NEO-01","quantity":10}],
    "candidate":{"sku":"FSH-BNP-01","quantity":1}}'

REFUSED — Bristlenose Pleco
  Bristlenose Pleco needs at least 120 L of tank and this one is 60 L. That is a floor
  for the species, not a stocking calculation — an adult reaches 13 cm and needs the
  swimming room whatever else is in there.
```

## Tests

```bash
python -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest      # 29 tests, no database and no network
```

The suite loads the **shipped** `rules.yaml`, not a fixture invented for it. If somebody widens the
pH tolerance until guppies and cardinal tetras pass, a test goes red and makes them say so out loud.
The species fixtures are copied from `catalog-service`'s seed, so the cases are fish the shop really
sells and mistakes people really make.

What is **not** covered: the HTTP layer and the catalog client. Both were exercised by hand against
a live `catalog-service`; neither has an automated test, which is this service's clearest gap.

## Configuration

| Variable | Default | |
|---|---|---|
| `CATALOG_BASE_URL` | `http://catalog-service:8080` | |
| `CATALOG_TIMEOUT_S` | `2.0` | unbounded calls here exhaust the worker |
| `CATALOG_CACHE_TTL_S` | `300` | bounded staleness, deliberately |
| `RULES_PATH` | `rules/rules.yaml` | |

Rules are read **once, at startup**, and never reloaded on a timer. A file changing underneath a
running service means two pods answer the same question differently for the length of a rollout, and
"why did it say yes yesterday" becomes unanswerable. A rules change is a deployment, and the version
is in every response.
