"""The HTTP surface.

The response shape is the deliverable here. An advisor that answers "false" is
useless: a customer standing in front of a tank needs to know *which* fish,
*which* parameter, and what the numbers are. Every finding carries the species,
the rule that produced it, and a sentence that quotes the rule's own
justification.
"""

from __future__ import annotations

import logging
import time
from collections import Counter

from fastapi import APIRouter, FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, Field

from advisor.catalog import CatalogClient, CatalogUnavailable, UnknownSku
from advisor.domain import Assessment, Inhabitant, Verdict
from advisor.rules import Rules, assess

log = logging.getLogger("advisor")
router = APIRouter()

METRICS: Counter = Counter()


class InhabitantIn(BaseModel):
    sku: str = Field(max_length=32)
    quantity: int = Field(ge=1, le=500)


class TankIn(BaseModel):
    volume_litres: float = Field(gt=0, le=10_000, alias="volumeLitres")
    inhabitants: list[InhabitantIn] = Field(default_factory=list, max_length=40)

    model_config = {"populate_by_name": True}


class CandidateIn(TankIn):
    candidate: InhabitantIn


def _finding_json(finding) -> dict:
    return {
        "verdict": finding.verdict.value,
        "rule": finding.rule,
        "detail": finding.detail,
        "species": finding.species,
    }


def _assessment_json(result: Assessment, rules: Rules) -> dict:
    return {
        "verdict": result.verdict.value,
        "findings": [_finding_json(f) for f in result.sorted_findings()],
        # The band the tank has to be held in, which is the thing the customer
        # writes on a sticky note next to the heater.
        "water": {
            "temperatureC": _interval_json(result.temperature),
            "ph": _interval_json(result.ph),
            "dgh": _interval_json(result.dgh),
        },
        "recommendedLitres": round(result.recommended_litres, 1),
        "rulesVersion": rules.version,
    }


def _interval_json(interval) -> dict | None:
    return None if interval is None else {"min": interval.low, "max": interval.high}


async def _resolve(app: FastAPI, items: list[InhabitantIn]) -> list[Inhabitant]:
    catalog: CatalogClient = app.state.catalog
    resolved = []
    for item in items:
        try:
            species = await catalog.species(item.sku)
        except UnknownSku as exc:
            raise HTTPException(
                status_code=404,
                detail={"error": "unknown_sku", "message": str(exc), "sku": item.sku},
            ) from exc
        except CatalogUnavailable as exc:
            # 503, not 500: the advisor is fine, its dependency is not, and a
            # caller should retry rather than treat the answer as "no".
            raise HTTPException(
                status_code=503,
                detail={"error": "catalog_unavailable", "message": str(exc)},
            ) from exc
        resolved.append(Inhabitant(species, item.quantity))
    return resolved


@router.post("/v1/tank/check")
async def check_tank(body: TankIn, request: Request) -> dict:
    """Assess a tank as described."""
    rules: Rules = request.app.state.rules
    inhabitants = await _resolve(request.app, body.inhabitants)
    result = assess(body.volume_litres, inhabitants, rules)
    METRICS[f"verdict_{result.verdict.value}"] += 1
    return _assessment_json(result, rules)


@router.post("/v1/tank/can-i-add")
async def can_i_add(body: CandidateIn, request: Request) -> dict:
    """Assess a tank with one more species in it.

    Answers the question a customer is actually asking, which is not "is my
    tank valid" but "can I buy this fish". The response separates the problems
    the candidate *introduces* from the ones the tank already had, because
    refusing a sale over a pre-existing fault would be both unhelpful and
    unfair.
    """
    rules: Rules = request.app.state.rules
    existing = await _resolve(request.app, body.inhabitants)
    candidate = (await _resolve(request.app, [body.candidate]))[0]

    before = assess(body.volume_litres, existing, rules)
    after = assess(body.volume_litres, existing + [candidate], rules)

    already = {(f.rule, f.detail) for f in before.findings}
    introduced = [f for f in after.findings if (f.rule, f.detail) not in already]

    verdict = Verdict.OK
    for finding in introduced:
        verdict = verdict.worse_of(finding.verdict)

    METRICS[f"candidate_{verdict.value}"] += 1
    return {
        "verdict": verdict.value,
        "candidate": {"sku": candidate.species.sku, "name": candidate.species.common_name},
        "introduces": [_finding_json(f) for f in introduced],
        "alreadyPresent": [_finding_json(f) for f in before.sorted_findings()],
        "tankAfter": _assessment_json(after, rules),
    }


@router.get("/v1/rules")
async def show_rules(request: Request) -> dict:
    """The rules, as published.

    A customer told "no" is entitled to see the threshold that said so, and a
    shop that cannot show its own rule is asking to be trusted rather than
    read.
    """
    rules: Rules = request.app.state.rules
    return {"version": rules.version, "rules": rules.raw}


@router.get("/healthz")
async def healthz() -> dict:
    # Deliberately does not call the catalog. If it did, a catalog outage would
    # make Kubernetes restart every healthy advisor pod in a loop.
    return {"status": "ok"}


@router.get("/readyz")
async def readyz(request: Request) -> JSONResponse:
    catalog: CatalogClient = request.app.state.catalog
    if await catalog.ready():
        return JSONResponse({"status": "ok"})
    return JSONResponse(
        {"status": "unready", "reason": "catalog unreachable"}, status_code=503
    )


@router.get("/metrics")
async def metrics() -> PlainTextResponse:
    lines = [
        "# HELP advisor_verdicts_total Tank assessments by verdict.",
        "# TYPE advisor_verdicts_total counter",
    ]
    for verdict in ("ok", "caution", "refused"):
        lines.append(f'advisor_verdicts_total{{verdict="{verdict}"}} {METRICS[f"verdict_{verdict}"]}')
    lines += [
        "# HELP advisor_candidate_answers_total Answers to can-i-add, by verdict.",
        "# TYPE advisor_candidate_answers_total counter",
    ]
    for verdict in ("ok", "caution", "refused"):
        lines.append(
            f'advisor_candidate_answers_total{{verdict="{verdict}"}} '
            f'{METRICS[f"candidate_{verdict}"]}'
        )
    return PlainTextResponse("\n".join(lines) + "\n")


def request_logger(app: FastAPI) -> None:
    @app.middleware("http")
    async def _log(request: Request, call_next):
        start = time.monotonic()
        response = await call_next(request)
        if request.url.path not in {"/healthz", "/metrics"}:
            log.info(
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": response.status_code,
                    "duration_ms": round((time.monotonic() - start) * 1000, 1),
                },
            )
        return response
