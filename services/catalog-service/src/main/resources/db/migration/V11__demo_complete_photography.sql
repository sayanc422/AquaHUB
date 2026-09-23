-- The last 11 products get an image_key. Every product in the catalogue now
-- carries a photograph: 55 of 55.
--
-- These 11 are NOT launch-eligible the way V9's 32 and V10's 2 are, and the
-- distinction is the whole point of this file existing separately. V9 and V10
-- wired in photographs that cleared a bar: correctly licensed, correctly
-- identified to species or subject, and at or above the 1200x900 floor that
-- services/storefront/public/species/README.md sets. These 11 cleared the
-- licence half of that bar and nothing else. They are demo-complete, not
-- commercial-ready.
--
-- The instruction behind the change was explicit: fill the remaining gaps,
-- dismiss the resolution and structural constraints, make the site look
-- finished. That is a defensible trade here and only here -- this platform is
-- designed for AWS, validated with mock providers, run on k3d, and never
-- applied to an AWS account. Nothing is ever sold from it. The day that stops
-- being true, these 11 keys have to come back out or be replaced with shop
-- photography, because what was relaxed to get them in does not survive
-- contact with a real storefront:
--
--   * Resolution. Five are below the floor at source and were enlarged with
--     Lanczos -- saulosi 2.3x from 556x392, red-melon-badis 1.92x from
--     701x468, yellow-shrimp 1.53x, the three food shots 1.4x from 1000x1000,
--     seiryu-stone-5kg 1.09x. An upscale invents no detail; it just hides the
--     shortfall behind interpolation.
--   * Identification. bristlenose-pleco and otocinclus are Ancistrus sp. and
--     Otocinclus sp. -- genus only. Both products are sold under a species
--     name the photograph does not carry.
--   * Product form. frozen-bloodworm-100g shows freeze-dried worms, not a
--     frozen blister pack. algae-wafers-250g shows tablets, not wafers.
--     seiryu-stone-5kg shows unidentified aquascaping rock already built into
--     someone's layout, not Seiryu stone as a sellable object.
--     master-test-kit shows a teaching-lab test-tube rack and is not an
--     aquarium test kit at all.
--   * Trademark. canister-filter-400lph carries a legible FLUVAL 204 mark on
--     a real Hagen product this shop does not sell, and it is the wrong flow
--     rate besides. V10 refused exactly this and the reasoning it gave is
--     still correct: a CC licence covers copyright and explicitly disclaims
--     trademark, so a verified licence is not clearance. It is published now
--     only because there is no commercial launch to clear it for. This is the
--     single row here that would be a legal problem rather than a quality
--     problem if this catalogue ever went live.
--
-- What was not relaxed is the licence itself. Every file was queried through
-- the Commons API, extmetadata.LicenseShortName read off the actual response,
-- Restrictions confirmed empty and the artist taken from extmetadata.Artist.
-- CC BY-SA 2.5/3.0/4.0 and CC BY 4.0 only; nothing "NC", nothing "ND",
-- nothing from a general image search. Source, licence and a per-file caveat
-- are recorded in services/storefront/public/species/CREDITS.md, section
-- "Deliberate quality relaxation on the remaining gaps, 22 September 2026".
--
-- All 11 JPEGs are committed alongside this migration, which is what
-- README.md asks for -- a key is a promise that the file exists, and V7 had
-- to clear two keys once already because that promise was not kept. saulosi
-- is one of those two; the file exists this time.
UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN (
   -- Malawi cichlid
   'saulosi',
   -- catfish / plecos (both genus-level IDs)
   'bristlenose-pleco', 'otocinclus',
   -- badis
   'red-melon-badis',
   -- invertebrates
   'yellow-shrimp',
   -- hardscape
   'seiryu-stone-5kg',
   -- equipment (canister filter carries a third-party trademark)
   'canister-filter-400lph', 'master-test-kit',
   -- food
   'community-flake-100g', 'algae-wafers-250g', 'frozen-bloodworm-100g'
 );
