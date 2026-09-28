-- Bettas, wild bettas and gouramis: three sections under `anabantoids`, 17
-- products and 12 species profiles.
--
-- Why. The shop owner (28 September 2026) said the betta section "looks very
-- lonely" and made bettas, gouramis, shrimp and invertebrates the business's
-- lead departments. `anabantoids` held nine products in one flat leaf; it is a
-- branch now, like `cichlids`: Bettas, Wild Bettas, Gouramis & Paradise Fish.
-- The nine existing products move into those sections; none are renamed.
--
-- THIS OVERRIDES V17 FOR BETTAS, ON PURPOSE. V17 folded morph-by-morph listings
-- into one product per species ("25 bettas" became one). The owner's request is
-- the opposite for this department, and the goldfish exception V17 itself
-- carved out is the precedent: a crowntail and a plakat are different
-- purchases, with different fin care and different prices. All six forms point
-- at the ONE Betta splendens profile, exactly as V7's Neocaridina colours and
-- V13's arowana morphs share theirs. The dwarf gourami keeps its single listing:
-- its summary already offers flame, powder blue and neon.
--
-- CONSERVATION STATUS, checked against each species' Wikipedia taxobox on
-- 28 September 2026 rather than written from memory: Betta albimarginata and
-- B. channoides are IUCN Endangered, B. coccina Vulnerable, B. smaragdina Data
-- Deficient, B. imbellis Least Concern. B. mahachaiensis had no status there,
-- so its listing claims none. Every wild betta here is captive-bred, and the
-- threatened ones say so first, the same rule V17 set for Indian natives.
--
-- INDIAN NATIVE: the banded gourami, Trichogaster fasciata, from the Ganga and
-- Brahmaputra plains, alongside V17's dwarf and honey gouramis.
--
-- A MONSTER FISH, stated as one: the giant gourami reaches 60 cm, and its
-- summary opens with the tank it needs rather than the size it is sold at.
--
-- Care figures are the commonly published ranges for each species. The
-- summaries, care notes and descriptions are written for this shop; each text
-- field was measured against a word floor before this file was generated
-- (agent_learningz.md, 2026-09-26).
--
-- PRICES ARE ESTIMATES, set by Claude, not reviewed by the owner.
--
-- image_key is NULL for every new row, set by a later migration in the same
-- change as the photographs. No inventory rows: catalogue-only until a tank
-- is assigned, as with V13 and V17.


-- ============================================================ sections ==

UPDATE category SET description = $d$Labyrinth fish: bettas, wild bettas, gouramis and paradise fish. All breathe air from the surface, so the tank needs a lid and warm, still air above the water.$d$,
       teaser = $d$Bettas, wild bettas and gouramis.$d$
 WHERE slug = 'anabantoids';

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT v.slug, v.name, v.description, v.teaser, v.sort_order, c.id, $d$ACTIVE$d$
  FROM category c, (VALUES
    ($d$bettas$d$, $d$Bettas$d$, $d$Siamese fighting fish in their bred forms: halfmoon, crowntail, plakat, double tail and veiltail. One male per tank, warm still air above the water, and no fin-nippers.$d$, $d$Halfmoon, crowntail, plakat, veiltail.$d$, 10),
    ($d$bettas-wild$d$, $d$Wild Bettas$d$, $d$The bettas that were never bred for fins: small bubble-nesters and pair-forming mouthbrooders from the peat swamps and forest streams of South-East Asia. Several are endangered in the wild, so every one sold here is captive-bred.$d$, $d$Imbellis, coccina, mouthbrooders.$d$, 20),
    ($d$gouramis$d$, $d$Gouramis & Paradise Fish$d$, $d$Labyrinth fish that breathe air from the surface, from the Indian dwarf and banded gouramis to the giant gourami. Most are peaceful; the males of most species are not peaceful with each other.$d$, $d$Dwarf, honey, pearl, banded, giant.$d$, 30)
  ) AS v(slug, name, description, teaser, sort_order)
 WHERE c.slug = $d$anabantoids$d$;

UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'bettas') WHERE sku = 'FSH-BET-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-01';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-02';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-03';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-04';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-05';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-06';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-07';
UPDATE product SET category_id = (SELECT id FROM category WHERE slug = 'gouramis') WHERE sku = 'FSH-GOU-08';

-- ===================================================== species profiles ==

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, animal_group, care_notes, description) VALUES
($d$Betta imbellis$d$, $d$Peaceful Betta$d$, 5.5, 40, 1, 24, 28, 6.0, 7.5, 2, 12, 'TERRITORIAL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred. "Peaceful" is relative: males still spar with each other, but they display and back off rather than fight to the death the way a splendens does. One male per tank, or a male and female in 40 L or more with plenty of plants to break the line of sight. A tight lid is essential; wild bettas jump, and they breathe air from the surface, so the air above the water must be warm and humid.$d$,
 $d$The peaceful betta is a wild bubble-nesting fighter from the peat swamps and slow, vegetated ditches of the Malay Peninsula, southern Thailand and Sumatra. It is a close relative of the Siamese fighting fish, and in the wild the two sometimes meet and hybridise.

A male in breeding colour is dark, almost black, with iridescent blue-green scales on every flank and a red crescent at the edge of the tail. Females are browner and striped. Keep it in soft to moderately hard water with floating plants, leaf litter and a dim light, and it colours up in days. It eats small live and frozen food: daphnia, mosquito larvae, bloodworm. It is the gentlest way into wild bettas and a good first species for anyone who has kept a splendens and wants to see what the wild fish looks like.$d$),
($d$Betta smaragdina$d$, $d$Emerald Betta$d$, 6.5, 40, 1, 24, 28, 6.0, 7.5, 2, 12, 'AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred. IUCN Data Deficient: nobody knows how the wild population is doing, which is the reason to buy only tank-raised fish. Males fight each other like splendens do, so keep one male per tank. It is not a community fish; keep it alone, as a pair, or with small peaceful surface-shy fish in a large tank at your own judgment. Cover the tank.$d$,
 $d$The emerald betta comes from the rice paddies and marshes of north-eastern Thailand, Laos and the Mekong lowlands. It belongs to the splendens group, the same fighting-fish lineage as the Siamese fighter, and was once bred for fighting in its own right in Isan.

Its name comes from the scales: each one carries a metallic green edge, so a male in good condition looks like green chain mail over a dark red-brown body, with long, gently rounded fins. It is hardy and adaptable, comfortable in the same water as a domestic betta, and bubble-nests in the same way. Feed it small meaty food and give it floating plants to hide under. It is a quieter, more natural-looking alternative to the fancy forms.$d$),
($d$Betta mahachaiensis$d$, $d$Mahachai Betta$d$, 6.5, 45, 1, 25, 30, 6.5, 8.0, 5, 15, 'AGGRESSIVE', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred. It comes from brackish nipa-palm swamps, so it does better in harder, slightly alkaline water than most wild bettas. It tolerates a pinch of marine salt, but it does not need it. One male per tank, because it is a splendens-group fighter. Its home range near Bangkok is small and under constant development pressure, which is why the shop sells only tank-bred fish.$d$,
 $d$The Mahachai betta was described as a species only in 2012, from the Samut Sakhon (Mahachai) area on the coast south-west of Bangkok. It lives in brackish swamps among nipa palms, in water that rises and falls with the tide.

Males are dark with rows of bright blue-green scales that look almost like sequins, and fins edged in the same colour. It is a splendens-group fighter and has to be treated as one: one male to a tank, plenty of cover, a lid, and warm, still air above the water. Its tolerance for harder, slightly saltier water makes it one of the easier wild bettas to keep in cities with hard tap water. Feed it live and frozen food.$d$),
($d$Betta albimarginata$d$, $d$Whiteseam Betta$d$, 4.5, 40, 2, 22, 27, 6.0, 7.5, 2, 10, 'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred only: IUCN Endangered in the wild. Keep it as a pair, in a tank of its own or with the tiniest, calmest companions. A mouthbrooder: the male carries the eggs and fry in his mouth for about two weeks and eats nothing while he does. Soft, clean, slightly cool water; plenty of leaf litter and cover. It is shy at first, so give it time before judging the colour.$d$,
 $d$The whiteseam betta is a tiny mouthbrooding betta from a handful of forest streams in North and East Kalimantan, on Borneo. It is one of the smallest bettas at around four and a half centimetres, and one of the most striking.

Males are a warm red-brown with black-banded fins, and each fin is edged in a clean white line, the white seam that gives the fish its name. Unlike the bubble-nesting fighters, pairs are devoted, and the male broods the eggs in his mouth. It is IUCN Endangered, a consequence of the logging and plantation clearing of its streams, which is exactly why a tank-bred pair is worth keeping well. Give it a small, dim, planted tank of its own, and feed it tiny live food: daphnia, grindal worms, baby brine shrimp.$d$),
($d$Betta channoides$d$, $d$Snakehead Betta$d$, 5.5, 40, 2, 24, 28, 5.0, 7.0, 1, 8, 'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred only: IUCN Endangered in the wild. Keep it as a pair. A paternal mouthbrooder, like the whiteseam betta. It needs soft, acidic, tannin-stained water, which Indian hard tap water is not, so plan on RO or rainwater mixed with tap. Leaf litter, dim light and a tight lid. It is timid and will not compete with busy tankmates at feeding time.$d$,
 $d$The snakehead betta comes from blackwater forest streams in East Kalimantan on Borneo. It gets its name from its head, which is broad and flat like a miniature snakehead's.

The male is a deep brick red with fins edged in white, set off by black submarginal bands. Females are browner. It is a small, gentle, pair-forming mouthbrooder, and a pair tends its young together in a way the fighting bettas never do. Its native streams are being lost to plantations and it is IUCN Endangered, so the shop sells captive-bred fish only. A small planted tank with almond leaves, a darker substrate and soft water brings out a colour no photograph does justice to.$d$),
($d$Betta coccina$d$, $d$Wine Red Betta$d$, 5.5, 30, 2, 24, 28, 5.0, 6.5, 0.5, 5, 'PEACEFUL', 'ADVANCED', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred only: IUCN Vulnerable in the wild. A true blackwater fish that needs very soft, acidic water (pH below 6.5, almost no hardness). RO or rainwater is required, not optional, in most Indian cities. Keep a pair in a small, dimly lit tank with leaf litter and floating plants. It is sensitive to nitrate and sudden water changes: change small amounts, often.$d$,
 $d$The wine red betta is a small bubble-nesting betta from the peat-swamp forests of Sumatra and peninsular Malaysia, where the water is the colour of strong tea and has almost no minerals in it at all.

It is small, slender and a deep wine red, and males carry a single iridescent green spot on each flank. It lives in pairs and is peaceful with other tiny fish, but it is the most demanding betta the shop sells, because its peat swamps are demanding places. Everything that makes it thrive is about water: soft, acid, clean and stable. It is IUCN Vulnerable as its swamps are drained for plantations. For someone who wants a small, genuinely wild fish and will set up a blackwater tank properly, there are few better.$d$),
($d$Trichogaster fasciata$d$, $d$Banded Gourami$d$, 10, 100, 1, 22, 28, 6.0, 7.5, 4, 15, 'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE, 'FISH',
 $d$Tank-bred. An Indian native, from the ponds, canals and flooded fields of the Ganga and Brahmaputra plains. It tolerates the hard, warm water of most Indian cities better than almost any imported gourami. Males squabble with each other, so keep one male, or one male with two or three females, in 100 L or more. Floating plants make it feel secure.$d$,
 $d$The banded gourami is one of India's own aquarium fish, a labyrinth fish of the Gangetic and Brahmaputra floodplains that Bengali fishermen call kholisa. It is the larger cousin of the dwarf and honey gouramis and one of the hardiest gouramis in the trade.

Males are marked with slanting blue and orange-red bands across a silvery-green body, and they turn deeper and brighter when they build a bubble nest; females are paler and rounder. It is peaceful with other fish of similar size, curious rather than shy, and happy in a planted community tank with rasboras, barbs and loaches. It is an omnivore: flake, small pellets and frozen food. Wild-caught fish from Indian markets can carry parasites, so ask for tank-bred and quarantine anyway.$d$),
($d$Trichogaster labiosa$d$, $d$Thick-Lipped Gourami$d$, 8, 60, 1, 22, 28, 6.0, 7.5, 4, 15, 'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE, 'FISH',
 $d$Tank-bred. Hardy and peaceful, and a good gourami for a first planted community tank. Males are mildly territorial with each other, so keep one male per tank unless it is large and well planted. A gold form is also bred and sold under the same name. It breathes surface air, so keep the surface open and the tank covered so that the air above it stays warm.$d$,
 $d$The thick-lipped gourami comes from the slow rivers and ponds of Myanmar. It is a mid-sized labyrinth fish, a little larger than the honey gourami and far more peaceful than the three-spot.

The name describes the male's slightly fleshy lips, but it is the colour that sells it: a honey-orange body crossed with fine blue-grey bars, and an anal fin edged in turquoise that brightens when he displays. It is calm, adaptable to a wide range of water and happy in almost any community of peaceful fish its own size. Feed it a mix of flake, small pellets and frozen food, and give it floating plants and a gentle filter, and it will build bubble nests among them.$d$),
($d$Trichopodus microlepis$d$, $d$Moonlight Gourami$d$, 15, 200, 1, 26, 30, 6.0, 7.0, 2, 15, 'PEACEFUL', 'INTERMEDIATE', 'OMNIVORE', TRUE, 'FISH',
 $d$Tank-bred. A large, calm, surprisingly shy gourami. It startles easily and needs dense planting and quiet tankmates, not boisterous barbs. Keep one male per tank; males spar with each other. It likes warmer water than most gouramis, so it is suited to Indian summers, but it needs a heater in the north in winter. Give it 200 L or more.$d$,
 $d$The moonlight gourami comes from the slow, heavily vegetated waters of Thailand, Cambodia and southern Vietnam. It grows to about fifteen centimetres and is the most elegant of the large gouramis.

Its scales are so small they are almost invisible, which gives the body a smooth, pearly, silver-green sheen that catches the light like moonlight on water. Males develop a red-orange throat and pelvic feelers in breeding condition. For a fish its size it is gentle, even timid, and it looks its best in a large, planted, softly lit tank with other calm, mid-sized fish. It eats flake, pellets and frozen food, and will graze a little on soft plants.$d$),
($d$Trichopodus pectoralis$d$, $d$Snakeskin Gourami$d$, 20, 250, 1, 23, 30, 6.0, 8.0, 2, 20, 'PEACEFUL', 'BEGINNER', 'OMNIVORE', TRUE, 'FISH',
 $d$Tank-bred. Grows to about 20 cm, so buy it for the tank it will need, not the tank you have. It is one of the most peaceful large gouramis, placid and slow, and hardy across a very wide range of water. A good centrepiece for a big community tank of other peaceful, mid-sized fish. A tight lid, as with every labyrinth fish.$d$,
 $d$The snakeskin gourami is native to the Mekong and Chao Phraya basins of Indochina, and has been farmed across South and South-East Asia as a food fish for so long that it is now established in many countries, including parts of India.

It is the largest gourami the shop sells for ordinary tanks, reaching around twenty centimetres, with an olive body crossed by irregular zig-zag bars and a dark horizontal line that together look like a snake's scales. For all that size it is one of the calmest fish in the hobby, slow-moving and uninterested in its tankmates. It is extremely hardy, feeds on almost anything, and lives for many years. Give it room and it is an easy, long-lived showpiece.$d$),
($d$Trichopsis vittata$d$, $d$Croaking Gourami$d$, 7, 40, 1, 22, 28, 6.0, 7.5, 2, 15, 'PEACEFUL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$Tank-bred. The fish that talks: males croak audibly during displays, and you can hear it from across a quiet room. Keep a small group, or at least a pair, in a planted tank with calm, small tankmates. It is too slow and shy for busy community tanks. It prefers small live and frozen food to flake, and a covered tank with warm, humid air.$d$,
 $d$The croaking gourami lives in the ditches, paddies and slow, weedy waters of South-East Asia, from Thailand and Cambodia to Sumatra, Java and Borneo. It is a small, slender labyrinth fish about seven centimetres long.

Its body is olive to purple-brown with dark horizontal stripes, and its eyes are ringed in brilliant blue; the fins are finely spotted with red. What makes it special is sound: both sexes, but mostly males, produce a clearly audible croak by snapping specialised pectoral-fin tendons, a way of talking to each other while displaying. It is peaceful, a little shy, and at its best in a quiet, well-planted tank of its own kind or with other small, gentle fish.$d$),
($d$Osphronemus goramy$d$, $d$Giant Gourami$d$, 60, 1500, 1, 20, 30, 6.5, 8.0, 5, 20, 'SEMI_AGGRESSIVE', 'INTERMEDIATE', 'OMNIVORE', FALSE, 'FISH',
 $d$Tank-bred juveniles. It grows to 60 cm or more and lives for decades. A 1,500 L tank or a pond is the honest minimum for an adult, and if you cannot provide that, do not buy it. It eats plants and anything small enough to swallow. Tame and personable as an adult, it learns its keeper's face. A strong lid; a big gourami can jump.$d$,
 $d$The giant gourami is native to the swamps and rivers of South-East Asia and has been farmed as a food fish so widely that it now lives across tropical Asia, including India. It is the largest labyrinth fish in the world, reaching sixty to seventy centimetres and several kilograms.

Juveniles are pointed-faced, silver and banded, and look nothing like the adult: a massive, deep-bodied fish with a heavy jaw and, in old males, a domed forehead. In a big enough tank or an indoor pond it is one of the most personable fish in the hobby, often hand-feeding and following its keeper around the glass. It is a monster fish, sold at a size that fits in your palm, so the tank comes first. Feed pellets, vegetables and greens.$d$);

-- ============================================================= products ==

INSERT INTO product
 (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category        WHERE slug            = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name),
       NULL
  FROM (VALUES
    ($d$FSH-BET-02$d$, $d$betta-male-crowntail$d$, $d$Betta, Male Crowntail$d$,
     $d$Tank-bred. Spiked, reduced webbing gives the fins a crown of rays. One male per tank; no fin-nippers.$d$,
     30000, $d$bettas$d$, $d$Betta splendens$d$),
    ($d$FSH-BET-03$d$, $d$betta-male-plakat$d$, $d$Betta, Male Plakat$d$,
     $d$Tank-bred. Short-finned and athletic: the closest form to the wild fish. Swims more, tears less. One male per tank.$d$,
     40000, $d$bettas$d$, $d$Betta splendens$d$),
    ($d$FSH-BET-04$d$, $d$betta-male-double-tail$d$, $d$Betta, Male Double Tail$d$,
     $d$Tank-bred. A split caudal fin and a broad dorsal. The heaviest finnage: needs gentle flow and no fin-nippers.$d$,
     50000, $d$bettas$d$, $d$Betta splendens$d$),
    ($d$FSH-BET-05$d$, $d$betta-male-veiltail$d$, $d$Betta, Male Veiltail$d$,
     $d$Tank-bred. The classic long, drooping tail, and the easiest betta to start with. One male per tank.$d$,
     15000, $d$bettas$d$, $d$Betta splendens$d$),
    ($d$FSH-BET-06$d$, $d$betta-female$d$, $d$Betta, Female$d$,
     $d$Tank-bred. Shorter fins, bright colour, and every bit a fighter. Keep one per tank; sororities are an advanced gamble.$d$,
     15000, $d$bettas$d$, $d$Betta splendens$d$),
    ($d$FSH-WBT-01$d$, $d$peaceful-betta$d$, $d$Peaceful Betta (Betta imbellis)$d$,
     $d$Captive-bred wild betta. Dark blue-green with a red-edged tail. The gentlest way into wild bettas.$d$,
     60000, $d$bettas-wild$d$, $d$Betta imbellis$d$),
    ($d$FSH-WBT-02$d$, $d$emerald-betta$d$, $d$Emerald Betta (Betta smaragdina)$d$,
     $d$Captive-bred wild fighter. Green-edged scales like chain mail. One male per tank.$d$,
     70000, $d$bettas-wild$d$, $d$Betta smaragdina$d$),
    ($d$FSH-WBT-03$d$, $d$mahachai-betta$d$, $d$Mahachai Betta (Betta mahachaiensis)$d$,
     $d$Captive-bred. A brackish-swamp fighter from near Bangkok, and comfortable in harder water. One male per tank.$d$,
     80000, $d$bettas-wild$d$, $d$Betta mahachaiensis$d$),
    ($d$FSH-WBT-04$d$, $d$whiteseam-betta$d$, $d$Whiteseam Betta (Betta albimarginata)$d$,
     $d$Captive-bred only: Endangered in the wild. A tiny mouthbrooder, sold as a pair, with white-edged fins.$d$,
     90000, $d$bettas-wild$d$, $d$Betta albimarginata$d$),
    ($d$FSH-WBT-05$d$, $d$snakehead-betta$d$, $d$Snakehead Betta (Betta channoides)$d$,
     $d$Captive-bred only: Endangered in the wild. A brick-red, pair-forming mouthbrooder for soft water.$d$,
     90000, $d$bettas-wild$d$, $d$Betta channoides$d$),
    ($d$FSH-WBT-06$d$, $d$wine-red-betta$d$, $d$Wine Red Betta (Betta coccina)$d$,
     $d$Captive-bred only: Vulnerable in the wild. A small blackwater betta: soft, acidic water or nothing.$d$,
     90000, $d$bettas-wild$d$, $d$Betta coccina$d$),
    ($d$FSH-GOU-09$d$, $d$banded-gourami$d$, $d$Banded Gourami (Kholisa)$d$,
     $d$Tank-bred. An Indian native, and hardy in Indian tap water. Blue and orange bands on the male.$d$,
     10000, $d$gouramis$d$, $d$Trichogaster fasciata$d$),
    ($d$FSH-GOU-10$d$, $d$thick-lipped-gourami$d$, $d$Thick-Lipped Gourami$d$,
     $d$Tank-bred. Honey-orange with blue-grey bars. Calm, hardy and at home in a planted community tank.$d$,
     15000, $d$gouramis$d$, $d$Trichogaster labiosa$d$),
    ($d$FSH-GOU-11$d$, $d$moonlight-gourami$d$, $d$Moonlight Gourami$d$,
     $d$Tank-bred. Pearly silver-green and gentle. Grows to 15 cm and needs 200 L and quiet tankmates.$d$,
     20000, $d$gouramis$d$, $d$Trichopodus microlepis$d$),
    ($d$FSH-GOU-12$d$, $d$snakeskin-gourami$d$, $d$Snakeskin Gourami$d$,
     $d$Tank-bred. A placid 20 cm centrepiece with snakeskin markings. Very hardy; buy the tank first.$d$,
     15000, $d$gouramis$d$, $d$Trichopodus pectoralis$d$),
    ($d$FSH-GOU-13$d$, $d$croaking-gourami$d$, $d$Croaking Gourami$d$,
     $d$Tank-bred. Small, blue-eyed and audible: males croak when they display. Best in a small group.$d$,
     25000, $d$gouramis$d$, $d$Trichopsis vittata$d$),
    ($d$FSH-GOU-14$d$, $d$giant-gourami$d$, $d$Giant Gourami (juvenile)$d$,
     $d$Tank-bred juvenile of a fish that reaches 60 cm and lives for decades. A pond or a 1,500 L tank, or not at all.$d$,
     40000, $d$gouramis$d$, $d$Osphronemus goramy$d$)
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);
