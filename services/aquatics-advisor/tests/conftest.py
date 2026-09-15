import pathlib
import sys

import pytest
import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from advisor.domain import Interval, Species  # noqa: E402
from advisor.rules import Rules  # noqa: E402


@pytest.fixture(scope="session")
def rules() -> Rules:
    """The real rules file, not a fixture invented for the tests.

    Loading the shipped YAML means a threshold edited by a domain person runs
    straight into this suite. That is the point: if somebody widens the pH
    tolerance until guppies and cardinal tetras pass, a test should go red and
    make them say so out loud.
    """
    path = pathlib.Path(__file__).resolve().parents[1] / "rules" / "rules.yaml"
    return Rules(yaml.safe_load(path.read_text()))


def species(**overrides) -> Species:
    base = dict(
        sku="TEST-01",
        common_name="Test Fish",
        scientific_name="Testus fishus",
        max_size_cm=4.0,
        min_tank_litres=40,
        min_group_size=1,
        temperature=Interval(22.0, 26.0),
        ph=Interval(6.5, 7.5),
        dgh=Interval(4.0, 12.0),
        temperament="PEACEFUL",
        diet="OMNIVORE",
        plant_safe=True,
    )
    base.update(overrides)
    return Species(**base)


# The real catalog seed, so the tests reason about the fish the shop sells
# rather than about convenient inventions. These numbers are copied from
# catalog-service's V2__seed_catalog.sql.
NEON = species(
    sku="FSH-NEO-01", common_name="Neon Tetra", scientific_name="Paracheirodon innesi",
    max_size_cm=3.5, min_tank_litres=60, min_group_size=8,
    temperature=Interval(20.0, 26.0), ph=Interval(5.5, 7.5), dgh=Interval(2.0, 10.0),
)
CARDINAL = species(
    sku="FSH-CAR-01", common_name="Cardinal Tetra", scientific_name="Paracheirodon axelrodi",
    max_size_cm=5.0, min_tank_litres=80, min_group_size=8,
    temperature=Interval(23.0, 28.0), ph=Interval(4.6, 6.8), dgh=Interval(1.0, 8.0),
)
GUPPY = species(
    sku="FSH-GUP-01", common_name="Guppy", scientific_name="Poecilia reticulata",
    max_size_cm=4.0, min_tank_litres=40, min_group_size=3,
    temperature=Interval(22.0, 28.0), ph=Interval(7.0, 8.2), dgh=Interval(8.0, 20.0),
)
BETTA = species(
    sku="FSH-BET-01", common_name="Betta (male)", scientific_name="Betta splendens",
    max_size_cm=7.0, min_tank_litres=20, min_group_size=1,
    temperature=Interval(24.0, 28.0), ph=Interval(6.0, 7.5), dgh=Interval(3.0, 12.0),
    temperament="AGGRESSIVE", diet="CARNIVORE",
)
CORY = species(
    sku="FSH-COR-01", common_name="Panda Cory", scientific_name="Corydoras panda",
    max_size_cm=5.0, min_tank_litres=60, min_group_size=6,
    temperature=Interval(20.0, 25.0), ph=Interval(6.0, 7.4), dgh=Interval(2.0, 12.0),
)
KUHLI = species(
    sku="FSH-KUH-01", common_name="Kuhli Loach", scientific_name="Pangio kuhlii",
    max_size_cm=10.0, min_tank_litres=80, min_group_size=5,
    temperature=Interval(24.0, 28.0), ph=Interval(5.5, 7.0), dgh=Interval(2.0, 10.0),
)
DANIO = species(
    sku="FSH-ZEB-01", common_name="Zebra Danio", scientific_name="Danio rerio",
    max_size_cm=5.0, min_tank_litres=60, min_group_size=6,
    temperature=Interval(18.0, 25.0), ph=Interval(6.5, 7.5), dgh=Interval(5.0, 16.0),
    temperament="SEMI_AGGRESSIVE",
)
PLECO = species(
    sku="FSH-BNP-01", common_name="Bristlenose Pleco", scientific_name="Ancistrus cirrhosus",
    max_size_cm=13.0, min_tank_litres=120, min_group_size=1,
    temperature=Interval(22.0, 27.0), ph=Interval(6.0, 7.8), dgh=Interval(4.0, 16.0),
    diet="HERBIVORE", plant_safe=False,
)
