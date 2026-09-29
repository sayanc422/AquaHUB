-- Photographs for V23's bettas and gouramis and V24's shrimp and snails:
-- 24 of their 33 products, and the six sections they added. Development plan
-- item 3.
--
-- Same bar as V18: Commons only, CC0 / PD / CC-BY / CC-BY-SA read off the
-- API's extmetadata, Restrictions empty, and every file looked at against its
-- caption. The morph matters as much as the species here -- a crowntail is a
-- different purchase from a plakat, a snowball shrimp from a red cherry -- so a
-- photo of the right species in the wrong form was rejected, not used.
-- Source, licence, artist, crop and a per-file caveat are in
-- services/storefront/public/species/CREDITS.md and sections/CREDITS.md.
--
-- NINE PRODUCTS STAY NULL, on purpose -- a key is a promise the file exists
-- (V5 -> V7): betta-male-crowntail, emerald-betta, thick-lipped-gourami,
-- bloody-mary-shrimp, black-rose-shrimp, green-jade-shrimp, chocolate-shrimp,
-- snowball-shrimp, blue-mystery-snail. CREDITS.md says why for each.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN (SELECT s FROM (VALUES
    -- bettas
    ('betta-male-plakat'),
    ('betta-male-double-tail'),
    ('betta-male-veiltail'),
    ('betta-female'),
    -- wild bettas
    ('peaceful-betta'),
    ('mahachai-betta'),
    ('whiteseam-betta'),
    ('snakehead-betta'),
    ('wine-red-betta'),
    -- gouramis
    ('banded-gourami'),
    ('moonlight-gourami'),
    ('snakeskin-gourami'),
    ('croaking-gourami'),
    ('giant-gourami'),
    -- shrimp
    ('orange-sakura-shrimp'),
    ('red-rili-shrimp'),
    ('crystal-red-shrimp'),
    ('crystal-black-shrimp'),
    ('blue-bolt-shrimp'),
    ('orange-eyed-blue-tiger-shrimp'),
    ('bamboo-shrimp'),
    ('vampire-shrimp'),
    ('indian-whisker-shrimp'),
    -- snails
    ('horned-nerite-snail')
 ) AS v(s));

UPDATE category SET image_key = 'sections/' || slug || '.jpg'
 WHERE slug IN ('bettas', 'bettas-wild', 'gouramis',
                'shrimp-neocaridina', 'shrimp-caridina', 'shrimp-other');
