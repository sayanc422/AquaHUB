-- Fourteen products the catalogue was missing, named by the shop owner after
-- reading the live site: three large predatory catfish, one Malawi hap, four
-- American cichlids and six arowana.
--
-- Three things in here are not ordinary catalogue rows and are called out
-- rather than left to be discovered:
--
--   1. THE CITES FISH. Scleropages formosus is CITES Appendix I. That is a
--      legal fact about the animal, not a care preference, and it comes first
--      in care_notes on all four of its products for that reason. In the
--      United States the Endangered Species Act makes private import, sale and
--      interstate transport illegal whatever the fish's provenance; elsewhere
--      captive-bred stock moves only under CITES permits from registered
--      breeding operations, microchipped and certified per fish. A customer
--      reading a shop listing for this fish needs that before the price, and
--      "never soften a limitation" is the house rule that makes it the first
--      sentence rather than a footnote.
--
--      Four morphs, not the dozen the trade recognises. Super Red, Golden
--      Crossback, Red Tail Golden and Green are the four that name genuinely
--      different farm lines at genuinely different prices, and they are the
--      four a customer will have heard of. Chili Red, Blue Base, Banjar Red,
--      Tong Yan and the rest are grade and provenance distinctions inside those
--      lines, and listing them would imply the shop can tell them apart on
--      arrival, which it cannot. All four rows point at ONE species_profile:
--      they are one species, S. formosus, and four profiles would say
--      otherwise. (Same reasoning as V7's single Neocaridina davidi row behind
--      four shrimp colours.)
--
--   2. THE HYBRID. species_profile.scientific_name is NOT NULL (V1), and the
--      flowerhorn has no valid binomial -- it is a human-made cross of Central
--      American cichlids whose exact parentage is a breeder's trade secret and
--      differs between lines. Rather than invent a name that a customer or the
--      advisor could mistake for a real taxon, the column carries the explicit
--      placeholder 'Hybrid (Amphilophus spp. x others)' and care_notes says in
--      its first two sentences that this is a manufactured line and not a
--      species. That honesty matters more here than anywhere else in the
--      catalogue: every other row in this table names an animal you could look
--      up, and a customer has every reason to assume this one does too.
--
--   3. TWO UNSETTLED NAMES, listed under the trade's name and flagged in
--      care_notes rather than silently "corrected":
--        * Pseudoplatystoma fasciatum. Buitrago-Suarez & Burr's 2007 revision
--          restricted P. fasciatum to Guiana Shield drainages; the Amazon fish
--          that the aquarium trade ships as "tiger shovelnose" is now usually
--          P. punctifer. Both are valid species and the two are not reliably
--          separable in a shipping bag, so the listing says which name it is
--          using and admits it cannot guarantee which fish arrives.
--        * Vieja synspila. Confirmed by the owner as the intended fish after
--          being asked to disambiguate. It also appears as Paraneetroplus
--          synspilus and, under one synonymy, as Vieja melanura. The customer
--          asked for Vieja synspila, so that is the name on the row.
--
-- A fourth thing, less dramatic but worth stating: every max_size_cm and
-- min_tank_litres on the catfish and arowana below is the adult figure, not the
-- figure that makes the fish sellable. A redtail catfish at 10,000 L is not a
-- tank anyone reading this has; that is the point of writing it down. The
-- advisor will refuse these fish in every stocking a hobbyist proposes, which
-- is the correct answer and needed no rule written about monster fish.
--
-- animal_group is spelled out on every row. V8 dropped the 'FISH' default on
-- purpose -- "what kind of animal is this" should be a decision, not a guess
-- that happens to be right.

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, animal_group, care_notes) VALUES

 -- Predatory catfish ------------------------------------------------------
 ('Phractocephalus hemioliopterus', 'Redtail Catfish', 130.00, 10000, 1, 20.0, 26.0, 5.5, 7.5, 2.0, 15.0,
  'AGGRESSIVE', 'ADVANCED', 'CARNIVORE', FALSE, 'FISH',
  'Sold at 10 cm, reaches 130 cm and over 40 kg, and gets most of the way there in five years. It is not aggressive so much as indiscriminate -- anything that fits in its mouth is food, including a tankmate two-thirds its own length. No tank sold as furniture will hold an adult: the honest options are a heated indoor pond, a public aquarium that wants one, or not buying the fish. Shops that do not say this sell a lot of them.'),
 ('Pseudoplatystoma fasciatum', 'Tiger Shovelnose Catfish', 100.00, 5000, 1, 22.0, 26.0, 6.0, 7.8, 4.0, 18.0,
  'AGGRESSIVE', 'ADVANCED', 'CARNIVORE', FALSE, 'FISH',
  'Reaches a metre and patrols constantly, so tank length matters more than volume -- under about 3 m it rubs its snout raw against the glass and the damage does not heal. Another fish sold at 10 cm that a home aquarium cannot finish. On the name: the 2007 revision of the genus restricted P. fasciatum to the Guiana Shield rivers, and the Amazon fish the trade ships as "tiger shovelnose" is usually P. punctifer. We list the trade name and cannot promise which of the two is in the bag.'),
 ('Pangasianodon hypophthalmus', 'Iridescent Shark Catfish', 100.00, 4000, 3, 22.0, 28.0, 6.5, 7.5, 2.0, 20.0,
  'SEMI_AGGRESSIVE', 'ADVANCED', 'OMNIVORE', FALSE, 'FISH',
  'A shoaling river catfish with poor eyesight and a violent panic response -- a sudden light or a tap on the glass sends it into the wall hard enough to kill it, which is why so many die in their first year in living rooms. It reaches a metre and wants company, so the minimum group here is honest rather than achievable: three of these need a tank essentially nobody has. This is the fish sold as "pangasius" in supermarket freezers, which is a fair guide to the adult size.'),

 -- Lake Malawi ------------------------------------------------------------
 ('Cyrtocara moorii', 'Dolphin Cichlid', 25.00, 400, 4, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
  'A sand-sifting, open-water hap, not a rock-grazing mbuna, and that difference decides the tank. It is mild enough to be bullied off its food by most of the fish on the Malawi page and needs open sand to feed over rather than a rock wall. Males grow the nuchal hump and hold the strongest blue; one male to three or four females. Same water as the mbuna and almost nothing else in common with them.'),

 -- South America ----------------------------------------------------------
 ('Andinoacara rivulatus', 'Green Terror', 30.00, 400, 1, 20.0, 26.0, 6.5, 8.0, 5.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', FALSE, 'FISH',
  'Milder than the name suggests and still a fish that picks a fight with anything it can reach. Males reach 30 cm, develop a nuchal hump, and will kill a female they have not accepted -- pairs go in behind a divider or not at all. Trade naming is a mess worth knowing about: the orange-edged "gold saum" fish is A. rivulatus and the white-edged "silver saum" is usually A. stalsbergi, a separate species sold under the same common name.'),

 -- Central America --------------------------------------------------------
 ('Herichthys cyanoguttatus', 'Texas Cichlid', 30.00, 450, 1, 20.0, 28.0, 6.5, 8.0, 8.0, 25.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE, 'FISH',
  'The only cichlid native to the United States, and the only large American cichlid here that does not need a heated room -- it is comfortable down to 20 C. Thirty centimetres, digs the tank up weekly and rearranges anything not glued down. Territorial enough that it is a species tank or a very large tank of equals; it will not share with something it can dominate.'),
 ('Hybrid (Amphilophus spp. x others)', 'Flowerhorn', 30.00, 400, 1, 26.0, 30.0, 6.5, 8.0, 9.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE, 'FISH',
  'This is not a species. The flowerhorn is a human-made hybrid line bred in South East Asia from Central American cichlids -- Amphilophus, Cichlasoma and others, with the exact cross a trade secret that differs between breeders -- and selected for the nuchal hump and the colour. It has no valid scientific name, no wild population and no field guide behind it, so its care numbers here come from the keeping literature and not from any published study of a wild fish. What is reliable: 30 cm, aggressive enough to need a tank of its own, and the hump is fat and fluid, not a sign of health. Males are commonly sterile.'),
 ('Vieja synspila', 'Redhead Cichlid', 35.00, 500, 1, 24.0, 30.0, 7.0, 8.0, 8.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE, 'FISH',
  'Thirty-five centimetres and deep-bodied, so tank width matters as much as length -- in a 45 cm-wide tank it cannot turn without bending. The red comes in on the head with age and is much stronger on males; a juvenile in a shop tank shows none of it. The name is unsettled: this fish is also published as Paraneetroplus synspilus and, under one synonymy, as Vieja melanura.'),

 -- Arowana ----------------------------------------------------------------
 ('Osteoglossum bicirrhosum', 'Silver Arowana', 120.00, 3000, 1, 24.0, 30.0, 6.0, 7.5, 2.0, 15.0,
  'AGGRESSIVE', 'ADVANCED', 'CARNIVORE', TRUE, 'FISH',
  'Reaches 100-120 cm and lives in the top 15 cm of the water, so surface area decides the tank and depth contributes almost nothing -- roughly 3 m by 1 m is the working floor for an adult, which is a pond. It jumps hard enough to shift an unweighted lid; in the wild it takes insects off branches above the water. Drop-eye, the permanent downward-rolled eye seen on most captive adults, comes from a fish spending its life looking at a tank floor instead of up at a surface, and it does not reverse.'),
 ('Scleropages jardinii', 'Jardini Arowana', 90.00, 2500, 1, 24.0, 30.0, 6.5, 7.5, 5.0, 15.0,
  'AGGRESSIVE', 'ADVANCED', 'CARNIVORE', TRUE, 'FISH',
  'Up to 90 cm, and harder-tempered than the silver -- Australian and New Guinea Scleropages hold territory in the wild and do not stop doing it in a tank. One per tank unless the tank is enormous, and nothing in with it that fits in its mouth. Same rules as every arowana: surface area over depth, and a lid it cannot lift.'),
 ('Scleropages formosus', 'Asian Arowana', 90.00, 2500, 1, 24.0, 30.0, 6.5, 7.5, 5.0, 15.0,
  'AGGRESSIVE', 'ADVANCED', 'CARNIVORE', TRUE, 'FISH',
  'CITES Appendix I. Read this before anything else: international commercial trade in wild-caught Scleropages formosus is prohibited outright, and captive-bred fish move only under CITES permits from registered breeding operations, individually microchipped and certified per fish. In the United States the Endangered Species Act makes import, sale and interstate transport illegal for private keepers regardless of where the fish was bred, and several other countries restrict it similarly. Check what your own jurisdiction allows before you consider the price -- this is not paperwork a shop can sort out on your behalf afterwards. The fish itself: 90 cm, territorial, surface-dwelling, jumps, one per tank, and the same surface-area-over-depth rule as every other arowana.');

-- ============================================================= products ==
--
-- image_key is set here rather than left NULL: every one of these fourteen has
-- a photograph committed in the same change (V15 wires them, and
-- services/storefront/public/species/CREDITS.md records the licence). Splitting
-- the key into its own migration keeps this file about the fish.

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category        WHERE slug            = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name),
       NULL
  FROM (VALUES
    -- Predatory catfish
    ('FSH-PCT-01', 'redtail-catfish', 'Redtail Catfish',
     'Sold at 10 cm. Reaches 130 cm and 40 kg. There is no home aquarium that finishes this fish -- please read the care profile before you read the price.',
     250000, 'catfish-predatory', 'Phractocephalus hemioliopterus'),
    ('FSH-PCT-02', 'tiger-shovelnose-catfish', 'Tiger Shovelnose Catfish',
     'Sold at 10 cm. Reaches a metre and needs three metres of tank length to swim without wearing its snout away.',
     300000, 'catfish-predatory', 'Pseudoplatystoma fasciatum'),
    ('FSH-PCT-03', 'iridescent-shark', 'Iridescent Shark Catfish',
     'The cheapest metre-long fish in the shop, and the one most often bought by accident. Shoaling, nervous, and it swims into glass when startled.',
     45000, 'catfish-predatory', 'Pangasianodon hypophthalmus'),

    -- Lake Malawi
    ('FSH-MAL-10', 'dolphin-cichlid', 'Dolphin Cichlid',
     'Tank-bred. A blue sand-sifting hap with a nuchal hump. Calm for a Malawi fish -- keep it with peacocks and haps, not with mbuna.',
     130000, 'malawi', 'Cyrtocara moorii'),

    -- South America
    ('FSH-SAM-03', 'green-terror', 'Green Terror',
     'Tank-bred. Pearled blue-green with an orange fin margin. Thirty centimetres and it means the name.',
     95000, 'cichlids-south-american', 'Andinoacara rivulatus'),

    -- Central America
    ('FSH-CAM-03', 'texas-cichlid', 'Texas Cichlid',
     'Tank-bred. The only cichlid native to the United States, and the one that tolerates an unheated room.',
     110000, 'cichlids-central-american', 'Herichthys cyanoguttatus'),
    ('FSH-CAM-04', 'flowerhorn', 'Flowerhorn',
     'Tank-bred. A man-made hybrid line, not a species -- bred for the head hump and the colour. See the care profile for what that means.',
     180000, 'cichlids-central-american', 'Hybrid (Amphilophus spp. x others)'),
    ('FSH-CAM-05', 'redhead-cichlid', 'Redhead Cichlid (Vieja)',
     'Tank-bred. Thirty-five centimetres and deep-bodied; the red comes in on the head with age.',
     160000, 'cichlids-central-american', 'Vieja synspila'),

    -- Arowana
    ('FSH-ARO-01', 'silver-arowana', 'Silver Arowana',
     'Sold at 15 cm. Reaches 120 cm, lives at the surface, and jumps. Surface area decides the tank, not litres.',
     450000, 'arowana', 'Osteoglossum bicirrhosum'),
    ('FSH-ARO-02', 'jardini-arowana', 'Jardini Arowana',
     'Sold at 15 cm. Reaches 90 cm and is the bad-tempered one. One per tank, and a lid it cannot lift.',
     950000, 'arowana', 'Scleropages jardinii'),

    -- Asian arowana: four trade morphs, one species, one care profile.
    -- CITES Appendix I -- every summary says so, not just the care profile,
    -- because the summary is what a customer reads on the grid tile.
    ('FSH-ARO-03', 'asian-arowana-super-red', 'Asian Arowana -- Super Red',
     'CITES Appendix I: restricted or illegal to own in many countries, including the US. Certified captive-bred, microchipped. Read the care profile before enquiring.',
     8500000, 'arowana', 'Scleropages formosus'),
    ('FSH-ARO-04', 'asian-arowana-golden-crossback', 'Asian Arowana -- Golden Crossback',
     'CITES Appendix I: restricted or illegal to own in many countries, including the US. Certified captive-bred, microchipped. The Malaysian line whose gold crosses the back completely.',
     7500000, 'arowana', 'Scleropages formosus'),
    ('FSH-ARO-05', 'asian-arowana-red-tail-golden', 'Asian Arowana -- Red Tail Golden',
     'CITES Appendix I: restricted or illegal to own in many countries, including the US. Certified captive-bred, microchipped. The Indonesian golden line; gold stops at the fourth scale row.',
     2500000, 'arowana', 'Scleropages formosus'),
    ('FSH-ARO-06', 'asian-arowana-green', 'Asian Arowana -- Green',
     'CITES Appendix I: restricted or illegal to own in many countries, including the US. Certified captive-bred, microchipped. The widest-ranging and least expensive of the four morphs we list.',
     900000, 'arowana', 'Scleropages formosus')
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);
