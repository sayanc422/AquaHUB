-- Photographs sourced under a licence that permits commercial use, not shop
-- photography. See services/storefront/public/species/CREDITS.md for the
-- source, licence and attribution recorded against every file below --
-- services/storefront/public/species/README.md requires that before any
-- image lands here, and this is the first batch to arrive that way rather
-- than "supplied by shop owner, unverified".
--
-- 32 of the 45 products missing a photograph got one. The other 13 stay
-- NULL and render as the designed placeholder: Wikimedia Commons had no
-- image that was both correctly licensed (CC0/public domain/CC-BY/CC-BY-SA
-- only -- never "NC" or "ND") and correctly identified as the species/subject
-- actually sold here. Forcing a wrong-species or wrong-licence photo through
-- to close the gap would have cost more than the empty tile it replaces.
UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN (
   -- community fish
   'betta-male-halfmoon', 'cardinal-tetra', 'neon-tetra', 'guppy-male-trio',
   'harlequin-rasbora', 'zebra-danio', 'kuhli-loach',
   -- badis
   'scarlet-badis', 'blue-badis',
   -- catfish / plecos
   'panda-cory', 'bronze-cory', 'sterbai-cory', 'pygmy-cory',
   'sailfin-pleco', 'common-pleco', 'featherfin-synodontis', 'cuckoo-catfish',
   -- Malawi cichlid
   'red-zebra',
   -- invertebrates
   'amano-shrimp', 'cherry-shrimp', 'blue-dream-shrimp', 'blue-velvet-shrimp',
   'ghost-shrimp', 'nerite-snail', 'mystery-snail', 'ramshorn-snail',
   'malaysian-trumpet-snail', 'assassin-snail',
   -- plants and hardscape
   'anubias-nana-petite', 'cryptocoryne-wendtii', 'vallisneria-nana',
   'spiderwood-medium'
 );
