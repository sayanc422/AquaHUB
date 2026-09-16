# 19. The catalogue says what kind of animal it is

**Status:** Accepted · **Phase:** 6 · **Extends** [ADR 0017](0017-advisor-owns-no-data.md)

## Context

V7 put invertebrates in the catalogue for the first time — shrimp and snails, as a root section of
their own. Running the resulting catalogue through `aquatics-advisor` produced this:

```
--- A planted nano done right (40 L) -> REFUSED
    [REFUSED] Fully grown, this stocking needs about 46 L and the tank is 40 L.
```

Four scarlet badis and ten cherry shrimp in a 40 L planted tank. That is not an edge case, it is
one of the best-known good tanks in the hobby, and the advisor refused it.

The cause is that the advisor sizes a stocking as `sum(adult_length × quantity) × litres_per_cm`.
Length is a fair proxy for bioload **within fish**: over the range a shop sells, a longer fish eats
more and produces more waste. It is badly wrong for invertebrates. The ten shrimp were 30 of the
38 cm being measured — 79% of the bioload the advisor refused on — and ten cherry shrimp have close
to no bioload at all. They graze biofilm, and a shrimp colony is routinely added to a tank that is
already fully stocked with fish.

Nothing was wrong with the rule when it was written. It became wrong the moment the catalogue
started selling something that is not a fish.

## Decision

`species_profile` grows an `animal_group` column — `FISH`, `SHRIMP` or `SNAIL` — and the advisor
applies a per-group bioload factor from `rules.yaml`.

The split of ownership follows [ADR 0017](0017-advisor-owns-no-data.md) exactly. *What kind of
animal this is* is a fact about the species, and species facts are the catalogue's. *What to do
about it* is a judgement that changes with argument and experience, so it is a number in
`rules.yaml` where an aquarist can change it without a deployment:

```yaml
bioload_factor:
  FISH: 1.0
  SHRIMP: 0.1
  SNAIL: 0.15
```

Three values rather than a boolean, and deliberately not zero.

**Three, not a boolean.** `is_invertebrate` would have to be replaced the first time a rule
distinguishes a shrimp from a snail — and that rule is already foreseeable: most fish that can eat
a shrimp cannot eat a snail, and an assassin snail preys on snails and nothing else. A boolean
answers today's question and blocks tomorrow's.

**Not zero.** A hundred shrimp in a 20 L tank *is* a stocking problem. A rule that can never say no
about invertebrates is no more useful than the one it replaced, in the opposite direction. The
advisor still refuses that tank, and there is a test that says so.

## Cost

- **A column with three values is a taxonomy, and taxonomies grow.** Crayfish, crabs and freshwater
  clams are all plausible stock and none of them is a shrimp or a snail. Adding a value means a
  migration, a CHECK constraint change and a new factor. That is the price of the enum over free
  text, and it is worth paying: free text would have let `Shrimp`, `shrimp` and `SHRIMPS` coexist.
- **The factors are judgement, not measurement.** 0.1 and 0.15 are an aquarist's estimate, and the
  file says so. They have not been validated against nitrate readings in a real tank, and nothing
  here pretends otherwise.
- **The advisor now has a field it must tolerate missing.** A catalogue that has not deployed V8
  would omit `animalGroup`, so the adapter defaults it to `FISH`. That default is chosen to fail in
  the strict direction — over-cautioning is a customer buying a larger tank, and the alternative is
  telling somebody their tank is fine when it is not.
- **Version skew is now visible in the advice, not just in the logs.** Between deploying the advisor
  and deploying the catalogue's V8, customers get the old, wrong answer about shrimp. The order is
  therefore catalogue first. Nothing enforces that ordering; it is a note in the release notes,
  which is weaker than a check.

## What this did not change

The predation rule. A cherry shrimp with an oscar is still refused, on the same 2.5 size ratio as
before — softening the stocking arithmetic must not soften anything about who eats whom, and there
is a test asserting exactly that pairing.

## How it was found

By running the real catalogue through the real advisor, not by reading the rule. The rule reads
correctly; it was the data underneath it that changed. This is the third defect in this repository
found by running something and the third that a review would not have caught.
