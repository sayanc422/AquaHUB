-- Development plan item 4, the crop audit (30 September 2026).
--
-- Four products gain a photograph, all from iNaturalist under CC BY or CC0,
-- each re-queried by photo id for licence, attribution and identification:
--   endlers-livebearer -- a male in profile. iNaturalist's community ID is
--                         Poecilia reticulata x wingei, the hybrid much of
--                         the trade sells as "Endler's"; not pure P. wingei.
--   dwarf-baby-tears   -- a wild Micranthemum (Hemianthus) callitrichoides
--                         carpet in Cuba, one identification only.
--   green-myrio        -- Myriophyllum mattogrossense in a display aquarium.
--   ludwigia-peruensis -- Ludwigia glandulosa, the plant sold as 'peruensis',
--                         growing wild in Texas, one identification only.
-- Caveats per file are in the storefront's species/CREDITS.md.
--
-- The audit also re-framed 19 photographs that were cutting fish off, and
-- replaced tiger-shovelnose-catfish.jpg. Those are file changes under the
-- same key, so they need nothing here.

UPDATE product SET image_key = 'species/' || slug || '.jpg'
 WHERE slug IN ('endlers-livebearer', 'dwarf-baby-tears', 'green-myrio', 'ludwigia-peruensis');
