"""Interval intersection, which every water rule is built on."""

import pytest

from advisor.domain import Interval, intersect_all


def test_overlapping_intervals_intersect_to_the_shared_band():
    assert Interval(20, 26).intersect(Interval(23, 28)) == Interval(23, 26)


def test_disjoint_intervals_have_no_intersection():
    # None, not an empty interval: an empty interval is a value arithmetic will
    # keep working on, and "no overlap" has to stop the calculation.
    assert Interval(5.5, 6.8).intersect(Interval(7.0, 8.2)) is None


def test_intervals_that_touch_at_a_point_do_overlap():
    # A single point is a real answer -- it is a tank held at exactly 26 °C,
    # which the narrow-overlap rule will then flag as impractical rather than
    # impossible. The two judgements are separate on purpose.
    assert Interval(20, 26).intersect(Interval(26, 30)) == Interval(26, 26)


def test_intersection_is_order_independent():
    a, b = Interval(20, 26), Interval(23, 28)
    assert a.intersect(b) == b.intersect(a)


def test_intersecting_a_set_narrows_as_species_are_added():
    assert intersect_all([Interval(20, 28), Interval(22, 27), Interval(24, 26)]) == Interval(24, 26)


def test_one_incompatible_member_makes_the_whole_set_impossible():
    assert intersect_all([Interval(20, 26), Interval(22, 27), Interval(30, 32)]) is None


def test_an_empty_set_has_no_intersection():
    assert intersect_all([]) is None


def test_a_single_interval_intersects_to_itself():
    assert intersect_all([Interval(20, 26)]) == Interval(20, 26)


def test_an_interval_cannot_end_before_it_starts():
    with pytest.raises(ValueError):
        Interval(8.0, 6.0)


def test_width_is_what_the_narrowness_rule_measures():
    assert Interval(24, 26).width() == 2.0
    assert Interval(26, 26).width() == 0.0
