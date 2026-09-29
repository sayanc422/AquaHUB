"""Shrimp eaten by shrimp, and by fish that specialise in them (rules v5).

The Indian whisker shrimp is a 7 cm predatory river prawn, and catalog V24 put
it on sale beside cherry shrimp. The size-ratio predation rule cannot see it:
7 cm against 3 cm is under the 2.5 ratio, and it is not an "aggressive" fish.
The live tank checker answered "These can live together" for exactly the tank
the whisker shrimp's own care note forbids, on 28 September 2026.
"""

from advisor.domain import Interval, Verdict
from advisor.rules import assess

from tests.conftest import CHERRY_SHRIMP, NERITE, species
from tests.test_rules import reasons, tank

WHISKER = species(
    sku="INV-WHS-01", common_name="Indian Whisker Shrimp", scientific_name="Macrobrachium lamarrei",
    max_size_cm=7.0, min_tank_litres=40, min_group_size=1,
    temperature=Interval(22.0, 30.0), ph=Interval(6.5, 8.0), dgh=Interval(5.0, 20.0),
    temperament="SEMI_AGGRESSIVE", diet="CARNIVORE", animal_group="SHRIMP",
)
BAMBOO = species(
    sku="INV-FLT-01", common_name="Bamboo Shrimp", scientific_name="Atyopsis moluccensis",
    max_size_cm=8.0, min_tank_litres=60, min_group_size=1,
    temperature=Interval(23.0, 28.0), ph=Interval(6.5, 7.8), dgh=Interval(3.0, 15.0),
    animal_group="SHRIMP",
)


def test_a_whisker_shrimp_is_refused_with_cherry_shrimp(rules):
    result = assess(*tank(60, (CHERRY_SHRIMP, 10), (WHISKER, 3)), rules)
    hits = reasons(result, "behaviour.shrimp_predation")
    assert result.verdict is Verdict.REFUSED
    assert hits and set(hits[0].species) == {"INV-WHS-01", "INV-CHE-01"}


def test_a_shrimp_eater_leaves_a_larger_shrimp_and_a_snail_alone(rules):
    # A bamboo shrimp outgrows the whisker shrimp, and a nerite is not a shrimp.
    # The rule is about prey the eater can catch, not about sharing a tank.
    result = assess(*tank(100, (BAMBOO, 1), (WHISKER, 1), (NERITE, 2)), rules)
    assert not reasons(result, "behaviour.shrimp_predation")


def test_the_rule_is_data_so_the_list_is_in_the_rules_file(rules):
    # Like fin-nippers: which animals hunt shrimp is a fact about the animal the
    # catalog does not carry, and it belongs to whoever keeps them.
    assert "INV-WHS-01" in rules.skus("behaviour", "shrimp_eater_skus")
