-- Images: store a key, not a URL.
--
-- V3 added `image_url` to both tables and left it empty. Filling it with URLs
-- would be a mistake worth avoiding before there is any data in it: a URL
-- hard-codes where the bytes live, so the day the shop moves its photographs
-- behind a CDN, every row has to be rewritten. A key does not -- the storefront
-- composes `IMAGE_BASE_URL + key`, and moving from `/static` to CloudFront is a
-- ConfigMap change with no migration at all.
--
-- catalog-service owns *which* photograph belongs to a product. It has no
-- business owning *where it is served from*.

ALTER TABLE category RENAME COLUMN image_url TO image_key;
ALTER TABLE product  RENAME COLUMN image_url TO image_key;

-- The convention: species/<product slug>.jpg, sections/<category slug>.jpg.
-- Predictable enough that a shop assistant who photographs a new fish knows
-- what to call the file without asking anybody.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN ('saulosi', 'demasoni', 'yellow-lab', 'red-zebra',
                'acei-yellow-tail', 'auratus');

UPDATE category SET image_key = 'sections/' || slug || '.jpg'
 WHERE slug IN ('live-fish', 'live-plants', 'supplies', 'freshwater',
                'cichlids', 'cichlids-african', 'malawi');

-- Nothing else has a photograph yet, and a key pointing at a file that does not
-- exist is worse than a null: the storefront renders a placeholder for null and
-- a broken image for a bad key.
