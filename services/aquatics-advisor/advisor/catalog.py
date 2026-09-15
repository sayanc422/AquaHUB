"""The advisor's view of catalog-service.

**This service has no database, and that is a decision rather than an omission.**
It owns rules; it owns no data. Species care profiles belong to
catalog-service, and a copy here would be a second source of truth that drifts
the first time somebody corrects a pH range in one place.

What it keeps instead is a cache with a deadline. Care profiles change a few
times a year, and a tank check that made an upstream call per species would put
the advisor's latency at the mercy of the catalog's.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

import httpx

from advisor.domain import Interval, Species


class CatalogUnavailable(RuntimeError):
    """The catalog could not be reached or did not answer in time."""


class UnknownSku(KeyError):
    """No such product, or one with no care profile.

    Not an error worth paging anybody for: it means a customer asked about
    something that is not livestock, or a SKU that has been retired.
    """


@dataclass
class _Entry:
    species: Species
    fetched_at: float


class CatalogClient:
    """Reads species profiles, and remembers them briefly."""

    def __init__(self, base_url: str, timeout_s: float = 2.0, ttl_s: float = 300.0) -> None:
        self._base_url = base_url.rstrip("/")
        # Bounded, like every other upstream call in this platform. Without it
        # a slow catalog holds advisor workers until they are all waiting, and
        # one degraded dependency becomes a dead service.
        self._timeout = timeout_s
        self._ttl = ttl_s
        self._cache: dict[str, _Entry] = {}

    async def species(self, sku: str) -> Species:
        cached = self._cache.get(sku)
        if cached and (time.monotonic() - cached.fetched_at) < self._ttl:
            return cached.species

        slug = await self._slug_for(sku)
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(f"{self._base_url}/api/products/{slug}")
        except httpx.HTTPError as exc:
            raise CatalogUnavailable(f"catalog did not answer: {exc}") from exc

        if response.status_code == 404:
            raise UnknownSku(sku)
        if response.status_code >= 400:
            raise CatalogUnavailable(f"catalog returned {response.status_code}")

        parsed = _to_species(sku, response.json())
        self._cache[sku] = _Entry(parsed, time.monotonic())
        return parsed

    async def _slug_for(self, sku: str) -> str:
        """The catalog is addressed by slug; orders and tanks speak SKU.

        One search call, cached with everything else. A SKU-addressed endpoint
        on catalog-service would remove this hop, and asking for one is a
        conversation with that service rather than a workaround here.
        """
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(f"{self._base_url}/api/products")
        except httpx.HTTPError as exc:
            raise CatalogUnavailable(f"catalog did not answer: {exc}") from exc

        if response.status_code >= 400:
            raise CatalogUnavailable(f"catalog returned {response.status_code}")

        for product in response.json():
            if product.get("sku") == sku:
                return product["slug"]
        raise UnknownSku(sku)

    async def ready(self) -> bool:
        """Readiness, not liveness.

        An advisor that cannot reach the catalog cannot answer anything, so it
        should leave the Service endpoints. It must not fail *liveness* on the
        same condition, or a catalog outage restarts every healthy pod in a
        loop and turns a partial outage into a total one -- the same rule the
        storefront follows.
        """
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(f"{self._base_url}/api/categories")
            return response.status_code < 400
        except httpx.HTTPError:
            return False


def _to_species(sku: str, payload: dict) -> Species:
    """Convert the catalog's JSON once, at the boundary.

    Every field rename upstream lands here and nowhere else. Rules that read the
    catalog's shape directly would need editing in a dozen places by somebody
    who came to change a threshold.
    """
    profile = payload.get("species")
    if not profile:
        raise UnknownSku(f"{sku} has no care profile (is it livestock?)")

    def interval(node: dict) -> Interval:
        return Interval(float(node["min"]), float(node["max"]))

    product = payload["product"]
    return Species(
        sku=product["sku"],
        common_name=profile["commonName"],
        scientific_name=profile["scientificName"],
        max_size_cm=float(profile["maxSizeCm"]),
        min_tank_litres=int(profile["minTankLitres"]),
        min_group_size=int(profile["minGroupSize"]),
        temperature=interval(profile["temperatureC"]),
        ph=interval(profile["ph"]),
        dgh=interval(profile["dgh"]),
        temperament=profile["temperament"],
        diet=profile["diet"],
        plant_safe=bool(profile["plantSafe"]),
    )
