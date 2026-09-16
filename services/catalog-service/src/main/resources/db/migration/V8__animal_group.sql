-- A shrimp is not a small fish.
--
-- V7 put invertebrates in the catalogue for the first time, and immediately
-- broke aquatics-advisor's stocking arithmetic -- which is exactly what a
-- shared species profile is supposed to make impossible, so it is worth being
-- precise about how.
--
-- The advisor sizes a stocking with `sum(max_size_cm * quantity)` against a
-- litres-per-adult-centimetre constant. That is a reasonable proxy for fish:
-- within the range a shop sells, length tracks bioload well enough to give
-- honest advice. It is badly wrong for invertebrates. Ten cherry shrimp are
-- 30 cm of animal and close to no bioload at all -- they do not have gills
-- working the way a fish's do, they eat biofilm, and a shrimp colony is
-- routinely added to a tank that is already fully stocked with fish.
--
-- Run against the real numbers, the advisor refused four scarlet badis and ten
-- cherry shrimp in a 40 L planted nano -- which is not an edge case, it is one
-- of the most common good tanks in the hobby. The shrimp supplied 79% of the
-- bioload it was refusing on.
--
-- The fix belongs here rather than in the advisor's rules, because "is this
-- animal a fish" is a fact about the species, and species facts are the
-- catalogue's to own. The advisor already refuses to keep its own copy of a
-- species profile for precisely this reason (ADR 0016). What the advisor owns
-- is what to DO about it: the bioload factor per group lives in rules.yaml,
-- where an aquarist can argue with it.

ALTER TABLE species_profile
    ADD COLUMN animal_group VARCHAR(16) NOT NULL DEFAULT 'FISH';

ALTER TABLE species_profile
    ADD CONSTRAINT species_animal_group_check
        CHECK (animal_group IN ('FISH', 'SHRIMP', 'SNAIL'));

-- Three groups, not two, and not a boolean. A snail and a shrimp differ in the
-- thing the advisor will ask next: a snail cannot be eaten by most fish and a
-- shrimp very much can, and an assassin snail is a predator of snails and of
-- nothing else. A boolean `is_invertebrate` would have to be replaced the first
-- time either rule is written.

UPDATE species_profile SET animal_group = 'SHRIMP'
 WHERE scientific_name IN ('Caridina multidentata', 'Neocaridina davidi',
                           'Palaemonetes paludosus');

UPDATE species_profile SET animal_group = 'SNAIL'
 WHERE scientific_name IN ('Neritina natalensis', 'Pomacea bridgesii',
                           'Planorbella duryi', 'Melanoides tuberculata',
                           'Clea helena');

-- The default exists so that this migration does not have to enumerate forty
-- fish, but it should not survive as a default: a species row added without
-- thinking about what kind of animal it is should be a decision, not a guess
-- that happens to be right most of the time.
ALTER TABLE species_profile ALTER COLUMN animal_group DROP DEFAULT;
