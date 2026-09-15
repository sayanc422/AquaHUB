-- Move the existing products into the leaves of the new tree, and stock Lake
-- Malawi so the deepest path in the catalogue ends in fish rather than in an
-- empty page.
--
-- Products are moved by SKU rather than by category, because the old
-- 'livestock-fish' category held ten fish that now belong in five different
-- families. A bulk re-parent would have put the plecos with the tetras.

UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'catfish-corydoras')
 WHERE sku = 'FSH-COR-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'catfish-pleco')
 WHERE sku IN ('FSH-BNP-01', 'FSH-OTO-01');
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'catfish-loach')
 WHERE sku = 'FSH-KUH-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'barbs')
 WHERE sku IN ('FSH-HAR-01', 'FSH-ZEB-01');
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'livebearers')
 WHERE sku = 'FSH-GUP-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'anabantoids')
 WHERE sku = 'FSH-BET-01';
-- The tetras stay where they are: that category *is* the old livestock-fish.

UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'plants-epiphyte')
 WHERE sku IN ('PLT-ANU-01', 'PLT-CRY-01');
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'plants-stem')
 WHERE sku = 'PLT-VAL-01';

-- ---------------------------------------------------------- Lake Malawi --
--
-- Real care parameters. Note what they do to the rest of the shop: mbuna want
-- pH 7.8-8.6 and a neon tetra wants 5.5-7.5, so those ranges do not meet at
-- any point. aquatics-advisor refuses that tank on its own data, without
-- anybody writing a rule about mbuna.

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, care_notes) VALUES
 ('Pseudotropheus saulosi', 'Saulosi', 9.0, 200, 6, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'HERBIVORE', FALSE,
  'Males blue and barred, females and juveniles solid yellow. One male to several females.'),
 ('Chindongo demasoni', 'Demasoni', 7.0, 150, 12, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'AGGRESSIVE', 'ADVANCED', 'HERBIVORE', FALSE,
  'Relentlessly aggressive to its own kind. Keep twelve or more so no single fish is targeted, or keep one.'),
 ('Labidochromis caeruleus', 'Yellow Lab', 10.0, 200, 5, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'SEMI_AGGRESSIVE', 'BEGINNER', 'OMNIVORE', FALSE,
  'The mildest common mbuna and the usual first rift-lake fish.'),
 ('Maylandia estherae', 'Red Zebra', 12.0, 250, 5, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'AGGRESSIVE', 'INTERMEDIATE', 'HERBIVORE', FALSE,
  'Orange in both sexes despite the name. Males hold territory and will chase.'),
 ('Pseudotropheus acei', 'Acei Yellow Tail', 15.0, 250, 5, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'SEMI_AGGRESSIVE', 'BEGINNER', 'HERBIVORE', FALSE,
  'Open-water mbuna that grazes wood rather than rock. Calmer than most of the group.'),
 ('Melanochromis auratus', 'Auratus', 11.0, 200, 5, 24.0, 28.0, 7.8, 8.6, 10.0, 20.0,
  'AGGRESSIVE', 'ADVANCED', 'OMNIVORE', FALSE,
  'Females gold with black stripes, males reverse to dark brown. Among the most aggressive mbuna sold.');

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category WHERE slug = 'malawi'),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name)
  FROM (VALUES
    ('FSH-MAL-01', 'saulosi', 'Saulosi',
     'Tank-bred. Males blue with dark bars, females solid yellow.', 65000, 'Pseudotropheus saulosi'),
    ('FSH-MAL-02', 'demasoni', 'Demasoni',
     'Tank-bred. Sold in groups of twelve only -- fewer and they kill each other.', 85000, 'Chindongo demasoni'),
    ('FSH-MAL-03', 'yellow-lab', 'Yellow Lab',
     'Tank-bred. The gentlest mbuna we stock and the usual place to start.', 55000, 'Labidochromis caeruleus'),
    ('FSH-MAL-04', 'red-zebra', 'Red Zebra',
     'Tank-bred. Orange throughout, regardless of sex.', 60000, 'Maylandia estherae'),
    ('FSH-MAL-05', 'acei-yellow-tail', 'Acei Yellow Tail',
     'Tank-bred. Purple-blue body with yellow fins; grazes wood rather than rock.', 70000, 'Pseudotropheus acei'),
    ('FSH-MAL-06', 'auratus', 'Auratus',
     'Tank-bred. Handsome and genuinely difficult -- a species tank fish.', 50000, 'Melanochromis auratus')
  ) AS v(sku, slug, name, summary, price_minor, scientific_name);
