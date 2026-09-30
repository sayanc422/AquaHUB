-- The owner's review of V25's photographs (30 September 2026).
--
-- Two gaps filled from Flickr and Commons under CC BY / CC BY-SA:
--   betta-male-crowntail -- a red male crowntail, Betta-Online on Flickr.
--   snowball-shrimp      -- a white Neocaridina ("white pearl"), upscaled, so
--                           not launch-eligible; see CREDITS.md.
-- Three files were replaced without a key change (veiltail, vampire shrimp,
-- whisker shrimp): same slug, same key, new photograph.
--
-- snakeskin-gourami goes back to NULL. Its only photograph was a caught fish
-- lying on a tiled floor, and the owner judged that worse than the
-- placeholder. The file is deleted in the same change; a key is a promise
-- the file exists (V5 -> V7).

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN ('betta-male-crowntail', 'snowball-shrimp');

UPDATE product SET image_key = NULL WHERE slug = 'snakeskin-gourami';
