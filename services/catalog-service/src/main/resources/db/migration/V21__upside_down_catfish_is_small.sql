-- V17 filed the upside-down catfish (Synodontis nigriventris, 10 cm, 100 L)
-- under catfish-synodontis because of its genus -- but that section sits
-- under catfish-large, and this is the one small Synodontis. A customer with a
-- 100 L tank browsing Small Catfish would never see it, and one browsing Large
-- would buy a fish for the wrong tank. CatalogApiTest's
-- everyFishOnTheSmallCatfishPageFitsASmallTank caught it on its first run
-- after V17 ("catfish filed as large that are not").
--
-- Filed where V17 filed the glass catfish, its only small-catfish peer that
-- fits no genus section: directly on catfish-small.

UPDATE product
   SET category_id = (SELECT id FROM category WHERE slug = 'catfish-small')
 WHERE sku = 'FSH-CAT-03';
