-- Shrimp and invertebrates: three shrimp sections, 16 products, six new care
-- profiles, and a description for every invertebrate in the catalogue.
--
-- Why. The shop owner (28 September 2026) is building the business around
-- shrimp and invertebrates and asked for a deeper, better-written department.
-- Until this file, not one invertebrate had an "About" description (V20 wrote
-- them for fish only) and each care note was a sentence or two. The eight
-- existing profiles are rewritten here with UPDATE, forward, the same way V19
-- corrected V17: nothing already applied is edited.
--
-- `inverts-shrimp` becomes a branch, by the water each shrimp needs, because
-- that is the decision a customer actually has to make: Cherry & Colour Shrimp
-- (Neocaridina, which suit most Indian tap water), Crystal, Bee & Tiger Shrimp
-- (Caridina, which need RO water and a cool room), and Amano, Filter-Feeding &
-- Other Shrimp. The six existing shrimp move into those sections.
--
-- Section descriptions are now multi-paragraph KEEPING GUIDES. The first
-- paragraph stays the page's lede; the storefront renders the rest beneath the
-- listing. That is the shrimp-care deep dive the owner asked for, and it lives
-- in the catalogue beside the animals rather than in storefront code.
--
-- Colour forms share a profile, as V7 established: seven new Neocaridina colours
-- join the four existing ones on the single Neocaridina davidi profile, and the
-- three bee shrimp lines share one Caridina cantonensis profile.
--
-- NAMES CHECKED against Wikipedia on 28 September 2026: bee shrimp are Caridina
-- cantonensis (the bred lines' taxonomy is disputed, and the description says
-- so rather than picking a side); tiger shrimp Caridina mariae; the vampire
-- shrimp Atya gabonensis (West Africa, 15 cm); the Indian whisker shrimp
-- Macrobrachium lamarrei; the horned nerite Clithon corona. Rabbit snails were
-- left out: no source here confirmed which Tylomelania the trade's "orange
-- rabbit snail" is, and a wrong scientific name on a product is worse than no
-- product.
--
-- A KNOWN ADVISOR GAP, stated rather than hidden: the whisker shrimp eats
-- cherry shrimp, and aquatics-advisor's predation rule (adult length, aggressive
-- species only, ratio 2.5) will not catch a 7 cm semi-aggressive shrimp with a
-- 3 cm one. Its care note and summary say so plainly, first.
--
-- Crabs and crayfish are not here: they need a new animal_group and advisor
-- rules, not just rows, and the owner has held them.
--
-- PRICES ARE ESTIMATES, set by Claude, not reviewed by the owner. image_key is
-- NULL for every new row, set in the same change as the photographs.


-- ============================================================ sections ==

UPDATE category SET description = $d$Freshwater shrimp and snails: the clean-up crew of a planted tank, and for many keepers the main event. Every invertebrate here carries a full care profile, like every fish.

Shrimp and snails are not small fish, and they fail in different ways. A fish tells you something is wrong by how it swims. A shrimp tells you by moulting badly or not breeding, weeks after the cause. So the rules are about stability rather than perfection: dechlorinated water, no copper in anything you add, slow acclimatisation, small regular water changes, and a mature tank with biofilm on every surface.

Copper kills invertebrates at levels harmless to fish. Check every medication, plant fertiliser and algae treatment before it goes in a tank with shrimp or snails; many fish medicines contain copper sulphate. Old copper pipes and some tap fittings leach it too.$d$ WHERE slug = 'invertebrates';
UPDATE category SET description = $d$Cherry and colour shrimp for beginners, crystal and bee shrimp for specialists, and filter-feeding shrimp that fish the current. Start with the section that matches your water, not the colour you like best.

Start with the water you have. Most Indian tap and borewell water is moderately hard and alkaline. That suits Neocaridina (cherry and colour shrimp) and Amanos, and it does not suit Caridina bee and tiger shrimp, which need soft, acidic water made from RO and a remineraliser. Choosing the shrimp that fits your water is the difference between a colony and a slow decline.

Three numbers matter more than the rest. GH, general hardness, is the calcium and magnesium a shrimp needs to build each new shell. KH, carbonate hardness, holds the pH steady. TDS, total dissolved solids, is the easiest single number to track with a cheap pen meter, and a sudden change in it is a warning. Test before you buy, and again once a week.

Acclimatise slowly. Float the bag to match temperature, then drip tank water into a container with the shrimp over an hour or more, until the volume has tripled, before moving them across without the bag water. Most shrimp that die in their first week die of a fast move between two waters that were both fine.

A new tank starves shrimp. They live on biofilm, the invisible film of microbes and algae on every surface, which takes weeks to build. Add shrimp to a tank that has run for at least a month, feed sparingly (what they finish in two hours, every other day), and remove what they leave. Leaf litter such as Indian almond leaves adds both food and cover.

Moulting is growth. Every few weeks a shrimp sheds its shell, and the empty shell left on the sand is normal: leave it, they eat it back for the minerals. A shrimp that dies stuck halfway out of a moult, with a white ring round its middle, is telling you the water is changing too much between water changes, or the GH is wrong.

Indian summers are the hazard nobody warns about. Neocaridina manage to 28 °C; Caridina struggle above 25 °C. A clip-on fan across the water surface lowers the temperature by two or three degrees through evaporation, and a room that stays cool matters more than any chiller. Keep an air pump on a battery backup for power cuts in May and June.$d$,
       teaser = $d$Cherry, crystal, Amano, bamboo.$d$ WHERE slug = 'inverts-shrimp';
UPDATE category SET description = $d$Nerites, mystery snails, ramshorns, Malaysian trumpet snails and the assassin snail: algae eaters, substrate turners and the one snail that controls the others.

Snails need hard water for their shells. In soft water a snail's shell thins and pits, and white or eroded tips are the sign. A piece of cuttlebone or crushed coral in the filter adds calcium without changing the tank much.

Choose snails for what they do. Nerites and horned nerites clean glass and hardscape and cannot breed in fresh water. Ramshorns and trumpet snails clean up leftovers and multiply with the food supply. The assassin snail eats other snails, including nerites. And never release any aquarium snail outdoors.$d$ WHERE slug = 'inverts-snails';
INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, $d$ACTIVE$d$
  FROM category c, (VALUES
    ($d$shrimp-neocaridina$d$, $d$Cherry & Colour Shrimp$d$,
     $d$Neocaridina davidi in every colour it is bred in: red cherry, bloody mary, orange sakura, yellow, green jade, blue dream and blue velvet, chocolate, black rose, rili and snowball. The hardy, forgiving shrimp, and the one to start with.

Keep one colour per tank. Every colour here is the same species, and colours interbreed. Mix red and blue and within a few generations the colony returns to the wild brown-green it came from. If you want more than one colour, keep more than one tank.

Buy a group, not a pair. Ten to twenty shrimp gives a colony enough males and females to breed steadily, and a colony that feels safe comes out into the open. They breed without help: a female carries her eggs under her tail for about three weeks, and the young hatch as tiny adults.

Grades are about colour density. A higher grade has more solid, more opaque colour across more of the body, and costs more. Over generations, a colony's grade drifts down unless the palest shrimp are moved to another tank; that selection is how a line is kept.$d$,
     $d$Neocaridina in every colour.$d$, 10),
    ($d$shrimp-caridina$d$, $d$Crystal, Bee & Tiger Shrimp$d$,
     $d$Crystal red and crystal black bee shrimp, Taiwan bee lines such as blue bolt, and tiger shrimp. The specialist shrimp: cool, soft, acidic, stable water, set up for them from the start.

Bee shrimp need water most Indian taps cannot give: pH around 6.0-6.5, GH 4-6, KH 0-1, TDS 120-160, and 20-24 °C. That means RO water remineralised with a GH-only shrimp salt, and an active soil substrate that buffers the pH down for a year or more. Tiger shrimp are a little more forgiving, but they still want soft water.

Temperature is the hard part in India. Above 25 °C they stop breeding and above 28 °C they die, so this section is for a cool room, an air-conditioned room, or a tank with a fan across its surface and a thermometer you actually read.

Keep bee and tiger shrimp in separate tanks if you want to keep either line true, since they can cross, and never mix them with Neocaridina in a breeding tank. Keep their tankmates to the tiniest peaceful fish, or none at all.$d$,
     $d$Crystal red, blue bolt, tiger.$d$, 20),
    ($d$shrimp-other$d$, $d$Amano, Filter-Feeding & Other Shrimp$d$,
     $d$Amano shrimp, the best algae eaters there are; bamboo and vampire shrimp, which fish the current with fans instead of claws; ghost shrimp; and the Indian whisker shrimp, a native river prawn that is also a predator.

Filter feeders need flow and food in the water. Bamboo and vampire shrimp cannot pick food off the bottom. Give them a perch in the filter outflow or a powerhead's stream, and feed fine powdered food into the current near them. One that is picking at the sand instead of fanning is hungry.

Read the notes before mixing. Amanos and filter feeders are safe with everything, but the whisker shrimp hunts small shrimp and fry at night, and large Amanos out-compete small shrimp at feeding time. Every care profile says which tankmates are safe.$d$,
     $d$Amano, bamboo, vampire, whisker.$d$, 30)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = 'inverts-shrimp';

UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-neocaridina') WHERE sku = 'INV-CHE-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-neocaridina') WHERE sku = 'INV-NEO-02';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-neocaridina') WHERE sku = 'INV-NEO-03';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-neocaridina') WHERE sku = 'INV-NEO-04';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-other') WHERE sku = 'INV-AMA-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'shrimp-other') WHERE sku = 'INV-GHO-01';

-- ============================================== existing invertebrates ==

UPDATE species_profile SET care_notes = $d$Tank-bred. The forgiving shrimp: it lives in 18-28 °C, pH 6.5-8.0 and GH 6-12, which covers most Indian tap water once it is dechlorinated. Stability matters more than any number. Acclimatise it slowly (drip over an hour), keep it in a mature tank with biofilm and plants, feed a little every other day, and change 10-20% of the water weekly rather than half at once. Keep one colour per tank: colours interbreed and the colony drifts back to wild brown within a few generations. No copper, ever; check fertilisers and medications. Fish larger than a small rasbora will hunt the young.$d$,
       description = $d$Neocaridina davidi, the cherry shrimp, is a small freshwater shrimp from Taiwan, southern China, Korea and Vietnam. The wild animal is a muddy brown-green. Every colour in the shop, from red cherry to blue dream, yellow goldenback, orange sakura, black rose, green jade, chocolate and the rili and snowball forms, is the same species, bred by selection over twenty years.

It is the shrimp to start with. It is hardy and unfussy about water, breeds readily in a planted tank with no special help, and spends its day grazing biofilm and algae off every leaf and stone. Females carry their eggs under the tail for about three weeks, and the young hatch as tiny copies of the adults. There is no larval stage, which is why a colony grows so reliably. Colour is graded: the deeper and more solid, the higher the grade and the price.$d$
 WHERE scientific_name = 'Neocaridina davidi';

UPDATE species_profile SET care_notes = $d$Tank-bred larvae are rare, so most Amano shrimp are wild-collected. The best algae-eating shrimp there is, especially for hair and thread algae. Keep at least three, in a tank with a tight lid, because they climb. They tolerate a wide range of water (pH 6.5-7.8, 20-28 °C) and are peaceful with everything but will out-compete smaller shrimp at feeding time. Their larvae need salt water, so they will not breed in your aquarium.$d$,
       description = $d$The Amano shrimp comes from the coastal streams of Japan and Taiwan and is named after Takashi Amano, the aquascaper who made it famous by using it to keep his nature aquariums clean. It is a larger, stockier shrimp than a cherry, about five centimetres, translucent grey with a line of dots or dashes along its sides.

Its reputation is earned. A group of Amanos will clear hair algae, thread algae and leftover food from a planted tank faster than any other invertebrate. Its larvae drift down to the sea and grow up in brackish water, so it cannot breed in fresh water and a group never becomes a population. That makes it the most practical clean-up crew for a planted tank, and one of the longest lived: two to three years is normal.$d$
 WHERE scientific_name = 'Caridina multidentata';

UPDATE species_profile SET care_notes = $d$Cheap, hardy and useful as a scavenger. Ghost shrimp is a trade name used for several near-identical glass shrimp, and this care covers all of them: 20-28 °C, pH 7.0-8.0, moderate hardness. Keep a group of five or more with small, peaceful fish. Larger individuals may pick at very small fry or weak shrimp at night. They are often sold as feeders, so choose healthy, active ones.$d$,
       description = $d$Ghost shrimp are almost completely transparent: you can see what they have just eaten travel down the gut. The name is used in the trade for several similar glass shrimp. This profile carries the North American species Palaemonetes paludosus, whose care is typical of the group.

They are busy, bold scavengers that clean up leftover food and detritus from the bottom of a tank, and they are among the cheapest invertebrates a shop sells. That price means they are often treated as feeders, which undersells them: kept properly in a planted tank they are active, interesting and live for a year or more. They do best with small, peaceful fish that cannot swallow them, and they are the easiest way to see how a shrimp eats, moults and moves.$d$
 WHERE scientific_name = 'Palaemonetes paludosus';

UPDATE species_profile SET care_notes = $d$The best algae-eating snail for glass, leaves and rock, and it does not eat healthy plants. Its eggs need brackish water to hatch, so it cannot breed in an aquarium, but it does leave small white egg capsules on hardscape, which some keepers find unsightly. It needs hard water (GH above 6) for a strong shell. It climbs, so use a lid. Never with loaches, puffers or assassin snails.$d$,
       description = $d$Nerite snails live along the coast of East Africa, in the lower reaches of rivers where fresh water meets the sea. In the aquarium they are prized as the most effective algae eaters among snails: they graze film, spot and diatom algae off glass, stone and wood without touching healthy plants.

The zebra nerite's shell carries bold black-and-gold stripes, and each snail's pattern is unique. Because its larvae need brackish water, a nerite cannot overrun a tank the way pond snails can, which makes it the snail most keepers choose deliberately. Its one habit worth knowing is that it lays small, hard white eggs that do not hatch. A single nerite handles a nano tank; one per 20-40 L keeps a larger one clean.$d$
 WHERE scientific_name = 'Neritina natalensis';

UPDATE species_profile SET care_notes = $d$A large, peaceful snail that eats algae, leftover food and soft or dying plants, but usually leaves healthy plants alone. It needs hard water for its shell and a covered tank with a gap above the water line, because it lays its pink egg clutches above the surface. Remove clutches you do not want to hatch. Never release any apple snail into a pond or river: other apple snails are among the world's worst invasive species.$d$,
       description = $d$The mystery snail is a South American apple snail, Pomacea bridgesii, also called the gold inca or spike-topped apple snail. It is one of the largest snails in the hobby, growing to about five centimetres, and it comes in gold, blue, ivory, purple and black shell colours bred from the wild brown form.

It is a gentle, curious animal with a long breathing siphon it raises to the surface for air, and it spends its day gliding over glass and plants eating algae and whatever the fish leave behind. Unlike most snails it has separate sexes, and a pair lays pink egg clutches above the waterline. It is a good choice for a community tank that wants a larger, characterful snail, and it lives for a year or more.$d$
 WHERE scientific_name = 'Pomacea bridgesii';

UPDATE species_profile SET care_notes = $d$Breeds readily and will multiply if food is plentiful, which makes it both a useful clean-up crew and, if overfed, a population. Control numbers by feeding less, not with chemicals: anything that kills snails also kills shrimp. It prefers hard water for its shell. Safe with plants and shrimp; eaten by loaches, puffers and assassin snails.$d$,
       description = $d$The ramshorn snail sold in the hobby is Planorbella duryi, originally from Florida, with a flat, coiled shell like a ram's horn. The red, pink and blue forms are bred colour varieties. The red body colour comes from haemoglobin in its blood, which is unusual among snails.

It is a small, busy snail that eats algae, dead plant matter, biofilm and uneaten food, and it is one of the most useful members of a shrimp tank's clean-up crew. It breeds readily, laying small jelly-like egg clutches on glass and plants, and its population rises and falls with the amount of food in the tank. For many keepers, a few ramshorns are an honest indicator: if their numbers explode, the tank is being overfed.$d$
 WHERE scientific_name = 'Planorbella duryi';

UPDATE species_profile SET care_notes = $d$Burrows through the substrate by day, which turns it over and keeps it from compacting, a real benefit in a planted tank. It breeds by live birth and can build a large population in an overfed tank; feed less to keep numbers down. It tolerates a wide range of water. Never release it into natural waters: it is established outside its native range in many countries.$d$,
       description = $d$The Malaysian trumpet snail has a native range spanning northern Africa and southern Asia and has been carried round the world by the aquarium trade. It has a long, conical, pointed shell, brown with darker flecks, and spends most of the day buried in the substrate, coming out at night to graze.

It is one of the most useful and most misunderstood snails in the hobby. Its burrowing keeps sand and soil loose and stops pockets of stagnant, oxygen-free substrate forming under a planted tank, and it eats detritus and leftover food. It bears live young, so its numbers follow the food supply. A few in a tank are a free, silent substrate service; many are a sign the fish are being fed too much.$d$
 WHERE scientific_name = 'Melanoides tuberculata';

UPDATE species_profile SET care_notes = $d$A snail that eats other snails: it is how most keepers control pest snail numbers without chemicals. It will also eat nerite and mystery snails, and it can take shrimplets, but it leaves adult shrimp and fish alone. It breeds slowly, one egg at a time, so it never overruns a tank. It prefers a sand or fine substrate to burrow in. Needs hard water for its shell.$d$,
       description = $d$The assassin snail comes from the rivers of South-East Asia, and it hunts. With a cone-shaped shell banded in yellow and brown, it buries itself in the sand and waits, then uses a long proboscis to eat other snails from inside their shells.

It is the biological answer to a pond or ramshorn snail population that has got out of hand: a few assassins will bring the numbers down over a few weeks without harming plants or fish. Once the pest snails are gone, they eat leftover food and live on quietly. They breed slowly, laying single eggs that take weeks to hatch, so a tank never ends up with too many. They are not a good choice for a tank of prized nerites or mystery snails.$d$
 WHERE scientific_name = 'Clea helena';

-- ===================================================== species profiles ==

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, animal_group, care_notes, description) VALUES
($d$Caridina cantonensis$d$, $d$Bee Shrimp$d$, 2.5, 30, 10, 20, 24, 5.8, 6.8, 4, 6, 'PEACEFUL', 'ADVANCED', 'OMNIVORE', TRUE, 'SHRIMP',
 $d$Tank-bred. Cool, soft, acidic, stable water, or nothing. Aim for 20-24 °C, pH 6.0-6.5, GH 4-6 and KH 0-1, with a TDS around 120-160. In most Indian cities that means RO water remineralised with a GH-only shrimp salt, an active soil substrate that holds the pH down, and a plan for summer: above 26 °C they stop breeding, and above 28 °C they die. A fan across the surface or a room that stays cool is part of the kit. Never keep them with Neocaridina in the same tank if you mean to breed a line; keep them away from any fish larger than a chili rasbora.$d$,
 $d$Bee shrimp come from the cool, soft hill streams of southern China and Hong Kong, where the wild animal is a small, translucent shrimp banded in brown. Everything in the shop is bred from it: the crystal red, crystal black and the Taiwan bee lines such as blue bolt. They are among the most selectively bred invertebrates in the hobby, and their taxonomy is argued over, so this profile describes the bred bee shrimp as a group.

They are graded by how much white they carry and how solid it is, and a good colony is the product of years of culling. They are sensitive not because they are fragile animals but because they come from very specific water and do not tolerate change. They graze biofilm on every surface, so a mature, established tank feeds them better than any food. Kept right, a colony of twenty becomes two hundred in a year.$d$),
($d$Caridina mariae$d$, $d$Tiger Shrimp$d$, 3, 30, 10, 20, 25, 6.5, 7.5, 4, 10, 'PEACEFUL', 'INTERMEDIATE', 'OMNIVORE', TRUE, 'SHRIMP',
 $d$Tank-bred. Hardier than bee shrimp and softer-water than cherries: pH 6.5-7.5, GH 4-10, 20-25 °C. It needs a cool room or a fan in an Indian summer; it does not tolerate 30 °C. Keep it apart from bee shrimp if you want to keep either line pure, because the two can hybridise. A mature, planted tank with lots of surface for biofilm, and no fish larger than it can hide from.$d$,
 $d$Tiger shrimp are Caridina mariae, from the streams of Guangdong in southern China and Hong Kong. The wild shrimp is translucent with dark vertical stripes, like a tiger, and bred lines have taken it much further.

The orange-eyed blue tiger is the best known of those lines: a deep blue body, fine black stripes and bright orange eyes, one of the most beautiful shrimp there is. Tigers sit between cherry shrimp and bee shrimp in how demanding they are: they need softer water than a cherry, but they forgive more than a crystal red. They are grazers of biofilm and algae, peaceful with everything, and a colony that settles in breeds steadily. The blue colour deepens in a tank with dark substrate and plants.$d$),
($d$Atyopsis moluccensis$d$, $d$Bamboo Shrimp$d$, 8, 60, 1, 23, 28, 6.5, 7.8, 3, 15, 'PEACEFUL', 'INTERMEDIATE', 'OMNIVORE', TRUE, 'SHRIMP',
 $d$Tank-bred where available, often wild-caught. A filter feeder that cannot pick food off the bottom the way other shrimp do, so it needs current. Give it a spot in the filter outflow or a powerhead's stream, and a mature tank with plenty of fine particles in the water. If you see it picking at the substrate instead of fanning, it is starving; target-feed powdered food upstream of it. Completely peaceful, even with the smallest fish. Never keep it with copper-based medication.$d$,
 $d$The bamboo shrimp, also sold as the wood shrimp or flower shrimp, lives in fast streams across South-East Asia, where it clings to rocks and roots in the current and fans the water for food. Instead of claws it has four fans made of fine bristles, and it holds them open in the flow like nets, pulling each one to its mouth in turn.

It grows to about eight centimetres and changes colour with its mood and its moult, from cream to red-brown with a pale stripe down the back. Watching one fish the current is one of the quieter pleasures of a planted tank. It is harmless to every tankmate, including fry and other shrimp. What it needs is flow and food in the water, which is why a new, spotless tank starves it.$d$),
($d$Atya gabonensis$d$, $d$Vampire Shrimp$d$, 15, 100, 1, 23, 28, 6.5, 7.8, 5, 15, 'PEACEFUL', 'INTERMEDIATE', 'OMNIVORE', TRUE, 'SHRIMP',
 $d$Usually wild-caught; there is no reliable captive breeding. A large filter feeder that needs current and a cave or root to shelter under by day. It is shy when new and nocturnal, so you may not see it for weeks. Target-feed powdered or crushed food into the current near it. Peaceful with everything despite the name and size. Keep it in a tank of at least 100 L with stable, mature water, and never with copper.$d$,
 $d$Despite its name, the vampire shrimp is completely harmless. It is a West African filter feeder, found in rivers from Senegal to the Congo, and grows to about fifteen centimetres, making it one of the largest shrimp in the hobby.

Its heavy, armoured legs look fearsome, but it feeds like the bamboo shrimp, with fans instead of claws held open in the current. Its colour ranges from cream to grey to a striking powder blue, and it can change after a moult. It spends the day in a cave or under a root and comes out to fish the current at night, so a quiet, dim tank with good flow suits it best. It is long-lived and one of the most unusual animals a peaceful community tank can hold.$d$),
($d$Macrobrachium lamarrei$d$, $d$Indian Whisker Shrimp$d$, 7, 40, 1, 22, 30, 6.5, 8.0, 5, 20, 'SEMI_AGGRESSIVE', 'BEGINNER', 'CARNIVORE', TRUE, 'SHRIMP',
 $d$Local, cheap and hardy. It handles Indian tap water and summer heat without complaint. But it is a predator: its long first claws catch small shrimp, fry and sleeping small fish at night. Never put it with cherry shrimp, bee shrimp or anything smaller than a tetra. Keep it with medium-sized, active fish, or in its own tank, where a small group is entertaining to watch. It will also eat snails.$d$,
 $d$The Indian whisker shrimp is a South Asian river prawn, Macrobrachium lamarrei, found in the rivers and ponds of India, Nepal and Bangladesh and sold across India under names like whisker shrimp and kuncho river prawn. It is a translucent, glassy shrimp that grows to about seven centimetres, with long antennae and a pair of slender, elongated first claws.

It is one of the cheapest and hardiest invertebrates in any Indian shop, and one of the most misunderstood. It is often sold as a clean-up crew alongside cherry shrimp, and it will eat them. At night it hunts. Kept for what it is, a native predatory shrimp in its own tank or with fish it cannot catch, it is active, bold and fascinating: it scavenges by day and stalks by night.$d$),
($d$Clithon corona$d$, $d$Horned Nerite Snail$d$, 2.5, 20, 1, 22, 28, 7.0, 8.5, 6, 18, 'PEACEFUL', 'BEGINNER', 'HERBIVORE', TRUE, 'SNAIL',
 $d$A small algae-eating nerite that stays small. It lays hard white eggs on wood and rocks, but they will not hatch in fresh water, so it cannot overrun a tank. It needs hard, alkaline water for its shell: in soft water, add a mineral source. It climbs out of the water, so keep the lid on. Never with loaches, puffers or assassin snails.$d$,
 $d$The horned nerite is a small nerite snail from the coasts and river mouths of South-East Asia and the western Pacific, where it lives in brackish and fresh water on the rocks and mangrove roots of tidal rivers. It is about two centimetres long, with a black-and-yellow banded shell crowned by a ring of short spines, the horns that give it its name.

It is one of the best algae eaters in the hobby for its size, grazing green spot and film algae off glass, leaves and hardscape without harming plants. Like other nerites it needs brackish water for its larvae, so it cannot breed in an aquarium and never becomes a pest. It suits the smallest nano tank as well as a big community, and is safe with shrimp.$d$);

-- ============================================================= products ==

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category        WHERE slug            = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name),
       NULL
  FROM (VALUES
    ($d$INV-NEO-05$d$, $d$orange-sakura-shrimp$d$, $d$Orange Sakura Shrimp$d$,
     $d$Tank-bred Neocaridina. Solid, bright orange from head to tail. Hardy, colony-forming. One colour per tank.$d$,
     18000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-06$d$, $d$bloody-mary-shrimp$d$, $d$Bloody Mary Shrimp$d$,
     $d$Tank-bred. The deepest red Neocaridina line, red even through the body. High grade; one colour per tank.$d$,
     30000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-07$d$, $d$black-rose-shrimp$d$, $d$Black Rose Shrimp$d$,
     $d$Tank-bred Neocaridina. Solid glossy black, striking over light sand or green moss. One colour per tank.$d$,
     30000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-08$d$, $d$green-jade-shrimp$d$, $d$Green Jade Shrimp$d$,
     $d$Tank-bred Neocaridina. A translucent jade green that deepens with age and a mature tank. One colour per tank.$d$,
     25000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-09$d$, $d$chocolate-shrimp$d$, $d$Chocolate Shrimp$d$,
     $d$Tank-bred Neocaridina. Deep chocolate brown, a quiet colour that suits a dark aquascape. One colour per tank.$d$,
     20000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-10$d$, $d$red-rili-shrimp$d$, $d$Red Rili Shrimp$d$,
     $d$Tank-bred Neocaridina. Red head and tail with a clear band through the middle. One colour per tank.$d$,
     20000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-NEO-11$d$, $d$snowball-shrimp$d$, $d$Snowball Shrimp$d$,
     $d$Tank-bred Neocaridina. White-bodied, named for the pearl-white eggs the females carry. One colour per tank.$d$,
     20000, $d$shrimp-neocaridina$d$, $d$Neocaridina davidi$d$),
    ($d$INV-BEE-01$d$, $d$crystal-red-shrimp$d$, $d$Crystal Red Shrimp$d$,
     $d$Tank-bred bee shrimp. Red and white bands, graded by the white. Soft, cool water only; a specialist shrimp.$d$,
     35000, $d$shrimp-caridina$d$, $d$Caridina cantonensis$d$),
    ($d$INV-BEE-02$d$, $d$crystal-black-shrimp$d$, $d$Crystal Black Shrimp$d$,
     $d$Tank-bred bee shrimp. Black and white bands. Soft, cool, acidic water, RO and active soil. Advanced.$d$,
     40000, $d$shrimp-caridina$d$, $d$Caridina cantonensis$d$),
    ($d$INV-BEE-03$d$, $d$blue-bolt-shrimp$d$, $d$Blue Bolt Shrimp$d$,
     $d$Tank-bred Taiwan bee. Electric blue over white, the jewel of the bee shrimp lines. Expert water only.$d$,
     120000, $d$shrimp-caridina$d$, $d$Caridina cantonensis$d$),
    ($d$INV-TIG-01$d$, $d$orange-eyed-blue-tiger-shrimp$d$, $d$Orange-Eyed Blue Tiger Shrimp$d$,
     $d$Tank-bred tiger shrimp. Deep blue, black stripes, orange eyes. Softer water than cherries; cool summers.$d$,
     90000, $d$shrimp-caridina$d$, $d$Caridina mariae$d$),
    ($d$INV-FLT-01$d$, $d$bamboo-shrimp$d$, $d$Bamboo Shrimp$d$,
     $d$A fan-handed filter feeder that fishes the current. Needs flow and a mature tank. Peaceful with everything.$d$,
     45000, $d$shrimp-other$d$, $d$Atyopsis moluccensis$d$),
    ($d$INV-FLT-02$d$, $d$vampire-shrimp$d$, $d$Vampire Shrimp$d$,
     $d$A harmless 15 cm West African filter feeder, blue to grey. Needs current, a cave and at least 100 L.$d$,
     100000, $d$shrimp-other$d$, $d$Atya gabonensis$d$),
    ($d$INV-WHS-01$d$, $d$indian-whisker-shrimp$d$, $d$Indian Whisker Shrimp$d$,
     $d$A native South Asian river prawn: hardy, cheap, and a predator. Never with small shrimp or fry.$d$,
     6000, $d$shrimp-other$d$, $d$Macrobrachium lamarrei$d$),
    ($d$INV-NER-02$d$, $d$horned-nerite-snail$d$, $d$Horned Nerite Snail$d$,
     $d$A small, spiny, banded nerite and a tireless algae grazer. Cannot breed in fresh water. Safe with shrimp.$d$,
     12000, $d$inverts-snails$d$, $d$Clithon corona$d$),
    ($d$INV-MYS-02$d$, $d$blue-mystery-snail$d$, $d$Blue Mystery Snail$d$,
     $d$A blue-shelled apple snail: large, gentle and a steady algae and leftovers eater. Never release it outdoors.$d$,
     18000, $d$inverts-snails$d$, $d$Pomacea bridgesii$d$)
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);
