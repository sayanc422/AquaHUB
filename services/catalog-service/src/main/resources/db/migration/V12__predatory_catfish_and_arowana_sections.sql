-- Two sections the tree has had nowhere to put, added before the fish that go
-- in them (V13) so that no product insert has to invent its own home.
--
-- 1. catfish-predatory, under catfish-large.
--
--    `catfish-large` has held two children since V7 -- large plecos and
--    Synodontis -- and no direct products. Both of those are, whatever their
--    adult size, animals that eat algae, wood and invertebrates. The fish this
--    shop is actually asked for under "big catfish" are a different thing
--    entirely: Amazonian predators that eat other fish and reach a metre or
--    more. Filing a redtail catfish next to a bristlenose's larger cousin
--    would tell a customer the wrong thing about what they are buying, and the
--    whole point of V7's size split was that the section a customer lands on
--    should answer the question that decides whether they can keep the fish.
--
--    The rule for this leaf, written down so the next person adding a species
--    does not have to guess: a fish that takes live or meaty food, reaches
--    75 cm or more, and cannot be housed for life in any tank sold as
--    furniture. Everything on this page is a public-aquarium or pond animal
--    sold as a 10 cm juvenile.
--
-- 2. arowana, under freshwater.
--
--    There was no arowana category at all -- `freshwater` went straight from
--    badidae to livebearers. Arowana are not cichlids, not catfish and not
--    characins; Osteoglossidae is its own order-level oddity and the trade
--    treats it as its own section, because the customer for an arowana is not
--    the customer for anything else in the shop. It also has to be its own
--    page for a reason that is not taxonomic: one of the species on it is
--    CITES Appendix I, and that warning needs somewhere to live that is not
--    buried three sections deep among community fish. See V13.
--
-- Both are ACTIVE rather than COMING_SOON because V13 stocks them in the same
-- change. V7's "an ACTIVE leaf with no products is a link to an empty page"
-- sweep would otherwise be right to flip them.

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'catfish-predatory', 'Predatory Catfish',
       'Redtails, shovelnose and their relatives. Every fish on this page is sold at 8-12 cm, reaches a metre or more, and needs a tank measured in thousands of litres before it is half grown. Most of them end up rehomed, and a good number end up dead of it. Read the care profile before the price.',
       'Metre-long fish, sold at 10 cm.', 30, id, 'ACTIVE'
  FROM category WHERE slug = 'catfish-large';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT 'arowana', 'Arowana',
       'Surface-hunting bonytongues from three continents. They need length and width rather than depth -- an arowana turns at the end of the tank, and a tank it cannot turn in bends its spine permanently. All of them jump, so a weighted lid is not optional. One species here, the Asian arowana, is CITES Appendix I and cannot legally be bought or sold in many countries at all; its listings say so.',
       'Bonytongues. Length, width and a lid.', 38, id, 'ACTIVE'
  FROM category WHERE slug = 'freshwater';
