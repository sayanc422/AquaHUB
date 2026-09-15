"""The stocking rules, against the fish the shop actually sells.

Every case here is one an aquarist would recognise, and most of them are
mistakes people really make. A test suite of invented species would prove the
arithmetic and none of the judgement.
"""

from advisor.domain import Inhabitant, Verdict
from advisor.rules import assess

from tests.conftest import BETTA, CARDINAL, CORY, DANIO, GUPPY, KUHLI, NEON, PLECO, species


def tank(litres, *pairs):
    return litres, [Inhabitant(sp, qty) for sp, qty in pairs]


def reasons(assessment, rule_prefix):
    return [f for f in assessment.findings if f.rule.startswith(rule_prefix)]


# ------------------------------------------------------------ the good case

def test_a_sensible_community_tank_is_fine(rules):
    litres, inhabitants = tank(120, (NEON, 10), (CORY, 6))
    result = assess(litres, inhabitants, rules)

    assert result.verdict is Verdict.OK, [f.detail for f in result.findings]
    # And it tells the customer the band to hold the tank in.
    assert result.temperature is not None
    assert (result.temperature.low, result.temperature.high) == (20.0, 25.0)


# ---------------------------------------------------------------- water

def test_guppies_and_cardinal_tetras_have_no_ph_in_common(rules):
    """The classic hard-water / soft-water mistake, and a genuine refusal.

    Guppies want pH 7.0-8.2, cardinals 4.6-6.8. There is no number that suits
    both, so this is not a judgement call.
    """
    litres, inhabitants = tank(200, (GUPPY, 6), (CARDINAL, 10))
    result = assess(litres, inhabitants, rules)

    assert result.verdict is Verdict.REFUSED
    ph = reasons(result, "water.pH")
    assert ph, [f.rule for f in result.findings]
    detail = ph[0].detail
    # The reason has to name both fish and both ranges, or it is useless to
    # somebody standing in front of the tank.
    assert "Guppy" in detail and "Cardinal Tetra" in detail
    assert "7-8.2" in detail and "4.6-6.8" in detail


def test_a_narrow_temperature_overlap_is_a_caution_not_a_refusal(rules):
    """Panda cories stop at 25 °C, kuhli loaches start at 24 °C.

    One degree of overlap is achievable and leaves no margin, which is exactly
    what a shop should say out loud rather than sell quietly.
    """
    litres, inhabitants = tank(200, (CORY, 6), (KUHLI, 5))
    result = assess(litres, inhabitants, rules)

    temp = reasons(result, "water.temperature")
    assert temp and temp[0].verdict is Verdict.CAUTION
    assert "24-25" in temp[0].detail


def test_a_single_species_raises_no_water_findings(rules):
    litres, inhabitants = tank(120, (NEON, 10))
    assert not reasons(assess(litres, inhabitants, rules), "water.")


# ------------------------------------------------------------- stocking

def test_a_pleco_is_refused_by_its_own_minimum_whatever_the_arithmetic_says(rules):
    """13 cm of fish in a 60 L tank. One of them, so the capacity sum passes."""
    litres, inhabitants = tank(60, (PLECO, 1))
    result = assess(litres, inhabitants, rules)

    minimum = reasons(result, "stocking.species_minimum")
    assert result.verdict is Verdict.REFUSED
    assert minimum and "120 L" in minimum[0].detail


def test_too_many_fish_for_the_volume_is_refused(rules):
    litres, inhabitants = tank(60, (NEON, 30))
    result = assess(litres, inhabitants, rules)

    capacity = reasons(result, "stocking.capacity")
    assert result.verdict is Verdict.REFUSED
    assert capacity and "126 L" in capacity[0].detail


def test_a_tank_filled_to_the_brim_is_a_caution(rules):
    # 12 neons x 3.5 cm x 1.2 = 50.4 L against 57 L: over the caution fraction,
    # under the refusal one.
    litres, inhabitants = tank(57, (NEON, 12))
    result = assess(litres, inhabitants, rules)

    capacity = reasons(result, "stocking.capacity")
    assert capacity and capacity[0].verdict is Verdict.CAUTION


# ------------------------------------------------------------ behaviour

def test_an_aggressive_fish_is_refused_in_a_community_tank(rules):
    litres, inhabitants = tank(120, (BETTA, 1), (NEON, 10))
    result = assess(litres, inhabitants, rules)

    temperament = reasons(result, "behaviour.temperament")
    assert result.verdict is Verdict.REFUSED
    assert temperament and "Betta" in temperament[0].detail


def test_two_male_bettas_are_refused_even_though_nothing_else_is_in_the_tank(rules):
    """The single most common fatal mistake in the hobby.

    `combinations` never pairs a species with itself, so without an explicit
    same-species rule this tank passes every other check in the file.
    """
    litres, inhabitants = tank(60, (BETTA, 2))
    result = assess(litres, inhabitants, rules)

    same = reasons(result, "behaviour.same_species")
    assert result.verdict is Verdict.REFUSED
    assert same and "2 ×" in same[0].detail


def test_one_betta_alone_is_fine(rules):
    litres, inhabitants = tank(60, (BETTA, 1))
    assert assess(litres, inhabitants, rules).verdict is Verdict.OK


def test_a_fin_nipper_is_refused_with_a_long_finned_fish(rules):
    litres, inhabitants = tank(200, (DANIO, 6), (GUPPY, 6))
    result = assess(litres, inhabitants, rules)

    nipping = reasons(result, "behaviour.fin_nipping")
    assert nipping and nipping[0].verdict is Verdict.REFUSED
    assert "Zebra Danio" in nipping[0].detail and "Guppy" in nipping[0].detail


def test_a_kuhli_loach_is_not_treated_as_a_predator(rules):
    """The false positive a size-only rule produces.

    A kuhli reaches 10 cm against a neon's 3.5 -- nearly three times -- and eats
    nothing in midwater. It is eel-shaped with a mouth built for gravel. This
    test exists because the first version of the rule refused this tank.
    """
    litres, inhabitants = tank(200, (KUHLI, 5), (NEON, 10))
    assert not reasons(assess(litres, inhabitants, rules), "behaviour.predation")


def test_a_large_predator_is_refused_with_something_it_can_swallow(rules):
    hunter = species(
        sku="FSH-TEST-PRED", common_name="Test Predator", max_size_cm=20.0,
        min_tank_litres=20, temperament="AGGRESSIVE", diet="CARNIVORE",
    )
    litres, inhabitants = tank(400, (hunter, 1), (NEON, 10))
    predation = reasons(assess(litres, inhabitants, rules), "behaviour.predation")

    assert predation and predation[0].verdict is Verdict.REFUSED
    assert "20 cm" in predation[0].detail and "3.5 cm" in predation[0].detail


# -------------------------------------------------------------- welfare

def test_three_neon_tetras_are_refused_as_a_shoal(rules):
    """Not a smaller shoal -- a stressed animal. The shop should not sell it."""
    litres, inhabitants = tank(120, (NEON, 3))
    result = assess(litres, inhabitants, rules)

    group = reasons(result, "welfare.group_size")
    assert result.verdict is Verdict.REFUSED
    assert group and "at least 8" in group[0].detail and "you have 3" in group[0].detail


def test_a_plant_eater_is_a_caution_because_it_is_the_customers_tank(rules):
    litres, inhabitants = tank(200, (PLECO, 1))
    plants = reasons(assess(litres, inhabitants, rules), "plants.safety")

    assert plants and plants[0].verdict is Verdict.CAUTION


# ------------------------------------------------------------- reporting

def test_every_problem_is_reported_not_just_the_first(rules):
    """A customer who fixes one fault and is then told a second is served badly."""
    litres, inhabitants = tank(40, (GUPPY, 2), (CARDINAL, 3))
    result = assess(litres, inhabitants, rules)

    rule_names = {f.rule for f in result.findings}
    assert "water.pH" in rule_names
    assert "welfare.group_size" in rule_names
    assert len(rule_names) >= 3, rule_names


def test_the_worst_verdict_wins_and_findings_come_worst_first(rules):
    litres, inhabitants = tank(200, (PLECO, 1), (NEON, 3))
    result = assess(litres, inhabitants, rules)

    assert result.verdict is Verdict.REFUSED  # refusal beats the plant caution
    assert result.sorted_findings()[0].verdict is Verdict.REFUSED


def test_an_empty_tank_is_fine_and_says_nothing(rules):
    result = assess(100, [], rules)
    assert result.verdict is Verdict.OK
    assert result.findings == []


def test_every_finding_names_a_rule_that_exists_in_the_file(rules):
    """A finding whose rule nobody can look up is an unarguable answer."""
    litres, inhabitants = tank(40, (GUPPY, 2), (CARDINAL, 3), (BETTA, 2))
    for finding in assess(litres, inhabitants, rules).findings:
        section = finding.rule.split(".")[0]
        assert section in rules.raw, f"{finding.rule} names no section of rules.yaml"
        assert finding.detail.endswith((".", "!")), finding.detail
        assert finding.species, finding.rule
