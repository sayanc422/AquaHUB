-- Every category tile gets a photograph. This is the first time any of them
-- has had one.
--
-- V5 set seven `sections/<slug>.jpg` keys against files nobody had taken, and
-- one of the seven ('live-plants') was not even a slug that exists. V7 cleared
-- the lot with the right reasoning -- "a key is a promise that the file
-- exists" -- and since then `category.image_key` has been NULL on every row,
-- root and leaf alike, so the shop front has rendered the designed placeholder
-- on all of them. The promise is kept this time: forty JPEGs are committed in
-- the same change, one per slug named below, all 1600x900 or larger,
-- EXIF-stripped, progressive, under 300 KB.
--
-- A count worth writing down because it was wrong in the brief that asked for
-- this: the tree holds 38 categories before V12, not 37, and V12 adds two more
-- (catfish-predatory, arowana). Forty rows, forty files, and the enumeration
-- below is the list rather than a blanket UPDATE so that a row added later does
-- not silently acquire a key to a file that does not exist.
--
-- WHY THE BAR IS DIFFERENT HERE, and it is worth being explicit because
-- services/storefront/public/species/CREDITS.md spends three sections on how
-- strict product photography has to be:
--
--   * Licensing is exactly as strict. Every file was queried through the
--     Commons API, extmetadata.LicenseShortName read off the actual response,
--     Restrictions confirmed empty, and the artist taken from
--     extmetadata.Artist and never from a filename. CC0 / public domain /
--     CC-BY / CC-BY-SA only, nothing "NC", nothing "ND", nothing from a general
--     image search. One otherwise-good candidate (File:Filtermaterial
--     060227.jpg, aquarium filter media, correctly licensed CC BY-SA 3.0 and
--     2485x1589) was rejected outright because its extmetadata.Artist is empty
--     and Commons files it under "Files with no machine-readable author" -- a
--     share-alike licence that names no author cannot be attributed, and
--     guessing the author from the description text is not the protocol.
--
--   * Subject precision is deliberately looser, and that is not a relaxation
--     of the bar -- it is a different bar. A product photograph has to show the
--     species on the label. A category tile is thematic: "Cichlids" wants a
--     good photograph of a cichlid, not a photograph of any particular
--     product. So `cichlids.jpg` is a tankful of assorted Malawi haps and
--     peacocks and is not claiming to be anything more specific.
--
-- Three tiles carry a caveat that is recorded per row in
-- services/storefront/public/sections/CREDITS.md rather than only here:
-- `victoria.jpg` is an unidentified haplochromine (Commons has no confirmed
-- Lake Victoria cichlid above the size floor at all), `badidae.jpg` is Dario
-- huli rather than the Dario dario the shop sells (the only Badidae file on
-- Commons over 1600x900), and `plants-foreground.jpg` is dwarf hairgrass
-- photographed growing emersed on a riverbank rather than as an aquarium
-- carpet. All three are honest about what they show and none of them is
-- pretending to be a specimen.
--
-- The six COMING_SOON sections get a real photograph too. The tile renders
-- whether or not the link goes anywhere, and a greyed-out tile with a
-- placeholder in it looks like a bug rather than like a section that is
-- announced and not yet stocked.

UPDATE category SET image_key = 'sections/' || slug || '.jpg'
 WHERE slug IN (
   -- roots
   'live-fish', 'invertebrates', 'plants', 'supplies',
   -- live fish, level 2
   'freshwater', 'saltwater',
   -- freshwater families
   'tetras', 'cichlids', 'catfish', 'barbs', 'livebearers', 'anabantoids',
   'loaches', 'badidae', 'arowana',
   -- cichlids by origin
   'cichlids-african', 'cichlids-american', 'cichlids-dwarf',
   'malawi', 'tanganyika', 'victoria', 'african-other',
   'cichlids-south-american', 'cichlids-central-american',
   -- catfish by adult size
   'catfish-small', 'catfish-large',
   'catfish-corydoras', 'catfish-oto', 'catfish-bristlenose',
   'catfish-pleco-large', 'catfish-synodontis', 'catfish-predatory',
   -- invertebrates
   'inverts-shrimp', 'inverts-snails',
   -- plants
   'plants-foreground', 'plants-stem', 'plants-epiphyte',
   -- supplies
   'hardscape', 'equipment', 'food'
 );
