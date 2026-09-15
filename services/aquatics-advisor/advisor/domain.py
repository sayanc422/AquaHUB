"""The advisor's domain: intervals, species, and the verdict it reaches.

Nothing here touches HTTP or a database. The whole point of this service is
that the rules are the interesting part, so they are pure functions over plain
data and every one of them is a test rather than an opinion.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class Verdict(str, Enum):
    """What the advisor says about a tank.

    Three values, not two. A binary yes/no would force every judgement call
    into one of the extremes, and most real stocking questions are neither
    obviously fine nor obviously wrong -- they are "this will work if you stay
    on top of it", which is what an aquarist in a shop would actually say.
    """

    OK = "ok"
    CAUTION = "caution"
    REFUSED = "refused"

    def worse_of(self, other: "Verdict") -> "Verdict":
        order = {Verdict.OK: 0, Verdict.CAUTION: 1, Verdict.REFUSED: 2}
        return self if order[self] >= order[other] else other


@dataclass(frozen=True)
class Interval:
    """A closed range of a water parameter.

    Frozen, because an interval that can be mutated after being intersected is
    a bug waiting for a caller who keeps a reference.
    """

    low: float
    high: float

    def __post_init__(self) -> None:
        if self.high < self.low:
            raise ValueError(f"an interval cannot end before it starts: {self.low}..{self.high}")

    def intersect(self, other: "Interval") -> "Interval | None":
        """The overlap, or None when there is none.

        None rather than an empty interval: an empty interval is a value that
        arithmetic will happily keep working on, and "no overlap" needs to stop
        the calculation rather than travel through it.
        """
        low = max(self.low, other.low)
        high = min(self.high, other.high)
        return Interval(low, high) if high >= low else None

    def width(self) -> float:
        return self.high - self.low

    def __str__(self) -> str:
        return f"{self.low:g}-{self.high:g}"


def intersect_all(intervals: list[Interval]) -> Interval | None:
    """Intersect a whole set.

    This is the operation the tank check is built on: a tank is liveable when
    every inhabitant's range shares a common band, and the band shrinks as each
    species is added. Folding pairwise is the same answer as checking every
    pair, and it is linear rather than quadratic -- but the *reason* for a
    failure needs the pair, which is why the caller also walks pairs when this
    returns None.
    """
    if not intervals:
        return None
    current = intervals[0]
    for nxt in intervals[1:]:
        overlap = current.intersect(nxt)
        if overlap is None:
            return None
        current = overlap
    return current


@dataclass(frozen=True)
class Species:
    """A species care profile, as the advisor needs it.

    catalog-service owns this data; the advisor owns the rules about it. The
    fields are a subset of the catalog's published JSON, converted once at the
    boundary so that a catalog field rename is a change in one adapter rather
    than throughout the rules.
    """

    sku: str
    common_name: str
    scientific_name: str
    max_size_cm: float
    min_tank_litres: int
    min_group_size: int
    temperature: Interval
    ph: Interval
    dgh: Interval
    temperament: str
    diet: str
    plant_safe: bool

    def __str__(self) -> str:
        return self.common_name


@dataclass(frozen=True)
class Inhabitant:
    """A species and how many of them."""

    species: Species
    quantity: int


@dataclass
class Finding:
    """One thing the advisor has to say, in the words it would say it in.

    `detail` is the sentence a customer reads. `rule` names the rule that
    produced it, so that somebody arguing with the answer can find the
    threshold in rules.yaml rather than in the source.
    """

    verdict: Verdict
    rule: str
    detail: str
    species: list[str] = field(default_factory=list)


@dataclass
class Assessment:
    """Everything the advisor concluded, worst first."""

    verdict: Verdict
    findings: list[Finding]
    # The band the tank has to be held in for everyone in it, when one exists.
    temperature: Interval | None = None
    ph: Interval | None = None
    dgh: Interval | None = None
    recommended_litres: float = 0.0

    def sorted_findings(self) -> list[Finding]:
        order = {Verdict.REFUSED: 0, Verdict.CAUTION: 1, Verdict.OK: 2}
        return sorted(self.findings, key=lambda f: order[f.verdict])
