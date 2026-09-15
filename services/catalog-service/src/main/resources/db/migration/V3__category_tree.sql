-- The catalogue becomes a tree.
--
-- Until now `category` was a flat list of six, because six was all the shop
-- sold. A real fish shop is not flat: a customer looking for a Demasoni is
-- looking for Live Fishes > Freshwater > Cichlids > African > Lake Malawi, and
-- every one of those levels is a page somebody browses.
--
-- Three columns carry it:
--   parent_id   the tree itself, self-referencing
--   status      ACTIVE / COMING_SOON / HIDDEN -- a section can be announced
--               before it is stocked, which is how "Saltwater" appears on the
--               shop front greyed out instead of not appearing at all
--   image_url   because a category tile without a picture is a link, and the
--               whole point of browsing by family is that you recognise the fish

ALTER TABLE category
    ADD COLUMN parent_id BIGINT REFERENCES category(id),
    ADD COLUMN status    VARCHAR(16)  NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN image_url VARCHAR(300),
    -- A one-line trailer for the tile. `description` is the paragraph on the
    -- page; this is the sentence under the name in a grid.
    ADD COLUMN teaser    VARCHAR(200);

ALTER TABLE category
    ADD CONSTRAINT category_status_check
        CHECK (status IN ('ACTIVE', 'COMING_SOON', 'HIDDEN')),
    -- The cheapest cycle to create and the easiest to miss.
    ADD CONSTRAINT category_not_its_own_parent
        CHECK (parent_id IS DISTINCT FROM id);

CREATE INDEX idx_category_parent ON category(parent_id);
-- The nav bar reads exactly this set on every page render.
CREATE INDEX idx_category_roots ON category(sort_order) WHERE parent_id IS NULL;

ALTER TABLE product ADD COLUMN image_url VARCHAR(300);

-- ------------------------------------------------------------------ tree --
--
-- The existing six rows keep their ids, so every product's category_id stays
-- valid while the tree is built around them. Renaming and re-parenting is
-- cheaper and safer than deleting and re-inserting rows other tables point at.

UPDATE category SET name = 'Shrimp & Snails', teaser = 'Dwarf shrimp, nerites and clean-up crew.'
 WHERE slug = 'livestock-inverts';
UPDATE category SET name = 'Live Plants', teaser = 'Tissue culture and potted stems.'
 WHERE slug = 'plants';
UPDATE category SET name = 'Hardscape', teaser = 'Wood, stone and substrate.'
 WHERE slug = 'hardscape';
UPDATE category SET name = 'Equipment', teaser = 'Filters, heaters, lights, test kits.'
 WHERE slug = 'equipment';
UPDATE category SET name = 'Fish Food', teaser = 'Flake, pellet, frozen and live.'
 WHERE slug = 'food';
-- 'livestock-fish' was the only home for every fish. It becomes the tetra
-- section, and the fish that are not tetras are moved out below.
UPDATE category
   SET slug = 'tetras', name = 'Tetras & Characins',
       description = 'Shoaling fish for soft, slightly acidic water. Six is a minimum, not a target.',
       teaser = 'Neons, cardinals and their relatives.', sort_order = 30
 WHERE slug = 'livestock-fish';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status) VALUES
 ('live-fish',   'Live Fishes',
  'Every fish here is quarantined on arrival and sold with its water parameters, adult size and minimum group on the label.',
  'Freshwater now. Marine next year.', 10, NULL, 'ACTIVE'),
 ('supplies',    'Aquarium Supplies',
  'Filtration, heating, lighting, test kits, food and hardscape.',
  'Everything that is not alive.', 30, NULL, 'ACTIVE');

-- Level 2 -----------------------------------------------------------------
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'freshwater', 'Freshwater',
       'Sorted by family, the way the tanks are arranged in the shop.',
       'Cichlids, catfish, tetras and more.', 10, id, 'ACTIVE'
  FROM category WHERE slug = 'live-fish';

-- Announced, not stocked. The shop front greys it out and says so, which is
-- more honest than a section that silently does not exist.
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'saltwater', 'Saltwater',
       'Marine livestock is not stocked yet. We are building the quarantine system for it.',
       'Marine livestock and corals.', 20, id, 'COMING_SOON'
  FROM category WHERE slug = 'live-fish';

-- Level 3: freshwater families --------------------------------------------
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('cichlids', 'Cichlids',
     'Sorted by where they come from, because that is what decides the water they need and who they can live with.',
     'African, American and dwarf cichlids.', 10),
    ('catfish', 'Catfish & Loaches',
     'Bottom-dwellers. Most want a group and a soft substrate to feed on.',
     'Corydoras, plecos and loaches.', 20),
    ('barbs', 'Barbs & Rasboras',
     'Busy, hardy shoalers for a planted community tank.',
     'Harlequins, cherry barbs, danios.', 40),
    ('livebearers', 'Livebearers',
     'Hard, alkaline water. Do not mix them with blackwater fish -- the pH ranges do not meet.',
     'Guppies, platies, mollies.', 50),
    ('anabantoids', 'Bettas & Gouramis',
     'Labyrinth fish, which breathe air from the surface. One male betta per tank, always.',
     'Bettas, honey and pearl gouramis.', 60)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'freshwater';

-- The tetra section already exists (it was 'livestock-fish'); re-parent it,
-- and move the inverts under freshwater too.
UPDATE category SET parent_id = (SELECT id FROM category WHERE slug = 'freshwater')
 WHERE slug IN ('tetras', 'livestock-inverts');
UPDATE category SET sort_order = 70 WHERE slug = 'livestock-inverts';

-- Level 4: cichlids by origin ---------------------------------------------
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('cichlids-african', 'African Cichlids',
     'Rift-lake fish for hard, alkaline water -- pH 7.8 and up. They cannot share a tank with soft-water species.',
     'Malawi, Tanganyika, Victoria, West Africa.', 10),
    ('cichlids-south-american', 'South American Cichlids',
     'Soft, acidic water. Angelfish, discus, severums and eartheaters.',
     'Angels, discus, eartheaters.', 20),
    ('cichlids-central-american', 'Central American Cichlids',
     'Large, boisterous and territorial. Tank size is the first question, not the last.',
     'Convicts, firemouths, Jack Dempseys.', 30),
    ('cichlids-dwarf', 'Dwarf Cichlids',
     'Under 8 cm and suitable for a planted community tank, given a cave each.',
     'Apistogramma, rams, kribensis.', 40)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'cichlids';

-- Level 4: catfish groups --------------------------------------------------
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('catfish-corydoras', 'Corydoras',
     'Shoaling, peaceful, and they need sand rather than gravel to feed properly.',
     'Panda, bronze, sterbai.', 10),
    ('catfish-pleco', 'Plecos & Otocinclus',
     'Algae grazers. Check the adult size before you buy -- some reach 45 cm.',
     'Bristlenose, otocinclus.', 20),
    ('catfish-loach', 'Loaches',
     'Burrowers and social diggers. Sand, caves and company.',
     'Kuhli and hillstream loaches.', 30)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'catfish';

-- Level 5: the African lakes ----------------------------------------------
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, v.status
  FROM category c, (VALUES
    ('malawi', 'Lake Malawi',
     'Mbuna and haps. Keep them crowded, feed vegetable matter rather than protein, and keep the pH above 7.8.',
     'Mbuna and haplochromines.', 10, 'ACTIVE'),
    ('tanganyika', 'Lake Tanganyika',
     'Harder and more alkaline again, and far more varied in behaviour -- shell dwellers, rock specialists, open-water shoalers.',
     'Shell dwellers and rock specialists.', 20, 'COMING_SOON'),
    ('victoria', 'Lake Victoria',
     'Haplochromines, most of them threatened in the wild and maintained by hobbyists.',
     'Haplochromines.', 30, 'COMING_SOON'),
    ('west-african', 'West African Riverine',
     'River fish rather than rift-lake -- softer water, and a very different tank from the rest of this section.',
     'Kribensis and jewel cichlids.', 40, 'COMING_SOON')
  ) AS v(slug, name, description, teaser, sort_order, status)
 WHERE c.slug = 'cichlids-african';

-- Supplies -----------------------------------------------------------------
UPDATE category SET parent_id = (SELECT id FROM category WHERE slug = 'supplies')
 WHERE slug IN ('hardscape', 'equipment', 'food');
UPDATE category SET parent_id = NULL, sort_order = 20 WHERE slug = 'plants';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, 'ACTIVE'
  FROM category c, (VALUES
    ('plants-foreground', 'Foreground & Carpet',
     'Low growers for the front of the tank. Most want strong light and CO2.',
     'Monte carlo, dwarf hairgrass.', 10),
    ('plants-stem', 'Stem Plants',
     'Fast growers for the back. Trim them and replant the tops.',
     'Rotala, ludwigia, hygrophila.', 20),
    ('plants-epiphyte', 'Anubias, Ferns & Mosses',
     'Tied to wood or stone, never planted in the substrate. The easiest plants in the shop.',
     'Anubias, java fern, bucephalandra.', 30)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'plants';
