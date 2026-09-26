-- The live plant range, and a care profile for plants.
--
-- The shop sold three plants with a one-line summary each and no care data.
-- The owner asked for liveaquaria.com's freshwater aquarium plant range
-- (57 species across its foreground/midground/background collections), with
-- a full keeping guide: light and how strong it must be, CO2, which fish
-- suit it. This adds 49 plants and profiles for the three already sold.
--
-- WHAT WAS LEFT OUT, and why, so nobody re-adds it by accident:
--   * Water hyacinth and water lettuce -- among the worst invasive weeds in
--     Indian waterways; the same rule V17 applied to mosquitofish.
--   * "Brazilian sword" (Spathiphyllum, a peace lily) and Japanese dwarf rush
--     (Acorus) -- not aquatic; both rot slowly under water. Selling them as
--     aquarium plants would be selling a dying plant.
--   * Pond, bog and lotus plants, plastic plants and liveaquaria's bundles.
--
-- A NEW TABLE, plant_profile, not more nullable columns on species_profile.
-- See PlantProfile.java for the argument; in short, a plant has light, CO2,
-- growth and placement, and nothing a fish profile holds. product gains
-- plant_profile_id, and a CHECK keeps it from ever being set alongside
-- species_profile_id.
--
-- LIGHT is given as a level and as PAR at the substrate (umol/m2/s), with a
-- rough lumens-per-litre figure in the care guide. PAR is the honest answer
-- to "how strong"; lumens per litre is a rule of thumb for a typical white
-- LED at typical tank depth, and the text says so.
--
-- SOURCES: liveaquaria's quick stats (lighting, placement, propagation, pH,
-- temperature, size) were the starting point, cross-checked against the
-- literature and corrected where wrong (it files Alternanthera in Araceae --
-- it is Amaranthaceae -- and sells Anubias afzelii as "congensis"). The
-- prose is original; nothing is copied from the retailer. Trade names are
-- mapped to current names (Echinodorus tenellus -> Helanthium tenellum,
-- "Cabomba pulcherrima" -> Cabomba furcata, moss ball -> Aegagropila
-- linnaei) and the product keeps the name customers search for.
--
-- INDIA: several of these are Indian natives -- water clover, moneywort
-- (Brahmi), temple plant, water wisteria, Rotala indica, Cryptocoryne
-- spiralis, hornwort -- and the care guides say which ones cope with a 30 C
-- summer and which (HC, glossostigma, marimo, Madagascar lace) need a cool
-- room.
--
-- PRICES ARE ESTIMATES: typical Indian retail for a pot, bunch or tissue-
-- culture cup in 2026, set by Claude, not quoted from a supplier, and not yet
-- reviewed by the owner. is_livestock stays FALSE, as V2 set it for plants.
--
-- PHOTOGRAPHS: 37 of the 49 new products have one, set here in the same
-- change as the files. Twelve stay NULL: no licensed photograph of the right
-- plant exists at the bar (named Echinodorus cultivars, Anubias hastifolia,
-- HC 'Cuba', and four stems). Sources and caveats are in the storefront's
-- species/CREDITS.md; CatalogApiTest pins the list of NULLs.

-- ------------------------------------------------------------ schema --
CREATE TABLE plant_profile (
    id              BIGSERIAL PRIMARY KEY,
    scientific_name VARCHAR(255) NOT NULL UNIQUE,
    common_name     VARCHAR(255) NOT NULL,
    family          VARCHAR(64)  NOT NULL,
    origin          VARCHAR(160) NOT NULL,
    placement       VARCHAR(16)  NOT NULL
        CHECK (placement IN ('FOREGROUND','MIDGROUND','BACKGROUND','EPIPHYTE','FLOATING')),
    light_level     VARCHAR(8)   NOT NULL CHECK (light_level IN ('LOW','MEDIUM','HIGH')),
    par_min         INT          NOT NULL,
    par_max         INT          NOT NULL,
    co2             VARCHAR(12)  NOT NULL CHECK (co2 IN ('NOT_NEEDED','BENEFICIAL','REQUIRED')),
    growth_rate     VARCHAR(8)   NOT NULL CHECK (growth_rate IN ('SLOW','MODERATE','FAST')),
    difficulty      VARCHAR(12)  NOT NULL CHECK (difficulty IN ('EASY','MODERATE','DEMANDING')),
    height_min_cm   NUMERIC(5,1) NOT NULL,
    height_max_cm   NUMERIC(5,1) NOT NULL,
    temp_min_c      NUMERIC(4,1) NOT NULL,
    temp_max_c      NUMERIC(4,1) NOT NULL,
    ph_min          NUMERIC(3,1) NOT NULL,
    ph_max          NUMERIC(3,1) NOT NULL,
    propagation     TEXT         NOT NULL,
    description     TEXT         NOT NULL,
    care_guide      TEXT         NOT NULL,
    tankmates       TEXT         NOT NULL,
    CONSTRAINT plant_par_range    CHECK (par_max >= par_min AND par_min > 0),
    CONSTRAINT plant_height_range CHECK (height_max_cm >= height_min_cm),
    CONSTRAINT plant_temp_range   CHECK (temp_max_c >= temp_min_c),
    CONSTRAINT plant_ph_range     CHECK (ph_max >= ph_min)
);

ALTER TABLE product ADD COLUMN plant_profile_id BIGINT REFERENCES plant_profile(id);
-- A product is an animal, a plant, or neither -- never both.
ALTER TABLE product ADD CONSTRAINT product_one_kind_of_profile
    CHECK (species_profile_id IS NULL OR plant_profile_id IS NULL);

-- ---------------------------------------------------------- sections --
UPDATE category SET status = 'ACTIVE',
       teaser = 'Dwarf hairgrass, HC, water clover.'
 WHERE slug = 'plants-foreground';
UPDATE category SET teaser = 'Anubias, java fern, marimo.' WHERE slug = 'plants-epiphyte';
UPDATE category SET teaser = 'Hygrophila, rotala, ludwigia, hornwort.' WHERE slug = 'plants-stem';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status, image_key)
SELECT 'plants-rosette', 'Swords, Crypts & Bulbs',
       'Rosette plants that grow from a crown or bulb in the substrate and feed through their roots. Give them root tabs.',
       'Amazon sword, crypts, vallisneria.', 15, id, 'ACTIVE', 'sections/plants-rosette.jpg'
  FROM category WHERE slug = 'plants';

-- Vallisneria is not a stem plant and a crypt is not an epiphyte; both were
-- filed by shelf rather than by what they are.
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'plants-rosette')
 WHERE sku IN ('PLT-CRY-01', 'PLT-VAL-01');

-- ------------------------------------------------ profiles and products --

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Eleocharis acicularis$d$, $d$Dwarf Hairgrass$d$, $d$Cyperaceae$d$, $d$Temperate and subtropical wetlands worldwide, including the Himalayan foothills$d$, 'FOREGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'EASY', 3, 10, 18, 28,
  6.0, 7.5, $d$Runners; split the clump into small plugs when planting$d$,
  $d$Dwarf hairgrass is a spike-rush: a sedge whose leaves are nothing but thin, bright-green blades a few centimetres long. Each plug sends out runners just under the substrate, and given light and time those runners knit into a dense, mowable lawn.

It grows naturally at the wet edges of ponds and paddies, above and below water, so it arrives from farms grown emersed and changes to finer, softer underwater blades over the first few weeks. Some of the old blades brown off during that change; that is normal.$d$,
  $d$Split the pot into pinches of five to ten blades and push each 3-4 cm apart into fine gravel or aquasoil, deep enough that the roots are buried but the base of the blades is not. A root tab under each row in the first month speeds up the spread.

Light is what decides whether it carpets. Medium light, about 40-80 PAR at the substrate (roughly 25-40 lumens per litre of tank on a typical LED), for 7-8 hours a day. In low light it grows tall and thin and never joins up. CO2 is not strictly needed, but with it the carpet closes in weeks instead of months. Trim with curved scissors when it passes 5-6 cm so the base keeps getting light, and vacuum the mulm off it at water changes.

It is happiest below 28 C. In an unheated Indian tank that reaches 30-32 C in May it slows down rather than dies; more surface agitation helps.$d$,
  $d$Good with small fish that swim above it: rasboras, tetras, pencilfish, dwarf gouramis, Endler's livebearers and all dwarf shrimp, which graze in it constantly. Corydoras are fine in small numbers, though they will dig a few gaps.

Carpets and diggers do not mix. Anything that sifts or excavates the substrate -- goldfish, eartheaters, most cichlids, large loaches, and big groups of Corydoras -- will lift new plugs before the runners anchor. Once a carpet is established, a small group of Corydoras is usually fine. Shrimp and otocinclus are the best clean-up crew: they graze the carpet without damaging it.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-01', 'dwarf-hairgrass', $d$Dwarf Hairgrass (Pot)$d$, $d$Fine, bright-green grass that runs into a lawn. The classic carpet for a planted tank.$d$, 22000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Eleocharis acicularis$d$), 'species/dwarf-hairgrass.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Helanthium tenellum$d$, $d$Pygmy Chain Sword$d$, $d$Alismataceae$d$, $d$Seasonally flooded wetlands of North and South America$d$, 'FOREGROUND', 'MEDIUM',
  35, 70, 'BENEFICIAL', 'MODERATE', 'EASY', 5, 10, 20, 28,
  6.2, 7.5, $d$Runners; each daughter plant can be cut free and replanted$d$,
  $d$The pygmy chain sword -- sold for decades as Echinodorus tenellus -- is the smallest of the sword plants. Each plant is a tuft of thin, grass-like leaves 5-10 cm tall, and each sends out a chain of runners with a new plantlet every few centimetres, which is where the name comes from.

In strong light the leaves can take on a reddish tinge. Farm-grown plants are often emersed and have broader leaves; they are replaced by narrower underwater leaves within a month.$d$,
  $d$Plant individual tufts 3-5 cm apart in fine gravel or sand, with the crown just at the surface. It is a root feeder like all swords, so put a root tab under it every two to three months.

Medium light, around 35-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day. Under taller plants it gets shaded and stops running, so keep the foreground open. CO2 speeds it up but is not required. Cut runners that head into the midground or trim the chain to shape; the cut daughters root anywhere you push them in.$d$,
  $d$A good carpet for community tanks: tetras, rasboras, livebearers, rams and apistogrammas, which spawn among its leaves, and all dwarf shrimp.

Carpets and diggers do not mix. Anything that sifts or excavates the substrate -- goldfish, eartheaters, most cichlids, large loaches, and big groups of Corydoras -- will lift new plugs before the runners anchor. Once a carpet is established, a small group of Corydoras is usually fine. Shrimp and otocinclus are the best clean-up crew: they graze the carpet without damaging it.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-02', 'pygmy-chain-sword', $d$Pygmy Chain Sword (Pot)$d$, $d$Narrow-leaved dwarf sword that spreads by runners into a low foreground carpet.$d$, 20000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Helanthium tenellum$d$), 'species/pygmy-chain-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Hemianthus callitrichoides$d$, $d$Dwarf Baby Tears$d$, $d$Linderniaceae$d$, $d$Streams and wet rocks of Cuba and the Caribbean$d$, 'FOREGROUND', 'HIGH',
  70, 120, 'REQUIRED', 'MODERATE', 'DEMANDING', 1, 3, 20, 26,
  5.5, 7.0, $d$Division of the mat; small clumps planted with tweezers$d$,
  $d$Dwarf baby tears, usually sold as 'HC Cuba', has leaves only 2-3 mm across -- among the smallest of any aquarium plant. A well-grown carpet looks like bright-green moss and is the signature of competition-style planted tanks.

It is sold as tissue culture: a lab-grown clump in a cup of gel, free of snails, algae and pesticides.$d$,
  $d$Rinse the gel off completely, tease the clump into pieces the size of a fingernail and push each into aquasoil 2 cm apart with tweezers. A 'dry start' -- planting in damp soil, covering the tank with cling film for three to four weeks, then flooding -- gives it a head start without algae.

This is a high-light plant: 70-120 PAR at the substrate (40+ lumens per litre), 7-8 hours a day, and pressurised CO2 is effectively required. Without both it lifts off the substrate and dies back. Feed a complete liquid fertiliser. Trim the carpet flat before it grows thick, or the lower layers rot and the whole mat floats up.

It dislikes heat. Above about 26 C it struggles, so in India it suits an air-conditioned room or a chiller.$d$,
  $d$Best with nano fish that will not dig: celestial pearl danios, chili and phoenix rasboras, ember tetras, otocinclus, and dwarf shrimp, which pick it clean.

This is a plant for a high-light, CO2 tank, and those tanks suit small, peaceful fish that will not uproot or graze: rasboras, small tetras, pencilfish, celestial pearl danios, otocinclus and dwarf shrimp. Keep goldfish, cichlids, silver dollars and any digger away from it. Amano shrimp are the best algae control in a tank run this hard.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-03', 'dwarf-baby-tears', $d$Dwarf Baby Tears 'Cuba' (Tissue Culture)$d$, $d$The tiniest carpet plant in the hobby. For high-light CO2 tanks only.$d$, 35000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Hemianthus callitrichoides$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Glossostigma elatinoides$d$, $d$Glossostigma$d$, $d$Phrymaceae$d$, $d$Shallow lake margins of New Zealand and Australia$d$, 'FOREGROUND', 'HIGH',
  80, 150, 'REQUIRED', 'FAST', 'DEMANDING', 1, 3, 20, 26,
  6.0, 7.5, $d$Runners; plant single stems a few centimetres apart$d$,
  $d$Glossostigma forms a low carpet of pairs of small, spoon-shaped leaves on creeping runners. Grown well it is one of the fastest carpets there is, covering a foreground in a few weeks.

What it cannot do is grow in dim light: its leaves turn upward and it grows vertically, looking for the light, instead of carpeting.$d$,
  $d$Plant single stems or tiny clumps 2-3 cm apart in fine aquasoil with tweezers. Keep taller plants from shading it.

It needs very strong light at the substrate -- 80-150 PAR (50+ lumens per litre) for 7-8 hours -- and pressurised CO2. Feed a complete liquid fertiliser plus root tabs. Once it covers the ground, trim hard every couple of weeks so the carpet does not stack up on itself and rot underneath.

Like most carpets, it prefers water below 26 C.$d$,
  $d$The ideal company is nano fish that swim well above the carpet: chili and phoenix rasboras, ember tetras, celestial pearl danios and otocinclus. Cherry and crystal shrimp graze it constantly without harm.

This is a plant for a high-light, CO2 tank, and those tanks suit small, peaceful fish that will not uproot or graze: rasboras, small tetras, pencilfish, celestial pearl danios, otocinclus and dwarf shrimp. Keep goldfish, cichlids, silver dollars and any digger away from it. Amano shrimp are the best algae control in a tank run this hard.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-04', 'glossostigma', $d$Glossostigma (Tissue Culture)$d$, $d$Fast, bright-green carpet of tiny paddle leaves. High light and CO2 required.$d$, 32000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Glossostigma elatinoides$d$), 'species/glossostigma.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Lilaeopsis novae-zelandiae$d$, $d$Micro Sword$d$, $d$Apiaceae$d$, $d$Estuaries and lake shores of New Zealand$d$, 'FOREGROUND', 'MEDIUM',
  40, 90, 'BENEFICIAL', 'SLOW', 'MODERATE', 3, 8, 18, 27,
  6.5, 7.5, $d$Runners; split into small plugs$d$,
  $d$Micro sword is a small member of the carrot family from New Zealand's estuaries and lake shores, where it grows in shallow water that floods and drains with the tide. It forms dense tufts of stiff, bright-green, grass-like leaves a few centimetres tall, and it spreads on runners into a low, even lawn.

Compared with dwarf hairgrass it is slower to spread, but tidier: its blades stay short, straight and bright green, and it needs less trimming once established.$d$,
  $d$Split the pot into small plugs of three or four blades and plant them 3-4 cm apart in fine gravel or aquasoil, with a root tab under each row. Keep it clear of taller plants that would shade it.

Medium to high light, about 40-90 PAR at the substrate (roughly 25-45 lumens per litre on a typical LED), 7-8 hours a day. It grows without CO2, but CO2 roughly doubles its speed; without it, allow three to six months for a full lawn. Trim runners that stray into the midground, and vacuum debris off the lawn at water changes.

It prefers water below about 27 C. In an unheated Indian tank in summer it slows down; extra surface agitation helps.$d$,
  $d$Good company is small fish that swim above it -- rasboras, tetras, pencilfish, dwarf gouramis -- and dwarf shrimp, which graze it clean.

Carpets and diggers do not mix. Anything that sifts or excavates the substrate -- goldfish, eartheaters, most cichlids, large loaches, and big groups of Corydoras -- will lift new plugs before the runners anchor. Once a carpet is established, a small group of Corydoras is usually fine. Shrimp and otocinclus are the best clean-up crew: they graze the carpet without damaging it.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-05', 'micro-sword', $d$Micro Sword (Pot)$d$, $d$Stiff, bright-green grass that spreads slowly into a lawn.$d$, 20000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Lilaeopsis novae-zelandiae$d$), 'species/micro-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Marsilea quadrifolia$d$, $d$Water Clover$d$, $d$Marsileaceae$d$, $d$Ponds and paddy fields of Europe and Asia, including India$d$, 'FOREGROUND', 'MEDIUM',
  30, 70, 'BENEFICIAL', 'SLOW', 'EASY', 2, 10, 18, 30,
  6.0, 7.5, $d$Runners; cut sections of rhizome with leaves$d$,
  $d$Water clover is not a clover at all but a small aquatic fern, Marsilea quadrifolia, that grows wild in ponds and paddy fields across Europe and Asia, including India. Out of water it carries four-lobed leaves on long stalks, like a lucky clover; submerged, it often makes single, rounded leaves that hug the substrate.

It spreads by a creeping rhizome and is one of the few carpets that does well without CO2, and one that tolerates the heat of an Indian summer.$d$,
  $d$Plant short sections of rhizome with a few leaves each, 3 cm apart, rhizome just under the surface. A root tab under the group helps it establish.

Medium light, about 30-70 PAR at the substrate (roughly 20-35 lumens per litre), 6-8 hours a day. It is slow to start -- often a month before it spreads -- then steady. The stronger the light, the lower and denser it grows; in dim light it sends leaves up on tall stalks. CO2 helps but is not needed.

It handles 18-30 C, which makes it one of the more reliable carpets for an unheated tank in India.$d$,
  $d$Good with livebearers, rasboras, tetras and dwarf shrimp. Its tough little leaves are not a favourite food.

Carpets and diggers do not mix. Anything that sifts or excavates the substrate -- goldfish, eartheaters, most cichlids, large loaches, and big groups of Corydoras -- will lift new plugs before the runners anchor. Once a carpet is established, a small group of Corydoras is usually fine. Shrimp and otocinclus are the best clean-up crew: they graze the carpet without damaging it.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-06', 'four-leaf-clover', $d$Water Clover (Pot)$d$, $d$Tiny aquatic fern with clover-like leaves. An easy, low-tech carpet.$d$, 18000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Marsilea quadrifolia$d$), 'species/four-leaf-clover.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Nymphoides aquatica$d$, $d$Banana Plant$d$, $d$Menyanthaceae$d$, $d$Lakes and slow rivers of the south-eastern United States$d$, 'FOREGROUND', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'MODERATE', 'EASY', 10, 40, 20, 28,
  6.0, 7.5, $d$Plantlets from floating leaves; the bananas themselves$d$,
  $d$The banana plant grows from a cluster of plump, finger-like storage roots that look exactly like a small bunch of bananas. From them it sends up heart-shaped underwater leaves and, in time, round floating pads like a miniature water lily, sometimes with small white flowers.

The bananas store starch, which is how the plant survives while it settles in; as it roots and grows they slowly shrink. It is native to lakes and slow rivers of the south-eastern United States.$d$,
  $d$Do not bury the bananas. Rest them on the substrate, or push in only their tips, so they stay exposed to light; buried, they rot. Roots grow down from the bananas within a couple of weeks.

Medium light, about 30-70 PAR at the substrate (roughly 20-35 lumens per litre), 6-8 hours a day. No CO2 needed; a root tab nearby helps. It will send long-stemmed leaves to the surface -- trim them off to keep the plant low, or let them float for shade. A floating leaf pressed into the substrate can root and grow a new plant.$d$,
  $d$Good with community fish and shrimp. Bettas and gouramis rest under its floating leaves and use them as cover.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FG-07', 'banana-plant', $d$Banana Plant$d$, $d$Round lily-pad leaves above a bunch of banana-shaped storage roots. A conversation piece.$d$, 25000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Nymphoides aquatica$d$), 'species/banana-plant.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias barteri var. nana$d$, $d$Anubias Nana$d$, $d$Araceae$d$, $d$Rivers and streams of Cameroon, West Africa$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 5, 15, 22, 30,
  6.0, 8.0, $d$Rhizome division: cut the rhizome with a few leaves on each piece$d$,
  $d$Anubias nana is the compact, dwarf form of Anubias barteri: thick, dark-green, heart- to lance-shaped leaves on short stems growing from a creeping rhizome. In its home streams in Cameroon it grows on rocks and roots at the water's edge, often half out of the water.

It is almost impossible to kill, which is why it is in nearly every aquarium shop in the world. This one is already attached to driftwood, so there is nothing to plant.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.$d$,
  $d$Anubias leaves are tough and bitter, so it is one of the few plants that survives with fish that destroy everything else: African cichlids (Malawi mbuna included), goldfish, silver dollars and plecos. Bettas and gouramis like resting on its broad leaves, and shrimp graze the biofilm on them.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-ANU-02', 'anubias-nana', $d$Anubias Nana on Driftwood$d$, $d$Tough, dark-green Anubias already tied to a piece of driftwood. Place it and it is done.$d$, 55000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias barteri var. nana$d$), 'species/anubias-nana.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias barteri$d$, $d$Anubias Barteri$d$, $d$Araceae$d$, $d$Rivers and streams of West Africa, Nigeria to Cameroon$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 15, 40, 22, 30,
  6.0, 8.0, $d$Rhizome division$d$,
  $d$Anubias barteri is the full-sized parent of the familiar Anubias nana, from the rivers and streams of West Africa, where it grows on rocks and roots at the water's edge, often half out of the water. It has broad, dark-green, leathery, heart- to spear-shaped leaves on long stems, and a mature plant can reach 30-40 cm across.

It grows one slow leaf at a time from a thick creeping rhizome and is one of the toughest plants in the hobby.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.

At full size it suits the midground or background of a tank at least 45 cm tall.$d$,
  $d$Bettas, gouramis and angelfish use its broad leaves as resting places and spawning sites.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-ANU-03', 'anubias-barteri', $d$Anubias Barteri (Pot)$d$, $d$The full-sized Anubias: broad, dark leaves on a creeping rhizome. Nearly indestructible.$d$, 45000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias barteri$d$), 'species/anubias-barteri.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias barteri 'Coffeefolia'$d$, $d$Anubias Coffeefolia$d$, $d$Araceae$d$, $d$Cultivated variety of a West African species$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 10, 25, 22, 30,
  6.0, 8.0, $d$Rhizome division$d$,
  $d$Anubias 'Coffeefolia' is a variety of Anubias barteri with strongly ribbed, puckered leaves, like those of a coffee bush -- hence the name. New leaves unfurl a translucent bronze-red and darken to deep green over a few weeks, so a healthy plant always shows both colours.

It grows a little taller and more open than Anubias nana, to about 20-25 cm, and suits the midground. Its care is identical to other Anubias.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.$d$,
  $d$Shrimp spend hours grazing the biofilm in its ribbed leaves, and bettas rest on them.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-ANU-04', 'anubias-coffeefolia', $d$Anubias Coffeefolia (Pot)$d$, $d$Anubias with ribbed, coffee-leaf texture and bronze-red new leaves.$d$, 55000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias barteri 'Coffeefolia'$d$), 'species/anubias-coffeefolia.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias hastifolia$d$, $d$Anubias Hastifolia$d$, $d$Araceae$d$, $d$Forest streams of West and Central Africa$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 20, 40, 22, 30,
  6.0, 8.0, $d$Rhizome division$d$,
  $d$Anubias hastifolia is one of the largest Anubias, from forest streams in West and Central Africa. Its leaves are spear- or arrow-shaped with two small lobes at the base, held on long stems, and a mature plant can reach 40 cm.

Like its relatives it grows slowly from a creeping rhizome and is almost indestructible, making it a background centrepiece for large tanks -- including cichlid tanks, where little else survives.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.$d$,
  $d$Large, robust fish that destroy other plants -- cichlids, goldfish, silver dollars -- leave it alone, and it gives them cover.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-ANU-05', 'anubias-hastifolia', $d$Anubias Hastifolia (Pot)$d$, $d$A large Anubias with arrow-shaped leaves on tall stems. A background centrepiece.$d$, 65000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias hastifolia$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias afzelii$d$, $d$Anubias Congensis$d$, $d$Araceae$d$, $d$Streams of West Africa, Senegal to Sierra Leone$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 15, 40, 22, 30,
  6.0, 8.0, $d$Rhizome division$d$,
  $d$Sold as 'Anubias congensis', this is usually Anubias afzelii, a West African species from Senegal to Sierra Leone. It has long, narrow, lance-shaped leaves in a lighter green than Anubias barteri, on tall stems, reaching 30-40 cm.

It is a good choice for the back of a low-tech tank, where it grows slowly and needs almost no attention.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.$d$,
  $d$Tall and tough, it gives cover to cichlids and gouramis that would eat softer background plants.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-ANU-06', 'anubias-congensis', $d$Anubias Congensis (Pot)$d$, $d$Tall Anubias with long, narrow, bright-green leaves.$d$, 50000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias afzelii$d$), 'species/anubias-congensis.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Microsorum pteropus$d$, $d$Java Fern$d$, $d$Polypodiaceae$d$, $d$Streams and waterfalls of South-East Asia, including north-east India$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 15, 30, 20, 30,
  6.0, 7.5, $d$Plantlets on the leaves; rhizome division$d$,
  $d$Java fern is a true fern that grows on rocks and roots in fast streams and waterfalls across South-East Asia, including north-east India. It has long, leathery, bright-green leaves on a creeping rhizome, and it reproduces by growing small plantlets on the undersides and tips of older leaves.

Its leaves contain compounds that make it unpalatable, so almost nothing eats it -- which, together with its tolerance of low light, heat and hard water, makes it the standard plant for cichlid tanks and beginners alike. 'Narrow', 'Windelov' and 'Trident' are forms of the same species.$d$,
  $d$Tie it to wood or rock with cotton thread or fishing line, glue it with gel superglue, or wedge it into a crevice. Do not bury the rhizome; it rots. The roots grip within a few weeks.

Low light is plenty: 15-40 PAR at the plant (about 10-20 lumens per litre), 6-8 hours a day. Strong light causes brown and black patches on the leaves; so does a lack of potassium. No CO2 needed. Feed a liquid fertiliser, since it takes food from the water. Cut plantlets off once they have a few roots and tie them on elsewhere, and trim off old leaves that go brown.$d$,
  $d$It survives with almost any fish, including those that destroy other plants: African and American cichlids, goldfish, silver dollars and large plecos.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FRN-01', 'java-fern', $d$Java Fern (Pot)$d$, $d$Tough, low-light fern tied to wood or rock. Nothing eats it.$d$, 30000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Microsorum pteropus$d$), 'species/java-fern.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Ceratopteris thalictroides$d$, $d$Water Sprite$d$, $d$Pteridaceae$d$, $d$Tropical wetlands worldwide, including rice fields across India$d$, 'FLOATING', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'FAST', 'EASY', 15, 40, 20, 30,
  6.0, 7.5, $d$Plantlets on the leaves$d$,
  $d$Water sprite is a fast-growing aquatic fern found in rice fields and ditches across India and the rest of the tropics. It has soft, lacy, deeply divided light-green leaves, and it reproduces by growing plantlets along the leaf edges.

It can be planted in the substrate, where it grows into a tall, bushy plant, or left to float, where it forms a mat with trailing roots. Either way it grows fast enough to use up nitrate and phosphate, which helps keep algae down in a new tank.$d$,
  $d$Planted: push the roots into the substrate with the crown above it. Floating: simply drop it in, but keep the surface from being covered completely, or plants below go dark.

Medium light, 30-70 PAR (about 20-35 lumens per litre), 7-8 hours a day. No CO2 needed; a liquid fertiliser keeps the leaves green. It grows fast, so thin it weekly and pull off plantlets to replant or give away. It tolerates 20-30 C, suiting unheated Indian tanks.$d$,
  $d$Livebearers, bettas and gouramis use it as cover, fry hide in its roots, and gouramis anchor bubble nests to it when it floats.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FRN-02', 'water-sprite', $d$Water Sprite (Bunch)$d$, $d$Fast, lacy fern that can float or be planted. Mops up nitrate.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Ceratopteris thalictroides$d$), 'species/water-sprite.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Aegagropila linnaei$d$, $d$Marimo Moss Ball$d$, $d$Pithophoraceae$d$, $d$Cold lakes of Japan, Iceland and northern Europe$d$, 'FOREGROUND', 'LOW',
  10, 30, 'NOT_NEEDED', 'SLOW', 'EASY', 2, 8, 15, 26,
  6.5, 8.0, $d$Division: cut a ball in half and roll each half back into shape$d$,
  $d$A marimo is not a moss but a filamentous green alga that grows into a velvety ball, rolled round by gentle wave action on the beds of cold lakes in Japan, Iceland and northern Europe. In Japan, Lake Akan's marimo are a protected natural monument.

It grows only a few millimetres a year and can live for decades. In the aquarium it is a low-maintenance ornament for the foreground, and a surface shrimp love to graze.$d$,
  $d$Place it on the substrate in a spot with low to moderate light, 10-30 PAR; direct strong light can bleach it white. Turn it every week or two so all sides get light and it stays round. At water changes, rinse it in old tank water and gently squeeze it out like a sponge.

It is a cold-water organism and suffers above about 26 C. In an Indian summer, keep it in the coolest part of the tank or in an air-conditioned room; a marimo that turns brown is usually too warm. A brown patch can be trimmed off, and a ball can be cut in half and rolled into two.$d$,
  $d$Shrimp and snails graze it constantly and keep it clean; small, gentle fish leave it alone.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-FRN-03', 'moss-ball', $d$Marimo Moss Ball$d$, $d$A living ball of green algae. Roll it now and then and it lasts for years.$d$, 18000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-epiphyte'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Aegagropila linnaei$d$), 'species/moss-ball.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus grisebachii 'Amazonicus'$d$, $d$Amazon Sword$d$, $d$Alismataceae$d$, $d$Flooded forests and river margins of the Amazon basin$d$, 'BACKGROUND', 'MEDIUM',
  30, 60, 'NOT_NEEDED', 'MODERATE', 'EASY', 30, 50, 22, 30,
  6.5, 7.5, $d$Plantlets on flower stems (runners)$d$,
  $d$The Amazon sword is the plant most people picture when they think of a planted tank: a rosette of 20-40 long, lance-shaped, bright-green leaves that fans out from a single crown. It lives along flooded river edges in the Amazon, growing submerged for half the year and emersed for the other half.

A single well-fed plant can fill the back corner of a 100 L tank on its own. Trade names are muddled -- 'bleheri', 'amazonicus' and 'grisebachii' are sold for near-identical plants, and all are cared for the same way.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 30-60 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$The broad leaves are a classic spawning site for angelfish and discus, and a good backdrop for tetras, rasboras, gouramis, rams, Corydoras and livebearers.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-01', 'amazon-sword', $d$Amazon Sword (Pot)$d$, $d$The classic background centrepiece: a big rosette of long, bright-green leaves.$d$, 25000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus grisebachii 'Amazonicus'$d$), 'species/amazon-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus osiris$d$, $d$Melon Sword$d$, $d$Alismataceae$d$, $d$Rivers of southern Brazil$d$, 'BACKGROUND', 'MEDIUM',
  30, 60, 'NOT_NEEDED', 'MODERATE', 'EASY', 25, 50, 18, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome side shoots$d$,
  $d$The melon sword is a large, robust sword from southern Brazil, with broad, slightly wavy leaves. New leaves come in reddish-brown before turning green, which gives the plant a warm colour when it is growing well.

It tolerates cooler water than most swords.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 30-60 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$Its broad leaves suit angelfish and discus for spawning, and gouramis and tetras for cover.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-02', 'melon-sword', $d$Melon Sword (Pot)$d$, $d$A large sword with broad leaves that emerge red-brown before turning green.$d$, 28000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus osiris$d$), 'species/melon-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Ozelot'$d$, $d$Ozelot Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid (Echinodorus schlueteri x E. barthii)$d$, 'MIDGROUND', 'MEDIUM',
  40, 70, 'NOT_NEEDED', 'MODERATE', 'EASY', 20, 40, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$The Ozelot sword is a cultivated hybrid with green leaves dotted with dark red-brown spots, like the coat of the ocelot it is named after. The spots are strongest in good light.

It is hardy and compact enough for a midground position in larger tanks.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-70 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$Compact enough for a midground, it suits community fish, angelfish and dwarf cichlids.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-03', 'ozelot-sword', $d$Ozelot Sword (Pot)$d$, $d$Green sword with dark red-brown spots, like an ocelot's coat.$d$, 30000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Ozelot'$d$), 'species/ozelot-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Red Flame'$d$, $d$Red Flame Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid$d$, 'MIDGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'EASY', 20, 30, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$Red Flame is a compact hybrid sword bred for colour. Its oval to lance-shaped leaves are heavily flecked and flushed with red over green, and new leaves emerge the deepest red. It stays about 20-30 cm tall, which suits the midground of a medium tank.

Colour depends on light and iron: in a dim, unfed tank it drifts towards green; with brighter light and an iron-rich root tab it stays vivid.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-80 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$A red focal plant for community tanks with tetras, rasboras, gouramis and dwarf cichlids.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-04', 'red-flame-sword', $d$Red Flame Sword (Pot)$d$, $d$Sword hybrid with green leaves heavily splashed with red.$d$, 35000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Red Flame'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Rubin'$d$, $d$Red Rubin Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'EASY', 30, 50, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$Red Rubin is a large hybrid sword with long, oval leaves in deep red, maroon and brown. Young leaves are the reddest; older ones turn olive-brown. It can reach 40-50 cm and is one of the most striking red plants for the background of a large tank.

Like other swords it is a heavy root feeder, and it rewards iron-rich root tabs with deeper colour.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-80 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$A red backdrop for angelfish, discus and large tetras such as congo tetras.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-05', 'red-rubin-sword', $d$Red Rubin Sword (Pot)$d$, $d$A large sword with deep red-brown leaves.$d$, 35000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Rubin'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Kleiner Bär'$d$, $d$Kleiner Bär Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid$d$, 'MIDGROUND', 'MEDIUM',
  40, 70, 'NOT_NEEDED', 'MODERATE', 'EASY', 15, 30, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$'Kleiner Bär' -- German for 'little bear' -- is a compact hybrid sword whose leaves emerge red-brown and turn olive-green as they age, so a healthy plant shows a spread of colours. It stays about 15-30 cm, a good size for the midground.

It is hardy and forgiving, and a good first red plant for a tank without CO2.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-70 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$Suits community fish and dwarf cichlids such as rams and apistogrammas, which spawn near its base.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-06', 'kleiner-bar-sword', $d$Kleiner Bär Sword (Pot)$d$, $d$Compact sword with red-brown leaves that fade to green.$d$, 32000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Kleiner Bär'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Oriental'$d$, $d$Oriental Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'MODERATE', 25, 40, 20, 28,
  6.2, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$Echinodorus 'Oriental' is a hybrid sword with long, narrow, strongly wavy-edged leaves in light green, sometimes with a pinkish tinge on new growth. It reaches 25-40 cm and gives the background an airy, rippled look.

It needs somewhat more light than the standard Amazon sword to keep its compact shape.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-80 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$Suits community fish and angelfish.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-07', 'oriental-sword', $d$Oriental Sword (Pot)$d$, $d$Sword with long, wavy, light-green leaves.$d$, 32000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Oriental'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus 'Hadi Red Pearl'$d$, $d$Hadi Red Pearl Sword$d$, $d$Alismataceae$d$, $d$Cultivated hybrid$d$, 'MIDGROUND', 'MEDIUM',
  50, 90, 'BENEFICIAL', 'MODERATE', 'EASY', 15, 25, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$Hadi Red Pearl is a compact hybrid sword with glossy, rounded leaves in deep red to wine-red that hold their colour well. It stays about 15-25 cm tall, small enough for the midground of a 60 cm tank.

Its colour is strongest with good light and iron-rich root feeding.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 50-90 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$A red accent for community tanks and dwarf cichlid setups.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-08', 'red-pearl-sword', $d$Hadi Red Pearl Sword (Pot)$d$, $d$Compact sword with glossy, deep red leaves.$d$, 38000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus 'Hadi Red Pearl'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus major$d$, $d$Ruffled Sword$d$, $d$Alismataceae$d$, $d$Rivers of eastern Brazil$d$, 'BACKGROUND', 'MEDIUM',
  30, 60, 'NOT_NEEDED', 'MODERATE', 'EASY', 30, 50, 22, 28,
  6.5, 7.5, $d$Plantlets on flower stems; rhizome division$d$,
  $d$The ruffled sword, sold as Echinodorus martii and properly Echinodorus major, comes from the rivers of eastern Brazil. It has long, bright-green leaves with strongly wavy, ruffled edges that ripple in the current.

It grows into a large, open rosette of 30-50 cm, suited to the background of a big tank.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 30-60 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$Suits angelfish, discus, gouramis and larger tetras.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-09', 'ruffle-sword', $d$Ruffled Sword (Pot)$d$, $d$Large sword with strongly ruffled, wavy-edged leaves.$d$, 30000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus major$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Echinodorus cordifolius 'Marble Queen'$d$, $d$Marble Queen Sword$d$, $d$Alismataceae$d$, $d$Cultivated variety of a species from North and Central America$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'EASY', 20, 50, 20, 28,
  6.5, 7.5, $d$Plantlets on flower stems$d$,
  $d$Marble Queen is a variegated form of the radican sword, Echinodorus cordifolius, with broad, heart-shaped leaves marbled and speckled in cream, yellow and green. No two leaves are patterned alike.

In a tank it can grow large, and it will send leaves above the surface if left to itself; trimming the tallest leaves keeps it submerged and compact. The photograph shows the plain green species; the Marble Queen's variegation is the difference.$d$,
  $d$Plant it with the crown -- where the leaves meet the roots -- just above the substrate, in at least 5-6 cm of gravel, sand or aquasoil. Sword plants are heavy root feeders: push a root tab (iron-rich substrate fertiliser) in beside the roots when planting and every two to three months after, or the new leaves come in pale and yellow between the veins. Liquid fertiliser helps but is not a substitute.

Light: medium, about 40-80 PAR at the substrate -- roughly 20-40 lumens per litre on a typical LED -- for 7-8 hours a day. CO2 is not needed, though it makes growth faster and more compact. Newly planted swords often drop their farm-grown leaves while the roots settle; cut these off at the base and wait for the new ones.

Remove old outer leaves as they yellow. If the plant sends up a flower stem, it will grow small plantlets along it; peg the stem down to the substrate and they root, or cut them free once they have a few leaves of their own. Swords tolerate warm water well, up to about 28-30 C, which suits unheated Indian tanks.$d$,
  $d$A bold background plant for angelfish, gouramis and large tetras.

Sword plants are big, hungry and tolerant, so they suit most community tanks, and angelfish and discus use their broad leaves to spawn. Plant-eaters and diggers destroy them: goldfish, silver dollars, tinfoil barbs, Buenos Aires tetras, oscars and most large cichlids. A large, underfed pleco may rasp holes in the leaves; otocinclus and Amano shrimp clean them without damage.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SWD-10', 'marble-queen-sword', $d$Marble Queen Sword (Pot)$d$, $d$Heart-shaped leaves marbled cream and green. Grows large.$d$, 32000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Echinodorus cordifolius 'Marble Queen'$d$), 'species/marble-queen-sword.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Cryptocoryne wendtii$d$, $d$Cryptocoryne Wendtii$d$, $d$Araceae$d$, $d$Streams of Sri Lanka$d$, 'MIDGROUND', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 10, 20, 22, 30,
  6.0, 8.0, $d$Runners; separate daughter plants$d$,
  $d$Cryptocoryne wendtii comes from the streams of Sri Lanka and is the most widely kept crypt. It forms a low rosette of wavy, lance-shaped leaves in green, brown or red-bronze depending on the variety and the light.

It is one of the easiest plants for a low-light tank and, once settled, one of the most reliable.$d$,
  $d$Plant it with the roots buried and the crown at the substrate surface, in fine gravel, sand or aquasoil, and leave it alone. Crypts hate being moved.

Expect 'crypt melt': within a week or two of planting, or after any sudden change in light, temperature or water, many crypts drop most or all of their leaves. The roots are fine. Leave the plant where it is, keep the water stable, and new leaves come back within three to six weeks. Buying one and seeing it melt is not a dead plant.

Light: low to medium, 15-40 PAR at the substrate (about 10-30 lumens per litre), 6-8 hours a day -- crypts are among the best plants for dim tanks and shaded corners. CO2 is not needed. They feed through their roots, so push a root tab in beside them every two to three months. Once settled they spread slowly by runners into a clump; cut daughter plants free with a few roots and replant them elsewhere.$d$,
  $d$Suits nearly all community fish -- tetras, rasboras, gouramis, livebearers, dwarf cichlids -- and bottom-dwellers such as Corydoras and kuhli loaches, which rest among its leaves. Its tough leaves also survive many fish that eat softer plants.

Crypts are tough and slightly bitter, so they survive many fish that eat softer plants. They are the classic low-light plant for Corydoras, kuhli loaches, gouramis, rasboras and dwarf cichlids, which shelter among the leaves. Only diggers -- goldfish and large cichlids -- are a real threat, and mainly before the roots are established.$d$);

UPDATE product SET plant_profile_id = (SELECT id FROM plant_profile WHERE scientific_name = $d$Cryptocoryne wendtii$d$) WHERE slug = 'cryptocoryne-wendtii';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Cryptocoryne spiralis$d$, $d$Cryptocoryne Spiralis$d$, $d$Araceae$d$, $d$Rivers and seasonal pools of western and southern India$d$, 'MIDGROUND', 'LOW',
  20, 50, 'NOT_NEEDED', 'SLOW', 'MODERATE', 15, 40, 20, 30,
  6.5, 8.0, $d$Runners; rhizome division$d$,
  $d$Cryptocoryne spiralis is an Indian plant, native to the Western Ghats and the seasonal pools of peninsular India, where it spends the dry season as a dormant rhizome. Its long, narrow leaves grow in a loose rosette and often twist slightly, giving it its name.

It is taller than wendtii, and its narrow leaves suit the midground or background of smaller tanks.$d$,
  $d$Plant it with the roots buried and the crown at the substrate surface, in fine gravel, sand or aquasoil, and leave it alone. Crypts hate being moved.

Expect 'crypt melt': within a week or two of planting, or after any sudden change in light, temperature or water, many crypts drop most or all of their leaves. The roots are fine. Leave the plant where it is, keep the water stable, and new leaves come back within three to six weeks. Buying one and seeing it melt is not a dead plant.

Light: low to medium, 20-50 PAR at the substrate (about 10-30 lumens per litre), 6-8 hours a day -- crypts are among the best plants for dim tanks and shaded corners. CO2 is not needed. They feed through their roots, so push a root tab in beside them every two to three months. Once settled they spread slowly by runners into a clump; cut daughter plants free with a few roots and replant them elsewhere.$d$,
  $d$Its long leaves suit Indian biotope tanks with rasboras, danios, barbs and loaches.

Crypts are tough and slightly bitter, so they survive many fish that eat softer plants. They are the classic low-light plant for Corydoras, kuhli loaches, gouramis, rasboras and dwarf cichlids, which shelter among the leaves. Only diggers -- goldfish and large cichlids -- are a real threat, and mainly before the roots are established.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-CRY-02', 'cryptocoryne-spiralis', $d$Cryptocoryne Spiralis (Pot)$d$, $d$An Indian crypt with long, narrow, twisting leaves. Hardy and slow.$d$, 28000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Cryptocoryne spiralis$d$), 'species/cryptocoryne-spiralis.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Cryptocoryne crispatula var. balansae$d$, $d$Cryptocoryne Balansae$d$, $d$Araceae$d$, $d$Streams of Thailand, Vietnam and southern China$d$, 'BACKGROUND', 'MEDIUM',
  30, 60, 'BENEFICIAL', 'SLOW', 'MODERATE', 20, 50, 22, 28,
  6.5, 8.0, $d$Runners$d$,
  $d$Cryptocoryne crispatula var. balansae comes from streams in Thailand, Vietnam and southern China. Its long, narrow leaves are strongly crinkled along their length, like crimped ribbon, and grow to 30-50 cm, making a textured background in bronze-green.

Unusually for a crypt, it likes harder, more alkaline water, which suits Indian tap water well.$d$,
  $d$Plant it with the roots buried and the crown at the substrate surface, in fine gravel, sand or aquasoil, and leave it alone. Crypts hate being moved.

Expect 'crypt melt': within a week or two of planting, or after any sudden change in light, temperature or water, many crypts drop most or all of their leaves. The roots are fine. Leave the plant where it is, keep the water stable, and new leaves come back within three to six weeks. Buying one and seeing it melt is not a dead plant.

Light: low to medium, 30-60 PAR at the substrate (about 10-30 lumens per litre), 6-8 hours a day -- crypts are among the best plants for dim tanks and shaded corners. CO2 is not needed. They feed through their roots, so push a root tab in beside them every two to three months. Once settled they spread slowly by runners into a clump; cut daughter plants free with a few roots and replant them elsewhere.$d$,
  $d$Suits hard-water fish such as livebearers and rainbowfish, as well as gouramis and barbs.

Crypts are tough and slightly bitter, so they survive many fish that eat softer plants. They are the classic low-light plant for Corydoras, kuhli loaches, gouramis, rasboras and dwarf cichlids, which shelter among the leaves. Only diggers -- goldfish and large cichlids -- are a real threat, and mainly before the roots are established.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-CRY-03', 'cryptocoryne-balansae', $d$Cryptocoryne Balansae (Pot)$d$, $d$Tall crypt with long, narrow, crinkled ribbon leaves.$d$, 30000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Cryptocoryne crispatula var. balansae$d$), 'species/cryptocoryne-balansae.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Sagittaria subulata$d$, $d$Dwarf Sagittaria$d$, $d$Alismataceae$d$, $d$Coastal marshes of the eastern United States$d$, 'FOREGROUND', 'LOW',
  20, 60, 'NOT_NEEDED', 'MODERATE', 'EASY', 5, 15, 18, 30,
  6.5, 7.5, $d$Runners$d$,
  $d$Dwarf Sagittaria has narrow, strap-like, bright-green leaves 5-15 cm long and spreads quickly by runners into a dense, grassy carpet. It comes from coastal marshes of the eastern United States.

It is the easiest 'carpet' for a tank without CO2 or strong light: it will not be as low as dwarf hairgrass, but it will cover the ground in a low-tech tank.$d$,
  $d$Plant clumps of two or three plants 3-5 cm apart, crowns just above the substrate. A root tab under each row helps.

Low to medium light, 20-60 PAR at the substrate (about 15-30 lumens per litre), 6-8 hours a day. No CO2 needed. Height depends on light: dim light makes it taller (up to 15 cm), bright light keeps it low. Pull runners that head into the midground. It tolerates 18-30 C.$d$,
  $d$Good with community fish, livebearers, Corydoras once established, and dwarf shrimp.

Carpets and diggers do not mix. Anything that sifts or excavates the substrate -- goldfish, eartheaters, most cichlids, large loaches, and big groups of Corydoras -- will lift new plugs before the runners anchor. Once a carpet is established, a small group of Corydoras is usually fine. Shrimp and otocinclus are the best clean-up crew: they graze the carpet without damaging it.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SAG-01', 'dwarf-sagittaria', $d$Dwarf Sagittaria (Pot)$d$, $d$Grass-like leaves that run into a low carpet. Easy, low-tech foreground.$d$, 18000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-foreground'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Sagittaria subulata$d$), 'species/dwarf-sagittaria.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Sagittaria platyphylla$d$, $d$Sagittaria Chilensis$d$, $d$Alismataceae$d$, $d$Wetlands of the south-eastern United States$d$, 'MIDGROUND', 'MEDIUM',
  30, 60, 'NOT_NEEDED', 'MODERATE', 'EASY', 10, 30, 20, 28,
  6.5, 7.5, $d$Runners$d$,
  $d$Sold as 'Sagittaria chilensis', this is Sagittaria platyphylla from the south-eastern United States. Submerged, it grows broad, strap-shaped, bright-green leaves 10-30 cm long in a rosette, spreading by runners into a clump.

It is sturdier and broader-leaved than dwarf Sagittaria, and suits the midground.$d$,
  $d$Plant with the crown just above the substrate; root tabs every two to three months.

Medium light, 30-60 PAR (about 20-30 lumens per litre), 7-8 hours a day. No CO2 needed. Remove runners to keep it contained, or let them fill in a clump. It tolerates hard water and 20-28 C.$d$,
  $d$Suits community fish and livebearers.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-SAG-02', 'sagittaria-chilensis', $d$Sagittaria Chilensis (Pot)$d$, $d$Broader-leaved Sagittaria for the midground.$d$, 20000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Sagittaria platyphylla$d$), 'species/sagittaria-chilensis.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Vallisneria nana$d$, $d$Vallisneria Nana$d$, $d$Hydrocharitaceae$d$, $d$Rivers and billabongs of northern Australia$d$, 'BACKGROUND', 'LOW',
  20, 60, 'NOT_NEEDED', 'FAST', 'EASY', 20, 50, 18, 30,
  6.5, 8.0, $d$Runners$d$,
  $d$Vallisneria nana is a slender eelgrass from the rivers and billabongs of northern Australia. It grows long, thin, ribbon-like leaves only a few millimetres wide, 20-50 cm tall, that sway in the current, and it spreads quickly by runners into a curtain.

It is narrower and more delicate than the giant and corkscrew Vallisneria, and suits the background of medium tanks.$d$,
  $d$Plant with the crown -- the pale point where roots meet leaves -- just above the substrate. Buried crowns rot.

Low to medium light, 20-60 PAR (about 15-30 lumens per litre). No CO2 needed. It loves hard water and is one of the best plants for Indian tap water; it dislikes some liquid-carbon algaecides, which make it melt. Pull runners to control its spread, and trim leaves that lie across the surface.$d$,
  $d$Suits livebearers, rainbowfish, barbs and many cichlids -- including Tanganyikan shell-dwellers, which spawn at its base.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

UPDATE product SET plant_profile_id = (SELECT id FROM plant_profile WHERE scientific_name = $d$Vallisneria nana$d$) WHERE slug = 'vallisneria-nana';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Aponogeton madagascariensis$d$, $d$Madagascar Lace Plant$d$, $d$Aponogetonaceae$d$, $d$Shaded, fast streams of Madagascar$d$, 'MIDGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'DEMANDING', 20, 50, 20, 26,
  6.0, 7.0, $d$Bulb division; seeds$d$,
  $d$The Madagascar lace plant is one of the most extraordinary plants in the hobby. Its long, oval leaves are nothing but a network of veins with open windows between them, like fine lace. It grows from a tuber in shaded, fast-flowing, soft-water streams in Madagascar, where it is now collected under protection; plants in the trade are cultivated.

It is a specialist plant. It needs cool, soft, very clean water, and in the wild it rests for a few months each year.$d$,
  $d$Plant the tuber with its top just at the substrate surface, in fine gravel or aquasoil, with a root tab nearby.

Medium light, 40-80 PAR (about 25-40 lumens per litre), 7-8 hours; CO2 helps. It needs soft, slightly acidic, cool water -- 20-26 C, which in India usually means an air-conditioned room -- with a strong current and frequent water changes, because its lace leaves trap debris and algae. After six months or more of growth it may die back; lift the tuber, keep it in cooler water or damp sand for a couple of months, then replant.$d$,
  $d$Keep it with small, gentle fish: rasboras, small tetras, otocinclus and dwarf shrimp.

This is a plant for a high-light, CO2 tank, and those tanks suit small, peaceful fish that will not uproot or graze: rasboras, small tetras, pencilfish, celestial pearl danios, otocinclus and dwarf shrimp. Keep goldfish, cichlids, silver dollars and any digger away from it. Amano shrimp are the best algae control in a tank run this hard.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-BLB-01', 'madagascar-lace', $d$Madagascar Lace Plant (Bulb)$d$, $d$Leaves that are pure lattice, like lace. A specialist centrepiece.$d$, 65000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-rosette'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Aponogeton madagascariensis$d$), 'species/madagascar-lace.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Ceratophyllum demersum$d$, $d$Hornwort$d$, $d$Ceratophyllaceae$d$, $d$Ponds and lakes on every continent except Antarctica, including across India$d$, 'BACKGROUND', 'LOW',
  15, 60, 'NOT_NEEDED', 'FAST', 'EASY', 30, 100, 15, 30,
  6.0, 8.0, $d$Side shoots; any broken piece grows$d$,
  $d$Hornwort grows in still water almost everywhere in the world, including ponds and tanks across India. It has whorls of stiff, forked, needle-like leaves along long, brittle stems, and it has no true roots at all: it floats free or anchors loosely with pale modified leaves.

It is the fastest-growing plant in this section and one of the best at soaking up nitrate and starving algae, which makes it the ideal first plant in a new tank.$d$,
  $d$Plant the stems loosely, weigh them down, or simply let the bunch float. It grows in almost any light, from 15 to 60 PAR (10-30 lumens per litre), and needs neither CO2 nor fertiliser in a stocked tank -- the fish feed it.

It can grow several centimetres a day. Thin it every week or two by pulling out whole stems. It sheds needles when moved or when conditions change sharply, then settles. Never tip spare hornwort into a drain, pond or river.$d$,
  $d$Good with nearly everything: livebearers, goldfish (which nibble but rarely finish it), barbs, danios and cichlids. Livebearer and killifish fry hide in it, and it is the standard spawning mop for egg-scatterers.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-01', 'hornwort', $d$Hornwort (Bunch of 6)$d$, $d$The toughest, fastest stem plant there is. Plant it or float it.$d$, 12000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Ceratophyllum demersum$d$), 'species/hornwort.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Egeria densa$d$, $d$Anacharis$d$, $d$Hydrocharitaceae$d$, $d$Rivers of south-eastern South America$d$, 'BACKGROUND', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'FAST', 'EASY', 30, 100, 15, 28,
  6.5, 8.0, $d$Cuttings$d$,
  $d$Anacharis, Egeria densa, comes from rivers of south-eastern South America. It has dense whorls of small, bright-green leaves on long, brittle stems and grows quickly in cool to warm water.

It is one of the classic plants for goldfish tanks and a strong nitrate-remover for new aquariums. It has become an invasive weed in many countries, so never dispose of it in a drain, pond or river.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not needed. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Goldfish nibble it, but it grows fast enough to keep up; livebearers and their fry shelter in it.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-02', 'anacharis', $d$Anacharis / Egeria (Bunch of 6)$d$, $d$Fast, hardy, bright-green stems. A classic goldfish plant.$d$, 12000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Egeria densa$d$), 'species/anacharis.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Cabomba caroliniana$d$, $d$Green Cabomba$d$, $d$Cabombaceae$d$, $d$Lakes and slow rivers of the Americas$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'FAST', 'MODERATE', 30, 80, 20, 28,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Green Cabomba, or fanwort, has fine, fan-shaped, finely divided leaves arranged in pairs along long stems, giving a soft, feathery background in bright green. It comes from lakes and slow rivers of the Americas.

It is beautiful but more demanding than it looks: in low light the stems grow thin and shed their lower leaves. It is invasive in many countries -- never release it into a waterway.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Livebearer fry and shrimp shelter in its fine leaves.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-03', 'cabomba', $d$Green Cabomba (Bunch of 6)$d$, $d$Feathery, fan-shaped leaves in bright green. Needs good light.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Cabomba caroliniana$d$), 'species/cabomba.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Cabomba furcata$d$, $d$Red Cabomba$d$, $d$Cabombaceae$d$, $d$Rivers of Central and South America$d$, 'BACKGROUND', 'HIGH',
  70, 120, 'REQUIRED', 'FAST', 'DEMANDING', 30, 80, 22, 28,
  6.0, 7.0, $d$Cuttings$d$,
  $d$Red Cabomba, Cabomba furcata (sold as C. piauhyensis or 'pulcherrima'), has red to purple, finely divided fan leaves, the stem tips glowing deep magenta under strong light. It comes from rivers of Central and South America.

It is one of the most striking red plants and one of the most demanding: without strong light and CO2 it fades and falls apart.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 70-120 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$A showpiece for aquascapes with rasboras, small tetras and shrimp.

This is a plant for a high-light, CO2 tank, and those tanks suit small, peaceful fish that will not uproot or graze: rasboras, small tetras, pencilfish, celestial pearl danios, otocinclus and dwarf shrimp. Keep goldfish, cichlids, silver dollars and any digger away from it. Amano shrimp are the best algae control in a tank run this hard.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-04', 'purple-cabomba', $d$Red Cabomba (Bunch of 6)$d$, $d$Deep red-purple feathery stems. A showpiece for high-light tanks.$d$, 25000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Cabomba furcata$d$), 'species/purple-cabomba.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Bacopa caroliniana$d$, $d$Lemon Bacopa$d$, $d$Plantaginaceae$d$, $d$Marshes and ditches of the south-eastern United States$d$, 'BACKGROUND', 'MEDIUM',
  30, 70, 'BENEFICIAL', 'SLOW', 'EASY', 20, 40, 20, 30,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Lemon Bacopa grows straight, upright stems lined with pairs of thick, fleshy, oval leaves. Crush a leaf and it smells of lemon, which gives it its common name. In medium light the leaves are bright green; in strong light the tips turn copper-bronze.

It is slower than most stem plants, which means less trimming and a group that stays tidy for weeks. It also tolerates warm water better than many stems, a real advantage in Indian summers.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Its thick leaves are tough enough for most community tanks: tetras, barbs, gouramis, livebearers, rams and Corydoras. Shrimp graze the biofilm on the stems.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-05', 'bacopa-caroliniana', $d$Bacopa Caroliniana (Bunch of 6)$d$, $d$Upright stems of thick, round leaves that smell of lemon when crushed.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Bacopa caroliniana$d$), 'species/bacopa-caroliniana.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Bacopa monnieri$d$, $d$Moneywort (Brahmi)$d$, $d$Plantaginaceae$d$, $d$Wetlands throughout the tropics, including all of India$d$, 'MIDGROUND', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'MODERATE', 'EASY', 10, 30, 18, 32,
  6.0, 8.0, $d$Cuttings$d$,
  $d$Moneywort is Bacopa monnieri -- the same Brahmi used in Ayurveda, growing wild in wet ground all over India. In the aquarium it forms upright or creeping stems of small, round, succulent leaves, with tiny white or pale-violet flowers when it grows out of the water.

It is one of the hardiest stem plants in the hobby and handles heat, hard water and irregular feeding better than almost any of them. For an Indian beginner it is close to ideal.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not needed. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Suits livebearers, danios, barbs, gouramis and Indian natives such as rasboras and pearlspots in brackish-leaning tanks. Its tough leaves survive fish that eat softer plants.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-06', 'moneywort', $d$Moneywort / Brahmi (Bunch of 6)$d$, $d$India's own Brahmi: small, succulent leaves on creeping stems. Very hardy.$d$, 12000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Bacopa monnieri$d$), 'species/moneywort.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Hygrophila angustifolia$d$, $d$Willow Hygrophila$d$, $d$Acanthaceae$d$, $d$Wetlands of tropical Asia and northern Australia, including India$d$, 'BACKGROUND', 'MEDIUM',
  30, 70, 'BENEFICIAL', 'FAST', 'EASY', 30, 60, 20, 30,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Willow Hygrophila has long, narrow, pointed leaves in light green, often with a golden or pink tinge at the tips in strong light, like the leaves of a willow. It grows wild in wetlands across tropical Asia, including India.

It is fast and forgiving: a bunch planted at the back of the tank fills the space within a couple of months.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Good with community fish, livebearers, gouramis and angelfish, which like its vertical cover.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-07', 'hygrophila-angustifolia', $d$Hygrophila Angustifolia (Bunch of 6)$d$, $d$Long, narrow, willow-like leaves. Fast, easy, and fills a background quickly.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Hygrophila angustifolia$d$), 'species/hygrophila-angustifolia.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Hygrophila sp. 'Araguaia'$d$, $d$Hygrophila Araguaia$d$, $d$Acanthaceae$d$, $d$Araguaia river basin, central Brazil$d$, 'MIDGROUND', 'HIGH',
  60, 100, 'BENEFICIAL', 'MODERATE', 'MODERATE', 5, 15, 22, 28,
  6.0, 7.0, $d$Cuttings$d$,
  $d$Hygrophila 'Araguaia' is a small, bushy Hygrophila from central Brazil with narrow leaves that spread sideways rather than climbing. In strong light the leaves turn red-brown to pink.

It is used as a low midground or even a foreground bush in aquascapes.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 60-100 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Its low, spreading habit suits small fish and shrimp in aquascapes.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-08', 'hygrophila-araguaia', $d$Hygrophila 'Araguaia' (Bunch of 6)$d$, $d$Low, bushy Hygrophila with narrow leaves that turn red in strong light.$d$, 25000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Hygrophila sp. 'Araguaia'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Hygrophila corymbosa$d$, $d$Temple Plant$d$, $d$Acanthaceae$d$, $d$Wetlands of India and South-East Asia$d$, 'BACKGROUND', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'FAST', 'EASY', 30, 60, 20, 30,
  6.0, 7.5, $d$Cuttings$d$,
  $d$The temple plant has broad, lance-shaped, bright-green leaves on thick stems. It is native to wetlands in India and South-East Asia, and it is one of the most forgiving fast-growing stems for a new tank.

In strong light the top leaves take on a bronze tinge.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not needed. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Gouramis, angelfish and livebearers use its broad leaves for cover.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-09', 'temple-plant', $d$Temple Plant / Hygrophila Corymbosa (Bunch of 6)$d$, $d$Broad, bright-green leaves on thick stems. A fast, hardy background plant.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Hygrophila corymbosa$d$), 'species/temple-plant.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Hygrophila difformis$d$, $d$Water Wisteria$d$, $d$Acanthaceae$d$, $d$Marshes of India, Bangladesh, Myanmar and Thailand$d$, 'BACKGROUND', 'MEDIUM',
  30, 70, 'NOT_NEEDED', 'FAST', 'EASY', 20, 50, 22, 30,
  6.5, 7.5, $d$Cuttings; plantlets from leaves$d$,
  $d$Water wisteria is native to the marshes of India and neighbouring countries. Under water it grows deeply lobed, lacy, light-green leaves; out of water the leaves are broad and toothed -- so different that farm-grown plants look like a different species until the new underwater leaves come in.

It is fast, easy and one of the best plants for mopping up nitrate in a new tank.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 30-70 PAR at the substrate (about 20-35 lumens per litre), 7-8 hours a day on a timer. CO2 is not needed. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Suits livebearers, gouramis, barbs, danios and tetras. Fry and shrimp shelter in its lacy leaves.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-10', 'water-wisteria', $d$Water Wisteria (Bunch of 6)$d$, $d$Lacy, fern-like leaves under water, broad leaves above. Very easy.$d$, 13000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Hygrophila difformis$d$), 'species/water-wisteria.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Ludwigia repens$d$, $d$Ludwigia Repens$d$, $d$Onagraceae$d$, $d$Wetlands of North and Central America$d$, 'MIDGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'MODERATE', 'EASY', 20, 40, 20, 30,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Ludwigia repens has pairs of rounded leaves that are olive-green on top and red underneath. In strong light with CO2 the whole plant turns copper-red, making it one of the easiest red plants for a beginner.

It is sometimes sold under its old name, Ludwigia natans.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$A reliable red accent for community tanks with tetras, rasboras and dwarf cichlids.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-11', 'ludwigia-repens', $d$Ludwigia Repens (Bunch of 6)$d$, $d$Round leaves, green on top and red underneath, turning fully red in bright light.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Ludwigia repens$d$), 'species/ludwigia-repens.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Ludwigia arcuata$d$, $d$Needle-Leaf Ludwigia$d$, $d$Onagraceae$d$, $d$Wetlands of the south-eastern United States$d$, 'MIDGROUND', 'HIGH',
  60, 100, 'BENEFICIAL', 'MODERATE', 'MODERATE', 20, 40, 20, 28,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Needle-leaf Ludwigia has thin, needle-shaped leaves along slender stems. In strong light they turn a vivid orange-red that contrasts with green plants around it. It comes from wetlands of the south-eastern United States.

The photograph shows it growing above water and in flower; submerged leaves are narrower and redder.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 60-100 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$A colour accent for aquascapes with small tetras, rasboras and shrimp.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-12', 'ludwigia-arcuata', $d$Needle-Leaf Ludwigia (Bunch of 6)$d$, $d$Fine, needle-like leaves that turn vivid orange-red in strong light.$d$, 22000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Ludwigia arcuata$d$), 'species/ludwigia-arcuata.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Ludwigia glandulosa$d$, $d$Ludwigia Peruensis$d$, $d$Onagraceae$d$, $d$Wetlands of the south-eastern United States$d$, 'MIDGROUND', 'HIGH',
  60, 100, 'BENEFICIAL', 'MODERATE', 'MODERATE', 20, 40, 22, 28,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Ludwigia glandulosa, sold as 'Peruensis', has long, lance-shaped leaves that turn deep red to purple in strong light, on upright stems. It comes from wetlands of the south-eastern United States.

It is one of the darkest red stem plants, but needs strong light and iron to keep that colour.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 60-100 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$A red accent for high-light community tanks.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-13', 'ludwigia-peruensis', $d$Ludwigia Peruensis (Bunch of 6)$d$, $d$Deep red, lance-shaped leaves on upright stems.$d$, 22000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Ludwigia glandulosa$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Myriophyllum heterophyllum$d$, $d$Red Myriophyllum$d$, $d$Haloragaceae$d$, $d$Lakes and ponds of eastern North America$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'FAST', 'MODERATE', 30, 60, 18, 28,
  6.5, 7.5, $d$Cuttings$d$,
  $d$Red Myriophyllum, or two-leaf watermilfoil, comes from lakes and ponds of eastern North America. It has feathery whorls of fine leaves along thick stems, like a soft foxtail, with red-tinged stems and tips in good light.

It grows fast and fills a background with soft texture, and fry hide easily in it.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Livebearers and their fry, and small tetras, use its feathery cover.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-14', 'red-myrio', $d$Red Myriophyllum (Bunch of 6)$d$, $d$Feathery, red-tinged stems like a foxtail. Soft and dense.$d$, 20000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Myriophyllum heterophyllum$d$), 'species/red-myrio.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Myriophyllum pinnatum$d$, $d$Green Myriophyllum$d$, $d$Haloragaceae$d$, $d$Wetlands of eastern North America$d$, 'BACKGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'FAST', 'MODERATE', 30, 60, 18, 28,
  6.5, 7.5, $d$Cuttings$d$,
  $d$Green Myriophyllum, Myriophyllum pinnatum, comes from wetlands of eastern North America. It has bright-green, feathery whorls of fine leaves along its stems, like a soft green foxtail.

It grows quickly and makes a soft, textured background, similar to red Myriophyllum but staying green.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Livebearers and their fry, and small tetras, use its feathery cover.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-15', 'green-myrio', $d$Green Myriophyllum (Bunch of 6)$d$, $d$Bright-green feathery stems for a soft background.$d$, 18000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Myriophyllum pinnatum$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Rotala indica$d$, $d$Rotala Indica$d$, $d$Lythraceae$d$, $d$Paddy fields and wet ground of India and South-East Asia$d$, 'MIDGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'FAST', 'EASY', 15, 40, 20, 30,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Rotala indica grows wild in Indian paddy fields. It has small, rounded leaves on fine stems, green in moderate light and pink to red at the tips in strong light.

Much of what is sold as 'Rotala indica' is actually the closely related Rotala rotundifolia; care is identical.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Suits Indian biotope tanks with rasboras, danios and small barbs, as well as shrimp.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-16', 'rotala-indica', $d$Rotala Indica (Bunch of 6)$d$, $d$Small round leaves that turn pink at the tips in good light. Very easy.$d$, 15000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Rotala indica$d$), 'species/rotala-indica.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Rotala 'Nanjenshan'$d$, $d$Rotala Nanjenshan$d$, $d$Lythraceae$d$, $d$Nanjenshan, southern Taiwan$d$, 'MIDGROUND', 'HIGH',
  60, 100, 'REQUIRED', 'MODERATE', 'DEMANDING', 15, 30, 22, 27,
  6.0, 7.0, $d$Cuttings$d$,
  $d$Rotala 'Nanjenshan' comes from Nanjenshan in southern Taiwan. It has very fine, needle-like leaves on thin stems, forming dense, soft bushes in light green to orange-pink under strong light.

It is an aquascaping plant, prized for its fine texture, and needs strong light and CO2 to grow well.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 60-100 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Suits nano fish such as rasboras and ember tetras, and shrimp.

This is a plant for a high-light, CO2 tank, and those tanks suit small, peaceful fish that will not uproot or graze: rasboras, small tetras, pencilfish, celestial pearl danios, otocinclus and dwarf shrimp. Keep goldfish, cichlids, silver dollars and any digger away from it. Amano shrimp are the best algae control in a tank run this hard.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-17', 'rotala-nanjenshan', $d$Rotala 'Nanjenshan' (Bunch of 6)$d$, $d$Very fine, needle-leaved Rotala for aquascapes.$d$, 25000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Rotala 'Nanjenshan'$d$), NULL;

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Alternanthera reineckii$d$, $d$Alternanthera Reineckii$d$, $d$Amaranthaceae$d$, $d$Wetlands of tropical South America$d$, 'MIDGROUND', 'HIGH',
  50, 100, 'BENEFICIAL', 'MODERATE', 'MODERATE', 15, 40, 22, 28,
  6.0, 7.5, $d$Cuttings$d$,
  $d$Alternanthera reineckii 'Rosaefolia' comes from wetlands of tropical South America. It has lance-shaped leaves that are olive-pink to rose on top and deep wine-red underneath, on upright stems.

It is one of the most reliable red plants for the midground, but only in strong light; in dim tanks it turns brown and drops its lower leaves.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: high, about 50-100 PAR at the substrate (40+ lumens per litre), 7-8 hours a day on a timer. CO2 and an iron supplement are what turn it red rather than green-brown. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$A red focal point for community tanks with tetras, rasboras and dwarf cichlids.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-18', 'alternanthera-reineckii', $d$Alternanthera Reineckii 'Rosaefolia' (Bunch of 6)$d$, $d$Pink-red leaves with wine-red undersides. One of the most reliable red plants.$d$, 22000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Alternanthera reineckii$d$), 'species/alternanthera-reineckii.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Lobelia cardinalis 'Dwarf'$d$, $d$Dwarf Cardinal Plant$d$, $d$Campanulaceae$d$, $d$Cultivated form of a North American marsh plant$d$, 'MIDGROUND', 'MEDIUM',
  40, 80, 'BENEFICIAL', 'SLOW', 'MODERATE', 5, 15, 20, 27,
  6.0, 7.5, $d$Cuttings; side shoots$d$,
  $d$The dwarf cardinal plant is a compact form of Lobelia cardinalis, the North American cardinal flower. Submerged, it grows as small rosettes of round, bright-green leaves with a purple underside, reaching only 5-15 cm.

It is slow and tidy, used as a low midground or foreground bush in aquascapes.$d$,
  $d$Stem plants arrive as cut stems in a bunch or a pot. Take them out of the pot and the rock-wool, strip the leaves off the bottom 3-4 cm of each stem, and push the stems in individually, 2-3 cm apart, about 4-5 cm deep. Planted as a tight bunch, the inner stems rot for want of light.

Light: medium, about 40-80 PAR at the substrate (about 25-40 lumens per litre), 7-8 hours a day on a timer. CO2 is not strictly needed but makes it denser and brighter. Stem plants feed mostly from the water, so dose a complete liquid fertiliser weekly; a root tab under the group helps the thirstier ones.

They grow towards the surface. When a stem reaches the top, cut off the top 10-15 cm and replant the tops -- the cut tops become new plants and the rooted bases branch into two or three shoots, so the group gets bushier each time. Pull out and replace stems that have gone bare at the bottom. In a hot Indian summer, above 30 C, most stem plants grow leggy and pale; more light and more surface agitation help.$d$,
  $d$Suits small community fish and shrimp.

Plant-eaters to avoid: goldfish, silver dollars, tinfoil and Buenos Aires tetras, Malawi mbuna, oscars and most large cichlids, kissing gouramis, and crayfish all eat or shred soft-leaved plants. Snail damage is rare; holes in leaves are more often a potassium shortage. Otocinclus, Amano shrimp and Siamese algae eaters keep the leaves clean, and its fast growth helps starve algae.$d$);

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, plant_profile_id, image_key)
SELECT 'PLT-STM-19', 'dwarf-cardinal-plant', $d$Dwarf Cardinal Plant (Pot)$d$, $d$Compact rosettes of round, bright-green leaves.$d$, 20000, 'INR', FALSE,
       (SELECT id FROM category WHERE slug = 'plants-stem'), (SELECT id FROM plant_profile WHERE scientific_name = $d$Lobelia cardinalis 'Dwarf'$d$), 'species/dwarf-cardinal-plant.jpg';

INSERT INTO plant_profile (scientific_name, common_name, family, origin, placement, light_level,
  par_min, par_max, co2, growth_rate, difficulty, height_min_cm, height_max_cm, temp_min_c, temp_max_c,
  ph_min, ph_max, propagation, description, care_guide, tankmates) VALUES (
  $d$Anubias barteri var. nana 'Petite'$d$, $d$Anubias Nana Petite$d$, $d$Araceae$d$, $d$Cultivated miniature of a West African species$d$, 'EPIPHYTE', 'LOW',
  15, 40, 'NOT_NEEDED', 'SLOW', 'EASY', 3, 6, 22, 30,
  6.0, 8.0, $d$Rhizome division$d$,
  $d$Anubias nana 'Petite' (also sold as 'Bonsai') is a miniature cultivar of Anubias nana, with leaves only 1-2 cm long on a rhizome that creeps slowly over wood and stone. A mature clump stays under 6 cm tall.

It is the Anubias for nano tanks, aquascape hardscape and shrimp tanks, and it is just as tough as its full-sized relatives.$d$,
  $d$Do not bury the rhizome -- the thick horizontal stem the leaves grow from. Buried, it rots. Tie it to driftwood or stone with cotton thread or fishing line, glue it on with a drop of gel superglue, or wedge it into a crevice; the roots grip within a few weeks. It can also sit on the substrate with only its roots pushed in.

It is a low-light plant: 15-40 PAR at the plant (about 10-20 lumens per litre) is plenty, 6-8 hours a day. In strong light its slow-growing leaves collect green spot algae, so in a bright tank put it in the shade of taller plants or wood. It does not need CO2. Feed a liquid fertiliser -- it takes its food from the water, not the substrate.

It grows one leaf at a time, slowly, and tolerates heat, hard water and the neglect of a busy week better than almost anything else in this section. That makes it the plant for Indian tanks that reach 30 C in summer.$d$,
  $d$Shrimp graze its tiny leaves constantly, and it is small enough to tuck into the gaps of rockwork in nano tanks with rasboras and other small fish.

Why it survives rough company: its leaves are thick, leathery and bitter, so most plant-eating fish leave it alone. That makes it one of the few plants that can go into a Malawi, Tanganyika or large American cichlid tank, with goldfish, or with silver dollars. Slow-growing leaves do collect algae; Amano shrimp, nerite snails and otocinclus keep them clean without harming the plant.$d$);

UPDATE product SET plant_profile_id = (SELECT id FROM plant_profile WHERE scientific_name = $d$Anubias barteri var. nana 'Petite'$d$) WHERE slug = 'anubias-nana-petite';
