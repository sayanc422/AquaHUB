-- green-jade-shrimp gets a photograph (1 October 2026), at the owner's direction.
--
-- No licensed photograph anywhere searched (Commons, Openverse/Flickr,
-- iNaturalist, Pexels) is captioned "green jade". The two iNaturalist
-- observations whose descriptions do say green jade show small, dark brown
-- shrimp in which no green is visible. The owner chose to accept a colour
-- match by eye for the clearest case only: a translucent green Neocaridina
-- davidi (iNaturalist photo 339456346, Daniel Schelesky, CC BY). It is the
-- right species and the right colour, but nobody named the line, so CREDITS
-- marks it not launch-eligible.
--
-- The other three lines stay NULL. Black and brown could equally be blue
-- dream or choco black, and the only deep-red candidate for bloody mary was
-- a wild-caught shrimp lying on its side on a dry rock, the same failure the
-- owner rejected for the snakeskin gourami in V26.

UPDATE product SET image_key = 'species/' || slug || '.jpg' WHERE slug = 'green-jade-shrimp';
