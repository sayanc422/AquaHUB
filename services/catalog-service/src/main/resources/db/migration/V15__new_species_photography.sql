-- The fourteen products V13 added get their photographs.
--
-- Sourced and verified exactly the way V9's 32 and V10's 2 were, and
-- deliberately NOT the way V11's 11 were: the Commons API was queried for every
-- candidate, extmetadata.LicenseShortName read off the actual response,
-- Restrictions confirmed empty, artist taken from extmetadata.Artist rather
-- than from a filename, and every surviving candidate downloaded and looked at
-- before it was accepted. CC0 / public domain / CC-BY / CC-BY-SA only. Source,
-- licence, artist and a per-file caveat are in
-- services/storefront/public/species/CREDITS.md.
--
-- V11 relaxed resolution, species precision, product form and trademark on
-- eleven files to make the site look finished, and said so. That relaxation is
-- NOT inherited here. Thirteen of these fourteen clear the original bar --
-- correct species, at or above the 1200x900 floor before cropping, no
-- third-party trademark in frame, lateral or near-lateral framing. The
-- exceptions are named, because "never soften a limitation" applies to a
-- migration comment as much as to a care note:
--
--   * THE FOUR ASIAN AROWANA MORPHS. Super Red, Golden Crossback, Red Tail
--     Golden and Green are four farm lines of one species, and Commons does not
--     index photographs by trade morph. Two of the four are matched by a
--     source whose own caption names the morph -- 'Honglongyu' is the Chinese
--     trade name for the red line, and 'Qua boi' is the Vietnamese for
--     cross-back -- and the Green morph's source caption says "Green Arowana"
--     outright. The fourth, Red Tail Golden, is a correctly identified
--     Scleropages formosus whose morph is NOT confirmed by any caption; the
--     assignment is ours, by eye, and CREDITS.md says so in those words. Every
--     one of the four is genuinely S. formosus. What is approximate is which
--     farm line, and on a fish where the line is most of the price, that is a
--     real caveat rather than a formality.
--
--   * flowerhorn.jpg has a busy background -- the fish is photographed in a
--     display tank in front of hanging paper lanterns. No trademark and no
--     person in frame, and it is the clearest shot on Commons of the pearled,
--     humped trade form rather than a washed-out albino. Recorded, not hidden.
--
--   * tiger-shovelnose-catfish.jpg has the caudal fin clipped at the left edge
--     in the source frame. It is the best lateral profile Commons holds for the
--     species; the alternatives are a three-quarter head-on shot and two dark
--     tank corners.
--
-- All fourteen JPEGs are committed alongside this migration. V7 had to clear
-- three keys once because that was not done, and V10 and V11 both had to say so
-- again; a key is a promise that the file exists.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN (
   -- predatory catfish
   'redtail-catfish', 'tiger-shovelnose-catfish', 'iridescent-shark',
   -- Lake Malawi
   'dolphin-cichlid',
   -- South American cichlid
   'green-terror',
   -- Central American cichlids (flowerhorn is the hybrid line, not a species)
   'texas-cichlid', 'flowerhorn', 'redhead-cichlid',
   -- arowana
   'silver-arowana', 'jardini-arowana',
   -- Asian arowana: four trade morphs, one species, four separate photographs
   'asian-arowana-super-red', 'asian-arowana-golden-crossback',
   'asian-arowana-red-tail-golden', 'asian-arowana-green'
 );
