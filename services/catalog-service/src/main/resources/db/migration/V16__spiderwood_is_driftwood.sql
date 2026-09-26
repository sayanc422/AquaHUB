-- Spiderwood is a driftwood, and "driftwood" is the word a customer types.
--
-- Search matches a product's name and summary (see ProductSearch), and V2's
-- summary said "hardscape wood", so a search for driftwood -- the most common
-- name for the whole product type -- found nothing in a shop that sells it.
-- The summary is corrected rather than a synonym list added to search: it is
-- also the line on the product page, and it should have said this there too.
UPDATE product
   SET summary = 'Branching driftwood for hardscape, 25-35 cm, pre-soaked.'
 WHERE slug = 'spiderwood-medium';
