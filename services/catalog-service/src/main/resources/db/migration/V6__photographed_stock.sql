-- The photographed fish.
--
-- Ten photographs arrived, and only three of them were of fish already in the
-- catalogue. The other seven are stock worth carrying, and two of them finally
-- put something in the South American and Central American sections, which
-- have been sitting empty and ACTIVE since the tree was built.
--
-- Every product slug matches its photograph's filename, because the slug IS the
-- wiring: catalog stores the key `species/<slug>.jpg`, the storefront composes
-- the URL, and a photograph named after the fish it shows needs no lookup table.

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, care_notes) VALUES

 -- Lake Malawi ----------------------------------------------------------
 ('Sciaenochromis fryeri', 'Electric Blue Ahli', 15.0, 300, 1, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', TRUE,
  'An open-water hunter, not a rock grazer. Males hold the blue; females are silver. One male to three or four females.'),
 ('Melanochromis johannii', 'Blue Johanni', 10.0, 200, 5, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE,
  'Males black with electric blue barring, females solid orange -- they look like different species.'),
 ('Aulonocara baenschi', 'Nkhomo Benga Peacock', 11.0, 250, 4, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'PEACEFUL', 'BEGINNER', 'CARNIVORE', TRUE,
  'Sifts sand for invertebrates. Far milder than mbuna, and it will be bullied off its food by them.'),

 -- South America --------------------------------------------------------
 ('Heros severus', 'Green Severum', 20.0, 250, 1, 23.0, 29.0, 6.0, 7.5, 4.0, 15.0,
  'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE,
  'A deep-bodied Amazonian. Eats soft plants and rearranges everything else.'),
 ('Astronotus ocellatus', 'Oscar', 35.0, 400, 1, 22.0, 28.0, 6.0, 7.5, 5.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', FALSE,
  'Reaches 35 cm and eats anything it can fit in its mouth. Buy the tank before you buy the fish.'),

 -- Central America ------------------------------------------------------
 ('Amphilophus labiatus', 'Red Devil', 25.0, 400, 1, 21.0, 28.0, 6.5, 7.5, 6.0, 25.0,
  'AGGRESSIVE', 'ADVANCED', 'OMNIVORE', FALSE,
  'The name is not decorative. A single specimen, in its own tank, with nothing it can destroy.'),
 ('Trichromis salvini', 'Salvini', 22.0, 250, 1, 22.0, 28.0, 6.5, 8.0, 5.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', TRUE,
  'Yellow and black with a red belly in condition. Pairs are devoted to each other and hostile to everything else.');

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category WHERE slug = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name),
       'species/' || v.slug || '.jpg'
  FROM (VALUES
    ('FSH-MAL-07', 'electric-blue-hap', 'Electric Blue Ahli',
     'Tank-bred. The blue is the male; females are silver and just as good to keep.',
     120000, 'malawi', 'Sciaenochromis fryeri'),
    ('FSH-MAL-08', 'johannii', 'Blue Johanni',
     'Tank-bred. Males black and electric blue, females solid orange.',
     65000, 'malawi', 'Melanochromis johannii'),
    ('FSH-MAL-09', 'nkhomo-benga-peacock', 'Nkhomo Benga Peacock',
     'Tank-bred. A sand-sifting peacock -- keep it with other peacocks, not with mbuna.',
     110000, 'malawi', 'Aulonocara baenschi'),
    ('FSH-SAM-01', 'green-severum', 'Green Severum',
     'Tank-bred. Amazonian, soft water, and it will eat your plants.',
     90000, 'cichlids-south-american', 'Heros severus'),
    ('FSH-SAM-02', 'oscar', 'Oscar',
     'Tank-bred. Sold at 6 cm, reaches 35 cm. Please read the care profile first.',
     75000, 'cichlids-south-american', 'Astronotus ocellatus'),
    ('FSH-CAM-01', 'red-devil', 'Red Devil',
     'Tank-bred. A one-fish tank, and an experienced keeper.',
     140000, 'cichlids-central-american', 'Amphilophus labiatus'),
    ('FSH-CAM-02', 'salvini', 'Salvini',
     'Tank-bred. The best-looking Central American we stock, and among the least tolerant.',
     130000, 'cichlids-central-american', 'Trichromis salvini')
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);

-- The three that were already in the catalogue and now have a photograph.
-- (V5 set keys for all six Malawi fish; three of those files exist, three do
-- not and render as placeholders until somebody photographs them.)
UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN ('demasoni', 'yellow-lab', 'auratus');

-- Sections keep their keys pointing at photographs nobody has taken yet, which
-- is honest: they render as placeholders rather than as a broken page.
