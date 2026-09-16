"""The stocking rules, applied.

Every rule is a small function with the same shape: look at the tank, return
findings. They are separate functions rather than one long check so that a
failing test names the rule, and so that a domain person reading this file can
find "the one about shoaling" without reading the others.

The thresholds all come from rules.yaml. None of them is written in here --
that is the whole arrangement: this file decides *what* to check, the YAML
decides *how much is too much*, and the person who keeps fish owns the second
one.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import combinations
from typing import Any, Callable

from advisor.domain import (
    Assessment,
    Finding,
    Inhabitant,
    Interval,
    Species,
    Verdict,
    intersect_all,
)


@dataclass(frozen=True)
class Rules:
    """rules.yaml, parsed once."""

    raw: dict[str, Any]

    @property
    def version(self) -> int:
        return int(self.raw["version"])

    def num(self, *path: str) -> float:
        node: Any = self.raw
        for key in path:
            node = node[key]
        return float(node)

    def why(self, *path: str) -> str:
        node: Any = self.raw
        for key in path:
            node = node[key]
        return " ".join(str(node).split())

    def skus(self, *path: str) -> set[str]:
        node: Any = self.raw
        for key in path:
            node = node[key]
        return set(node or [])

    def incompatible_temperaments(self) -> set[frozenset[str]]:
        return {
            frozenset(pair) for pair in self.raw["behaviour"]["incompatible_temperaments"]
        }


# --------------------------------------------------------------- water

def check_water(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> list[Finding]:
    """Temperature, pH and hardness must leave a band everyone can live in.

    Two failures, and they are different problems. No overlap at all is a
    refusal: there is no number the tank can be set to. A *narrow* overlap is a
    caution: it is achievable and it removes every margin for error, which is
    the kind of thing a shop should say out loud rather than sell quietly.
    """
    findings: list[Finding] = []
    if len(inhabitants) < 2:
        return findings

    params = [
        ("temperature", "°C", lambda s: s.temperature, "min_temperature_overlap_c", "why_temperature"),
        ("pH", "", lambda s: s.ph, "min_ph_overlap", "why_ph"),
        ("hardness", " dGH", lambda s: s.dgh, "min_dgh_overlap", "why_dgh"),
    ]

    for name, unit, get, threshold_key, why_key in params:
        species = [i.species for i in inhabitants]
        overlap = intersect_all([get(s) for s in species])

        if overlap is None:
            # Name the pair, not just the failure. "Something in this tank does
            # not fit" is useless to somebody standing in front of it.
            for a, b in combinations(species, 2):
                if get(a).intersect(get(b)) is None:
                    findings.append(
                        Finding(
                            verdict=Verdict.REFUSED,
                            rule=f"water.{name}",
                            detail=(
                                f"{a.common_name} and {b.common_name} have no {name} in common: "
                                f"{a.common_name} needs {get(a)}{unit}, {b.common_name} needs "
                                f"{get(b)}{unit}. There is no setting that suits both. "
                                f"{rules.why('water', why_key)}"
                            ),
                            species=[a.sku, b.sku],
                        )
                    )
            continue

        minimum = rules.num("water", threshold_key)
        if overlap.width() < minimum:
            findings.append(
                Finding(
                    verdict=Verdict.CAUTION,
                    rule=f"water.{name}",
                    detail=(
                        f"The only {name} that suits everything in this tank is "
                        f"{overlap}{unit} — a window of {overlap.width():g}{unit}, where "
                        f"{minimum:g}{unit} is the least this shop considers workable. "
                        f"Every fish in there is at the edge of its range, with nothing "
                        f"left for the tank drifting. {rules.why('water', why_key)}"
                    ),
                    species=[s.sku for s in species],
                )
            )
    return findings


# ------------------------------------------------------------ stocking

def check_capacity(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> list[Finding]:
    """Volume, against adult size rather than the size in the bag."""
    findings: list[Finding] = []
    if not inhabitants:
        return findings

    per_cm = rules.num("stocking", "litres_per_adult_cm")

    def bioload(i: Inhabitant) -> float:
        # An unknown group counts as a fish. Being wrong in the strict
        # direction is the right way round for stocking advice: it over-cautions
        # rather than telling somebody a tank is fine when it is not.
        try:
            factor = rules.num("stocking", "bioload_factor", i.species.animal_group)
        except KeyError:
            factor = 1.0
        return i.species.max_size_cm * i.quantity * per_cm * factor

    needed = sum(bioload(i) for i in inhabitants)

    # A species' own minimum is a floor the arithmetic cannot argue with: a
    # 13 cm pleco does not fit in a 30 L tank however few of them there are.
    biggest_minimum = max(i.species.min_tank_litres for i in inhabitants)
    demanding = max(inhabitants, key=lambda i: i.species.min_tank_litres).species

    if tank_litres < biggest_minimum:
        findings.append(
            Finding(
                verdict=Verdict.REFUSED,
                rule="stocking.species_minimum",
                detail=(
                    f"{demanding.common_name} needs at least {biggest_minimum} L of tank and this "
                    f"one is {tank_litres:g} L. That is a floor for the species, not a stocking "
                    f"calculation — an adult reaches {demanding.max_size_cm:g} cm and needs the "
                    f"swimming room whatever else is in there."
                ),
                species=[demanding.sku],
            )
        )

    if needed > tank_litres * rules.num("stocking", "hard_refusal_fraction"):
        findings.append(
            Finding(
                verdict=Verdict.REFUSED,
                rule="stocking.capacity",
                detail=(
                    f"Fully grown, this stocking needs about {needed:.0f} L and the tank is "
                    f"{tank_litres:g} L. {rules.why('stocking', 'why_capacity')}"
                ),
                species=[i.species.sku for i in inhabitants],
            )
        )
    elif needed > tank_litres * rules.num("stocking", "caution_fraction"):
        findings.append(
            Finding(
                verdict=Verdict.CAUTION,
                rule="stocking.capacity",
                detail=(
                    f"Fully grown, this stocking needs about {needed:.0f} L in a {tank_litres:g} L "
                    f"tank. It fits, with nothing spare — you will be doing larger water changes "
                    f"than you expected. {rules.why('stocking', 'why_capacity')}"
                ),
                species=[i.species.sku for i in inhabitants],
            )
        )
    return findings


# ----------------------------------------------------------- behaviour

def check_behaviour(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> list[Finding]:
    """Temperament, predation and fin-nipping."""
    findings: list[Finding] = []
    incompatible = rules.incompatible_temperaments()
    ratio = rules.num("behaviour", "predation_size_ratio")
    long_finned = rules.skus("behaviour", "long_finned_skus")
    nippers = rules.skus("behaviour", "fin_nipper_skus")

    # A species kept with itself. `combinations` never pairs a species with
    # itself, so without this the single most common fatal mistake in the hobby
    # -- two male bettas in one tank -- would pass every check in this file.
    #
    # It applies only to species that are kept alone (min_group_size == 1), and
    # that condition is not a detail. Mbuna are aggressive towards their own
    # kind AND are kept in groups of twelve, because a crowd spreads the
    # aggression so no single fish is driven to death. Without the check on
    # group size this rule refused twelve demasoni -- which is not merely a
    # false positive, it is the exact opposite of the correct husbandry, and it
    # would have refused the sale the shop most wants to get right.
    #
    # The species' own minimum group size is the data that decides it: a fish
    # whose profile says "keep 12" is telling us the group is the mitigation.
    for i in inhabitants:
        s = i.species
        if i.quantity > 1 and s.min_group_size == 1 and frozenset({s.temperament}) in incompatible:
            findings.append(
                Finding(
                    verdict=Verdict.REFUSED,
                    rule="behaviour.same_species",
                    detail=(
                        f"{i.quantity} × {s.common_name} in one tank: this species is "
                        f"{s.temperament.lower().replace('_', ' ')} towards its own kind. "
                        f"They will fight until one is dead. "
                        f"{rules.why('behaviour', 'why_temperament')}"
                    ),
                    species=[s.sku],
                )
            )

    for a, b in combinations([i.species for i in inhabitants], 2):
        if frozenset({a.temperament, b.temperament}) in incompatible:
            findings.append(
                Finding(
                    verdict=Verdict.REFUSED,
                    rule="behaviour.temperament",
                    detail=(
                        f"{a.common_name} ({a.temperament.lower().replace('_', ' ')}) and "
                        f"{b.common_name} ({b.temperament.lower().replace('_', ' ')}) should not "
                        f"share a tank. {rules.why('behaviour', 'why_temperament')}"
                    ),
                    species=[a.sku, b.sku],
                )
            )

        # Predation is judged on temperament *and* size, not size alone.
        #
        # Size alone gets this wrong in an obvious way: a kuhli loach reaches
        # 10 cm against a neon tetra's 3.5 cm and would be refused, when it is
        # an eel-shaped bottom dweller with a mouth built for hunting in gravel
        # and no interest whatever in a fish in midwater. What predicts
        # predation is mouth gape, and the catalog does not carry it.
        #
        # Temperament is the available proxy, and it is an imperfect one in the
        # other direction too -- the classic tank disaster is an angelfish,
        # which every source calls peaceful, eating the neons it was sold with.
        # That gap is named in rules.yaml rather than papered over, and closing
        # it means adding a gape or body-shape field to catalog-service.
        predatory = {"AGGRESSIVE", "SEMI_AGGRESSIVE"}
        big, small = (a, b) if a.max_size_cm >= b.max_size_cm else (b, a)
        if (
            big.temperament in predatory
            and big.diet in {"CARNIVORE", "OMNIVORE"}
            and big.max_size_cm >= small.max_size_cm * ratio
        ):
            findings.append(
                Finding(
                    verdict=Verdict.REFUSED,
                    rule="behaviour.predation",
                    detail=(
                        f"{big.common_name} reaches {big.max_size_cm:g} cm and "
                        f"{small.common_name} only {small.max_size_cm:g} cm. "
                        f"{rules.why('behaviour', 'why_predation')}"
                    ),
                    species=[big.sku, small.sku],
                )
            )

        pair = {a.sku, b.sku}
        if pair & nippers and pair & long_finned:
            nipper = a if a.sku in nippers else b
            victim = b if a.sku in nippers else a
            findings.append(
                Finding(
                    verdict=Verdict.REFUSED,
                    rule="behaviour.fin_nipping",
                    detail=(
                        f"{nipper.common_name} will nip {victim.common_name}. "
                        f"{rules.why('behaviour', 'why_fin_nipping')}"
                    ),
                    species=[nipper.sku, victim.sku],
                )
            )
    return findings


# ------------------------------------------------------------- welfare

def check_group_sizes(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> list[Finding]:
    """A shoaling fish below its minimum group is not a smaller shoal."""
    findings = []
    for i in inhabitants:
        if i.quantity < i.species.min_group_size:
            findings.append(
                Finding(
                    verdict=Verdict.REFUSED,
                    rule="welfare.group_size",
                    detail=(
                        f"{i.species.common_name} needs a group of at least "
                        f"{i.species.min_group_size} and you have {i.quantity}. "
                        f"{rules.why('welfare', 'why_group_size')}"
                    ),
                    species=[i.species.sku],
                )
            )
    return findings


def check_plants(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> list[Finding]:
    """Plant-safety is a caution, never a refusal: it is the customer's tank."""
    findings = []
    for i in inhabitants:
        if not i.species.plant_safe:
            findings.append(
                Finding(
                    verdict=Verdict.CAUTION,
                    rule="plants.safety",
                    detail=(
                        f"{i.species.common_name} eats live plants. "
                        f"{rules.why('plants', 'why_plant_safety')}"
                    ),
                    species=[i.species.sku],
                )
            )
    return findings


CHECKS: list[Callable[[float, list[Inhabitant], Rules], list[Finding]]] = [
    check_water,
    check_capacity,
    check_behaviour,
    check_group_sizes,
    check_plants,
]


def assess(tank_litres: float, inhabitants: list[Inhabitant], rules: Rules) -> Assessment:
    """Run every check and report all of it.

    Every rule runs even after one has refused. A customer who is told one
    reason, fixes it, and is then told a second is being served badly -- the
    answer they need is everything that is wrong with the tank as described.
    """
    findings: list[Finding] = []
    for check in CHECKS:
        findings.extend(check(tank_litres, inhabitants, rules))

    verdict = Verdict.OK
    for finding in findings:
        verdict = verdict.worse_of(finding.verdict)

    species = [i.species for i in inhabitants]
    per_cm = rules.num("stocking", "litres_per_adult_cm")
    return Assessment(
        verdict=verdict,
        findings=findings,
        temperature=intersect_all([s.temperature for s in species]) if species else None,
        ph=intersect_all([s.ph for s in species]) if species else None,
        dgh=intersect_all([s.dgh for s in species]) if species else None,
        recommended_litres=sum(i.species.max_size_cm * i.quantity * per_cm for i in inhabitants),
    )
