-- The taxonomy, settled.
--
-- V3 built the tree from guesswork about what the shop would sell. This
-- migration replaces the guesses with the owner's answers, and it is meant to
-- be the last structural change to the category tree before there are orders
-- pointing at it. Re-parenting a category once customers have bookmarked it is
-- a redirect problem; doing it now is an UPDATE.
--
-- Four changes:
--
--   1. Cichlids. V3 put South American and Central American as siblings of
--      African, with no "American" level at all. The owner wants American as a
--      parent of Central and South -- which is also the correct relationship,
--      and fixes the thing flagged as an open question: a flat list where one
--      entry contains its own siblings.
--
--   2. Catfish. The family gets the two profiles the owner actually sells by:
--      small catfish for small tanks, and large catfish. The split is a rule,
--      not a judgement call -- see below. Loaches move out, because a loach is
--      not a catfish and "Catfish & Loaches" was a shelf label, not a family.
--
--   3. Badidae. Badis and Dario are stock the owner wants and the tree had
--      nowhere to put them. They are not tetras, barbs, cichlids or gouramis.
--
--   4. Invertebrates become a root section alongside Live Fishes and Live
--      Plants, with Shrimp and Snails inside. They were buried at
--      Live Fishes > Freshwater > Shrimp & Snails, which is wrong twice: a
--      shrimp is not a fish, and the section a customer comes to the shop for
--      was four clicks deep.
--
-- Saltwater stays COMING_SOON and unstocked, as instructed.

-- ========================================================== 1. CICHLIDS ==

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'cichlids-american', 'American Cichlids',
       'Two very different halves. Central American fish are large, hard-water and territorial; South American fish are soft-water and mostly milder. The one thing they share is that neither belongs in a rift-lake tank.',
       'Central and South American.', 20, id, 'ACTIVE'
  FROM category WHERE slug = 'cichlids';

UPDATE category
   SET parent_id = (SELECT id FROM category WHERE slug = 'cichlids-american'),
       sort_order = CASE slug WHEN 'cichlids-central-american' THEN 10 ELSE 20 END
 WHERE slug IN ('cichlids-central-american', 'cichlids-south-american');

-- The African lakes already exist. What was missing is the catch-all: African
-- cichlids that are not from one of the three great lakes. V3 called that
-- 'west-african', which is narrower than the fish it has to hold -- jewel
-- cichlids are West African, but Steatocranus is Congo and Nanochromis is not
-- riverine in the same sense. Rename it to what it is.
UPDATE category
   SET slug = 'african-other', name = 'Other African Cichlids',
       description = 'Everything African that is not a Malawi, Tanganyika or Victoria fish -- mostly river species from West and Central Africa, which want softer water than the lakes and a very different tank.',
       teaser = 'Kribensis, jewels and river species.', sort_order = 40
 WHERE slug = 'west-african';

-- =========================================================== 2. CATFISH ==
--
-- The split is on adult size and minimum tank, and the rule is written down
-- here so that a shop assistant adding the next species does not have to guess:
--
--     small  = adult under 15 cm AND minimum tank 150 L or less
--     large  = anything else
--
-- A rule rather than a feel, because the whole point of the section is that a
-- customer with a 60 L tank can browse one page and trust it. Bristlenose sits
-- in `small` on that rule (13 cm, 120 L) even though it is a pleco, and that is
-- the right answer for the customer even if it looks odd next to the corys.

UPDATE category
   SET name = 'Catfish',
       description = 'Sorted by the question that decides whether you can keep one: how big it gets. Most catfish are sold at 4 cm and a good number of them do not stay there.',
       teaser = 'Sorted by adult size, not by looks.'
 WHERE slug = 'catfish';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('catfish-small', 'Small Catfish',
     'Adults under 15 cm, and happy in 150 L or less. Everything on this page can live in a normal community tank for its whole life.',
     'For tanks from 60 L up.', 10),
    ('catfish-large', 'Large Catfish',
     'Adults over 15 cm, or needing more than 150 L. These are fish you buy a tank for, not fish you add to one.',
     'Buy the tank first.', 20)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'catfish';

-- Corydoras were already a section; they move under `small` unchanged.
UPDATE category SET parent_id = (SELECT id FROM category WHERE slug = 'catfish-small'), sort_order = 10
 WHERE slug = 'catfish-corydoras';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('catfish-oto', 'Otocinclus & Dwarf Suckers',
     'The only algae eater that stays under 5 cm. They need a mature tank with real biofilm -- a new tank starves them, which is why they have a reputation for dying.',
     'Under 5 cm, and a mature tank.', 20),
    ('catfish-bristlenose', 'Bristlenose Plecos',
     'The pleco that stays small. Rasps wood, which it needs in the tank to digest properly.',
     'A pleco for a normal tank.', 30)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'catfish-small';

-- 'catfish-pleco' held otocinclus and bristlenose together, which put a 4 cm
-- fish and a 13 cm fish on the same page. It becomes the large plecos only.
UPDATE category
   SET slug = 'catfish-pleco-large', name = 'Large Plecos',
       description = 'Common and sailfin plecos reach 40-50 cm and produce waste in proportion. Sold at 6 cm by shops that do not say so; we do.',
       teaser = 'Reaching 40 cm and up.', sort_order = 10,
       parent_id = (SELECT id FROM category WHERE slug = 'catfish-large')
 WHERE slug = 'catfish-pleco';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'catfish-synodontis', 'Synodontis',
       'African catfish, hard-water, and the only catfish that suits a rift-lake tank. Some swim upside down and there is nothing wrong with them.',
       'The rift-lake catfish.', 20, id, 'ACTIVE'
  FROM category WHERE slug = 'catfish-large';

-- Loaches are Cobitidae. They were filed under catfish because they are both
-- bottom-dwellers, which is a shelf, not a family.
UPDATE category
   SET slug = 'loaches', name = 'Loaches',
       description = 'Burrowers and social diggers. Sand rather than gravel, caves, and never one on its own.',
       teaser = 'Kuhli, hillstream and clown loaches.', sort_order = 25,
       parent_id = (SELECT id FROM category WHERE slug = 'freshwater')
 WHERE slug = 'catfish-loach';

-- =========================================================== 3. BADIDAE ==

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'badidae', 'Badidae -- Badis & Dario',
       'Tiny, slow-moving, micro-predatory fish from South and South East Asia. They will not compete for food with anything fast, they generally refuse flake, and in a tank of their own they are among the best fish in the hobby.',
       'Scarlet badis and their relatives.', 35, id, 'ACTIVE'
  FROM category WHERE slug = 'freshwater';

-- ===================================================== 4. INVERTEBRATES ==

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status) VALUES
 ('invertebrates', 'Invertebrates',
  'Shrimp and snails. Copper kills every animal on these pages, so check any medication, plant fertiliser or tap conditioner before it goes in a tank with them.',
  'Shrimp and snails. No copper.', 20, NULL, 'ACTIVE');

-- 'livestock-inverts' has held the shrimp since the first seed. Rename and
-- re-parent rather than create-and-delete: two products point at this row.
UPDATE category
   SET slug = 'inverts-shrimp', name = 'Shrimp',
       description = 'Dwarf shrimp breed in the tank and a colony pays for itself. All the Neocaridina colours interbreed and revert to wild brown within a few generations -- keep one colour per tank.',
       teaser = 'Neocaridina colours and Amano.', sort_order = 10,
       parent_id = (SELECT id FROM category WHERE slug = 'invertebrates')
 WHERE slug = 'livestock-inverts';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'inverts-snails', 'Snails',
       'Clean-up crew and, in two cases, pest control. None of these will eat a healthy plant; the ones blamed for it were eating a plant that was already dying.',
       'Nerites, mystery and assassin snails.', 20, id, 'ACTIVE'
  FROM category WHERE slug = 'invertebrates';

-- Live Plants moves to sort 30 so the roots read: Live Fishes, Invertebrates,
-- Live Plants, Aquarium Supplies.
UPDATE category SET sort_order = 30 WHERE slug = 'plants';
UPDATE category SET sort_order = 40 WHERE slug = 'supplies';

-- ========================================================= care profiles ==
--
-- Note what is NOT here: a second `Neocaridina davidi` row. Blue Dream, Blue
-- Velvet, Yellow and Red Cherry are one species in four colours, and they
-- interbreed freely -- which is exactly why the shop has to tell customers to
-- keep one colour per tank. Four species rows would say the opposite, and would
-- also break the scalar subquery the product insert below depends on.

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, care_notes) VALUES

 -- Badidae ---------------------------------------------------------------
 ('Dario dario', 'Scarlet Badis', 2.0, 30, 4, 22.0, 26.0, 6.5, 7.5, 4.0, 12.0,
  'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE,
  'Two centimetres, and it will not eat flake. Live or frozen food only, and no fast tankmates -- a single male in a planted nano is the way to keep one.'),
 ('Badis badis', 'Blue Badis', 6.0, 60, 2, 20.0, 26.0, 6.5, 7.8, 5.0, 15.0,
  'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', TRUE,
  'Changes colour with mood, which is where "chameleon fish" comes from. Males hold small territories around caves and dispute the borders without much damage.'),
 ('Dario hysginon', 'Red Melon Badis', 2.5, 40, 4, 22.0, 27.0, 6.0, 7.5, 3.0, 10.0,
  'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE,
  'As demanding as the scarlet badis about food, and slightly bolder. Blackwater fish -- leaf litter suits it.'),

 -- Small catfish ---------------------------------------------------------
 ('Corydoras aeneus', 'Bronze Cory', 7.0, 80, 6, 22.0, 26.0, 6.0, 7.8, 2.0, 15.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'The hardiest cory there is. Sand, not gravel -- they feed by sifting and gravel wears their barbels away.'),
 ('Corydoras sterbai', 'Sterbai Cory', 6.5, 80, 6, 24.0, 29.0, 6.0, 7.6, 2.0, 12.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'The one cory that takes discus temperatures. Otherwise identical in care to the rest.'),
 ('Corydoras pygmaeus', 'Pygmy Cory', 3.0, 40, 8, 22.0, 26.0, 6.2, 7.4, 2.0, 12.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'Shoals in midwater rather than on the bottom, unlike every other cory. Ten is a better number than six.'),

 -- Large catfish ---------------------------------------------------------
 ('Pterygoplichthys gibbiceps', 'Sailfin Pleco', 45.0, 700, 1, 23.0, 28.0, 6.5, 7.8, 4.0, 20.0,
  'PEACEFUL', 'INTERMEDIATE', 'HERBIVORE', FALSE,
  'Sold at 6 cm, reaches 45 cm, lives 15 years and produces more waste than any fish of its size. Peaceful throughout -- the problem is never temperament, it is litres.'),
 ('Hypostomus plecostomus', 'Common Pleco', 40.0, 600, 1, 22.0, 28.0, 6.5, 7.8, 4.0, 20.0,
  'PEACEFUL', 'INTERMEDIATE', 'HERBIVORE', FALSE,
  'The fish most often bought to solve an algae problem and most often rehomed two years later. Needs wood, and needs a tank most people do not have.'),
 ('Synodontis eupterus', 'Featherfin Synodontis', 20.0, 250, 1, 22.0, 28.0, 6.5, 8.0, 6.0, 20.0,
  'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', TRUE,
  'Nocturnal, and it will take anything small enough at night. Fine with rift-lake cichlids, which is most of what it is bought for.'),
 ('Synodontis multipunctatus', 'Cuckoo Catfish', 15.0, 250, 4, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'SEMI_AGGRESSIVE', 'ADVANCED', 'CARNIVORE', TRUE,
  'A Tanganyikan brood parasite: it spawns into a mouthbrooding cichlid''s clutch and the cichlid raises the catfish instead. Keep four or more.'),

 -- Shrimp ----------------------------------------------------------------
 ('Palaemonetes paludosus', 'Ghost Shrimp', 4.0, 40, 5, 20.0, 28.0, 7.0, 8.0, 5.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'Cheap, transparent and a genuine scavenger. Sold as feeders elsewhere, which is why quality varies so much -- ours are quarantined like everything else.'),

 -- Snails ----------------------------------------------------------------
 ('Neritina natalensis', 'Nerite Snail', 2.5, 20, 1, 22.0, 28.0, 7.0, 8.5, 6.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'HERBIVORE', TRUE,
  'The best algae eater in the shop and it cannot breed in fresh water, so it never becomes a plague. It will lay white eggs on hardscape that do not hatch.'),
 ('Pomacea bridgesii', 'Mystery Snail', 6.0, 40, 1, 20.0, 28.0, 7.0, 8.0, 6.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'Needs an air gap above the water line to lay, and calcium in the water or the shell pits. Does not eat healthy plants, despite the family reputation.'),
 ('Planorbella duryi', 'Ramshorn Snail', 2.0, 20, 1, 18.0, 28.0, 7.0, 8.0, 5.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'Breeds to the food available, so a population explosion is a feeding problem rather than a snail problem.'),
 ('Melanoides tuberculata', 'Malaysian Trumpet Snail', 3.0, 20, 1, 20.0, 30.0, 7.0, 8.5, 6.0, 25.0,
  'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE,
  'Lives in the substrate and turns it over, which stops anaerobic pockets forming under a deep sand bed. Livebearing and effectively impossible to remove once in.'),
 ('Clea helena', 'Assassin Snail', 2.0, 20, 1, 22.0, 28.0, 7.0, 8.0, 6.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'CARNIVORE', TRUE,
  'Eats other snails, which is the point. It breeds slowly and will not take over. Will also take shrimplets, so not for a breeding shrimp tank.');

-- ============================================================= products ==

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category        WHERE slug            = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name),
       -- NULL, not a key. Not one of these fish has been photographed, and the
       -- storefront draws a designed placeholder for NULL and a broken image
       -- for a key with no file behind it.
       NULL
  FROM (VALUES
    -- Badidae
    ('FSH-BAD-01', 'scarlet-badis',     'Scarlet Badis',
     'Tank-bred. Two centimetres of red and blue. Live or frozen food only -- please read the care profile.',
     45000,  'badidae', 'Dario dario'),
    ('FSH-BAD-02', 'blue-badis',        'Blue Badis',
     'Tank-bred. The chameleon fish -- colour changes with mood and territory.',
     38000,  'badidae', 'Badis badis'),
    ('FSH-BAD-03', 'red-melon-badis',   'Red Melon Badis',
     'Tank-bred. A blackwater Dario; keep it over leaf litter.',
     55000,  'badidae', 'Dario hysginon'),

    -- Small catfish
    ('FSH-COR-02', 'bronze-cory',       'Bronze Cory',
     'Tank-bred. The hardiest cory there is. Six minimum, and sand rather than gravel.',
     18000,  'catfish-corydoras', 'Corydoras aeneus'),
    ('FSH-COR-03', 'sterbai-cory',      'Sterbai Cory',
     'Tank-bred. The cory that takes discus temperatures.',
     32000,  'catfish-corydoras', 'Corydoras sterbai'),
    ('FSH-COR-04', 'pygmy-cory',        'Pygmy Cory',
     'Tank-bred. Three centimetres, and it shoals in midwater. Ten is better than six.',
     15000,  'catfish-corydoras', 'Corydoras pygmaeus'),

    -- Large catfish
    ('FSH-PLE-01', 'sailfin-pleco',     'Sailfin Pleco',
     'Sold at 6 cm. Reaches 45 cm and needs 700 L. We would rather you bought the bristlenose.',
     40000,  'catfish-pleco-large', 'Pterygoplichthys gibbiceps'),
    ('FSH-PLE-02', 'common-pleco',      'Common Pleco',
     'Sold at 6 cm. Reaches 40 cm. Not an algae solution for a 100 L tank.',
     30000,  'catfish-pleco-large', 'Hypostomus plecostomus'),
    ('FSH-SYN-01', 'featherfin-synodontis', 'Featherfin Synodontis',
     'Tank-bred. Nocturnal African catfish, and the right one for a rift-lake tank.',
     95000,  'catfish-synodontis', 'Synodontis eupterus'),
    ('FSH-SYN-02', 'cuckoo-catfish',    'Cuckoo Catfish',
     'Tank-bred. A brood parasite of Tanganyikan mouthbrooders. Four or more.',
     150000, 'catfish-synodontis', 'Synodontis multipunctatus'),

    -- Shrimp. Amano and Red Cherry already exist and are updated below.
    ('INV-NEO-02', 'blue-dream-shrimp',  'Blue Dream Shrimp',
     'Tank-bred. Solid deep blue Neocaridina. One colour per tank -- see the description.',
     22000,  'inverts-shrimp', 'Neocaridina davidi'),
    ('INV-NEO-03', 'blue-velvet-shrimp', 'Blue Velvet Shrimp',
     'Tank-bred. The softer, paler blue -- sold elsewhere as blue cherry. Same species as the red.',
     20000,  'inverts-shrimp', 'Neocaridina davidi'),
    ('INV-NEO-04', 'yellow-shrimp',      'Yellow Goldenback Shrimp',
     'Tank-bred. Yellow Neocaridina with a gold dorsal stripe.',
     18000,  'inverts-shrimp', 'Neocaridina davidi'),
    ('INV-GHO-01', 'ghost-shrimp',       'Ghost Shrimp',
     'Transparent, cheap and a real scavenger. Quarantined, unlike most on the market.',
     6000,   'inverts-shrimp', 'Palaemonetes paludosus'),

    -- Snails
    ('INV-NER-01', 'nerite-snail',       'Nerite Snail',
     'The best algae eater we sell, and it cannot breed in fresh water.',
     9000,   'inverts-snails', 'Neritina natalensis'),
    ('INV-MYS-01', 'mystery-snail',      'Mystery Snail',
     'Six centimetres of snail. Needs calcium in the water and an air gap to lay.',
     14000,  'inverts-snails', 'Pomacea bridgesii'),
    ('INV-RAM-01', 'ramshorn-snail',     'Ramshorn Snail',
     'Sold in tens. Breeds to the food available, so feed less rather than buy fewer.',
     5000,   'inverts-snails', 'Planorbella duryi'),
    ('INV-MTS-01', 'malaysian-trumpet-snail', 'Malaysian Trumpet Snail',
     'Turns the substrate over from below. Effectively permanent once in the tank.',
     5000,   'inverts-snails', 'Melanoides tuberculata'),
    ('INV-ASS-01', 'assassin-snail',     'Assassin Snail',
     'Eats other snails. Not for a tank where shrimplets matter.',
     16000,  'inverts-snails', 'Clea helena')
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);

-- -------------------------------------------------------- re-shelving ----

-- Otocinclus and bristlenose leave the mixed pleco page for their own.
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'catfish-oto')
 WHERE sku = 'FSH-OTO-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'catfish-bristlenose')
 WHERE sku = 'FSH-BNP-01';

-- The cherry shrimp is one of four colours now, so its name has to say which.
UPDATE product
   SET name = 'Red Cherry Shrimp',
       summary = 'Tank-bred. Colony-forming and grade-sorted. One Neocaridina colour per tank.'
 WHERE sku = 'INV-CHE-01';

-- ------------------------------------------------------- broken images ---
--
-- V5 set `species/<slug>.jpg` on all six Malawi fish. Three of those files were
-- never delivered, so three product pages have been rendering a broken image
-- since V5 rather than the placeholder they should. A key is a promise that the
-- file exists; these ones were not kept.
UPDATE product SET image_key = NULL
 WHERE slug IN ('saulosi', 'red-zebra', 'acei-yellow-tail');

-- Same defect on the category side: V5 tried to set a key on 'live-plants',
-- which is not a slug that exists -- the root is 'plants' -- so the UPDATE
-- matched nothing and nobody noticed. There is no sections/ photograph on disk
-- at all yet, so the honest fix is to clear the lot rather than add another.
UPDATE category SET image_key = NULL WHERE image_key IS NOT NULL;

-- ------------------------------------------------------ dead sections ----
--
-- An ACTIVE leaf with no products is a link on the shop front that goes to an
-- empty page. Two have been in that state since V3 and nobody looked, because
-- nothing renders the tree and the products together. COMING_SOON is what the
-- status column is for -- the customer gets a greyed tile and a reason, which
-- is what Saltwater already does.
UPDATE category c
   SET status = 'COMING_SOON'
 WHERE c.status = 'ACTIVE'
   AND NOT EXISTS (SELECT 1 FROM category k WHERE k.parent_id = c.id)
   AND NOT EXISTS (SELECT 1 FROM product  p WHERE p.category_id = c.id);

-- The African Cichlids teaser still named the section that no longer exists
-- ("...Victoria, West Africa"). A tile's teaser is a promise about what is
-- behind it, so it has to track the rename above.
UPDATE category
   SET teaser = 'Malawi, Tanganyika, Victoria and beyond.'
 WHERE slug = 'cichlids-african';
