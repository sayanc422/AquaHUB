-- Takes back one of V27's four photographs, the same day.
--
-- V27 keyed green-myrio to a photo of Myriophyllum mattogrossense. The
-- product's plant profile (V22) is Myriophyllum pinnatum, a North American
-- species; mattogrossense is the South American "green myrio" of the trade.
-- Right look, wrong species, which is the wrong product. It was caught on the
-- product page, where the scientific name sits under the photo.
--
-- The four licensed iNaturalist observations of M. pinnatum are all emersed
-- flowering spikes, not the submerged stems the product is. So the key goes
-- back to NULL and the file is deleted in the same change: a key is a promise
-- that the file exists (V5 -> V7). V27 is already applied on the k3d
-- cluster, so it is corrected here rather than edited.

UPDATE product SET image_key = NULL WHERE slug = 'green-myrio';
