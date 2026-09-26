-- Photographs for V17's India-popular range: 95 of its 102 products, and the
-- four sections it added.
--
-- Same bar as V15, not V11's relaxed one: Commons only, CC0 / PD / CC-BY /
-- CC-BY-SA read off the API's extmetadata, Restrictions empty, artist from
-- extmetadata.Artist, source >= 1200x900 before the 4:3 crop, and every file
-- looked at. Source, licence, artist and a per-file caveat for each are in
-- services/storefront/public/species/CREDITS.md and sections/CREDITS.md.
--
-- SEVEN PRODUCTS STAY NULL, on purpose -- a key is a promise the file exists
-- (V5 -> V7): head-and-tail-light-tetra, bumblebee-cichlid, skunk-cory,
-- snowball-pleco, scissortail-rasbora, endlers-livebearer, tire-track-eel.
-- CREDITS.md says why for each.
--
-- The product slug is the file name for every one of these, so the key is
-- derived rather than listed twice; the list below is the set that HAS a file.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN (SELECT s FROM (VALUES
    ('african-butterflyfish'),
    ('angelfish'),
    ('apistogramma-agassizii'),
    ('bala-shark'),
    ('black-ghost-knifefish'),
    ('black-moor-goldfish'),
    ('black-neon-tetra'),
    ('black-phantom-tetra'),
    ('black-ruby-barb'),
    ('black-skirt-tetra'),
    ('bleeding-heart-tetra'),
    ('blood-parrot'),
    ('blue-acara'),
    ('boesemani-rainbow'),
    ('brichardi'),
    ('buenos-aires-tetra'),
    ('celestial-pearl-danio'),
    ('cherry-barb'),
    ('chinese-algae-eater'),
    ('chocolate-gourami'),
    ('clown-loach'),
    ('cobalt-blue-zebra'),
    ('cockatoo-cichlid'),
    ('comet-goldfish'),
    ('congo-tetra'),
    ('convict-cichlid'),
    ('denison-barb'),
    ('diamond-tetra'),
    ('discus'),
    ('dwarf-chain-loach'),
    ('dwarf-gourami'),
    ('ember-tetra'),
    ('emerald-green-cory'),
    ('emperor-tetra'),
    ('false-julii-cory'),
    ('fire-eel'),
    ('firemouth-cichlid'),
    ('frontosa'),
    ('german-blue-ram'),
    ('giant-danio'),
    ('glass-catfish'),
    ('glowlight-danio'),
    ('glowlight-tetra'),
    ('gold-nugget-pleco'),
    ('hillstream-loach'),
    ('honey-gourami'),
    ('jack-dempsey'),
    ('jaguar-cichlid'),
    ('kenyi-cichlid'),
    ('kissing-gourami'),
    ('kribensis'),
    ('lambchop-rasbora'),
    ('lemon-cichlid'),
    ('molly-assorted'),
    ('ocellatus'),
    ('odessa-barb'),
    ('oranda-goldfish'),
    ('ornate-bichir'),
    ('paradise-fish'),
    ('pea-puffer'),
    ('pearl-danio'),
    ('pearl-gourami'),
    ('pearlscale-goldfish'),
    ('penguin-tetra'),
    ('peppered-cory'),
    ('pictus-catfish'),
    ('platy-assorted'),
    ('praecox-rainbow'),
    ('rainbow-shark'),
    ('ranchu-goldfish'),
    ('red-eye-tetra'),
    ('red-irian-rainbow'),
    ('red-tail-shark'),
    ('rosy-barb'),
    ('royal-pleco'),
    ('rummynose-tetra'),
    ('ryukin-goldfish'),
    ('serpae-tetra'),
    ('siamese-algae-eater'),
    ('silver-dollar'),
    ('silver-hatchetfish'),
    ('sparkling-gourami'),
    ('striped-raphael-catfish'),
    ('swordtail-assorted'),
    ('threadfin-rainbow'),
    ('three-spot-gourami'),
    ('tiger-barb'),
    ('tinfoil-barb'),
    ('upside-down-catfish'),
    ('venustus'),
    ('white-cloud-minnow'),
    ('x-ray-tetra'),
    ('yellowfin-borleyi'),
    ('yoyo-loach'),
    ('zebra-loach')
 ) AS v(s));

UPDATE category SET image_key = 'sections/' || slug || '.jpg'
 WHERE slug IN ('goldfish', 'sharks-algae-eaters', 'rainbowfish', 'oddballs');
