-- Photographs for V30's gobies and their section (1 October 2026).
--
-- All six from Wikimedia Commons (CC BY-SA) or iNaturalist (CC0), each re-queried
-- by title or photo id for licence, author and identification. Rows and caveats
-- are in the storefront's species/CREDITS.md and sections/CREDITS.md. The two
-- photographs the owner attached were the visual reference, not a source:
-- they came from a web search with no licence.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN ('bumblebee-goby', 'peacock-gudgeon', 'philippine-neon-goby', 'knight-goby', 'zhous-scarlet-goby');

UPDATE category SET image_key = 'sections/gobies.jpg' WHERE slug = 'gobies';
