-- Gobies & Gudgeons: a new section under `freshwater`, five products and five
-- species profiles (1 October 2026).
--
-- Why. The owner asked to "add freshwater goby to the catalog", naming the
-- bumblebee goby and linking liveaquaria.com's page for it. That page and the
-- two photos the owner attached were used only as a visual and factual
-- reference: the photos have no licence (species/README.md), and the
-- retailer's facts were cross-checked rather than copied (agent_learningz.md,
-- 2026-09-26). Facts here are from each species' Wikipedia article, read on
-- 1 October 2026.
--
-- THE ONE THING TO KNOW: two of these are not really freshwater fish. The
-- bumblebee goby (Brachygobius doriae) lives in fresh and brackish water and
-- does best with a little salt; the knight goby lives mostly in fresh water
-- but in estuaries, and benefits from salt. species_profile has no salinity
-- field, so the advisor cannot see this. The care notes and the section
-- description say it in words instead, which is a gap, recorded as one in
-- docs/context_summary.md, not a fix.
--
-- WILD STATUS, stated first in each summary: the peacock gudgeon is IUCN
-- Vulnerable, and Zhou's scarlet goby has an endangered type-locality
-- population (collected for the trade), so both are sold captive-bred only.
-- The Philippine neon goby is amphidromous (its larvae go to sea) and nobody
-- breeds it commercially, so it is sold as wild-caught and says so.
--
-- INDIAN NATIVE: the knight goby, from India's estuaries and Sri Lanka.
--
-- The peacock gudgeon is a sleeper goby (Eleotridae), not a true goby; the
-- section is named "Gobies & Gudgeons" so that is not a mislabel.
--
-- PRICES ARE ESTIMATES, set by Claude, not reviewed by the owner.
-- image_key is NULL, set by a later migration with the photographs.

-- ============================================================ section ==

INSERT INTO category (slug, name, description, teaser, sort_order, parent_id, status)
SELECT $d$gobies$d$, $d$Gobies & Gudgeons$d$,
       $d$Small bottom-dwellers with big personalities: true gobies, which sit propped on their fused pelvic fins, and sleeper gobies (gudgeons), which hover just above the floor. Most claim a stone or a cave and defend it. Several prefer hard water with a little salt, which the tank checker cannot see; each care note says so.$d$,
       $d$Bumblebee, peacock gudgeon, neon goby.$d$, 62, c.id, $d$ACTIVE$d$
  FROM category c WHERE c.slug = $d$freshwater$d$;

-- ===================================================== species profiles ==

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, animal_group, care_notes, description) VALUES
($d$Brachygobius doriae$d$, $d$Bumblebee Goby$d$, 4.2, 40, 6, 24, 28, 7.5, 8.5, 10, 25, 'TERRITORIAL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$A brackish-water fish that the trade sells as a freshwater one. It lives in fresh and brackish water in the wild, and it does best in hard, alkaline water with a little marine salt added (about a specific gravity of 1.003 to 1.005). In soft freshwater it slowly fades. The shop's tank checker has no salinity field, so it cannot warn about this; ask in the shop. Keep six or more, so the squabbling over caves is spread out, and give each fish a shell or a stone to claim. It eats live and frozen food only (bloodworm, brine shrimp, daphnia) and ignores flake. It will eat shrimplets.$d$,
 $d$The bumblebee goby is a fish you watch rather than glance at. At four centimetres, banded in black and yellow like the insect it is named for, it spends its day perched on a stone or a shell, propped up on its pelvic fins, and darts out to claim a few centimetres of ground from the next goby along.

It comes from the mangroves, estuaries and coastal swamps of South-East Asia, from Thailand and Vietnam down to Borneo and Sumatra, where the water moves between fresh and salty with the tide. That is why it does best in a hard, slightly salty tank of its own, or with other fish that like hard, slightly salty water, such as mollies and Indian glassfish. A group of six or more in a small, rocky tank, fed on live and frozen food, colours up into the bright yellow bands in the photograph, and the males guard eggs in a cave.$d$),
($d$Tateurndina ocellicauda$d$, $d$Peacock Gudgeon$d$, 7.5, 60, 2, 23, 28, 6.5, 7.8, 5, 15, 'PEACEFUL', 'BEGINNER', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred only: IUCN Vulnerable in the wild, and every one sold here is bred in a tank. Peaceful with other fish; males squabble with each other, so keep one male with two females, or several of each in a tank big enough for each male to own a cave. A planted tank with dim light, caves and a few lengths of pipe on the floor brings it out into the open. It eats frozen and live food readily and learns to take small pellets. It will eat shrimplets, though adult cherry shrimp are usually left alone.$d$,
 $d$The peacock gudgeon is one of the most colourful small fish in fresh water, and one of the easiest to keep. Males are pastel blue-violet with red and yellow spots and stripes, a gold edge to every fin and a black eye-spot at the base of the tail, which is the "peacock" in the name. A male in breeding condition grows a bump on his forehead and turns brighter still. Females are smaller, with a yellow belly that swells with eggs.

It is a sleeper goby rather than a true goby, from the rivers and ponds of eastern Papua New Guinea, where it hovers in small groups just above the bottom instead of sitting on it. In the aquarium a pair spawns in a cave or a pipe, and the male guards and fans the eggs alone for over a week. It is a good fish for a quiet planted community tank with small tetras and rasboras.$d$),
($d$Stiphodon atropurpureus$d$, $d$Philippine Neon Goby$d$, 5.0, 60, 3, 22, 26, 6.8, 8.0, 5, 15, 'PEACEFUL', 'ADVANCED', 'HERBIVORE', TRUE, 'FISH',
 $d$Wild-caught: there is no commercial breeding of this goby anywhere, so every fish is taken from a stream. It needs a mature tank, not a new one: clean, cool, fast-flowing, well-oxygenated water, smooth stones in good light, and the film of algae and biofilm that grows on them, which is its food. A new tank with no algae starves it. Add a strong powerhead and a tight lid; it climbs glass with the sucker formed by its pelvic fins. Safe with shrimp, which share its stones without trouble.$d$,
 $d$Males of the Philippine neon goby are some of the most electric fish sold for fresh water: a velvet black body with a stripe of iridescent blue along the back that seems to switch on and off as the fish turns. Females are paler, striped in brown and cream.

It lives in clear, rocky mountain streams from the Philippines to southern China, Japan, Vietnam and Indonesia, grazing algae from stones with a mouth slung underneath like a pleco's. Its life cycle is why it cannot be bred: the adults spawn in fresh water, the larvae drift out to sea, and the young climb back up the rivers using their pelvic sucker, even scaling waterfalls. In the aquarium it belongs in a stream tank with strong flow, bright light on bare stones, and peaceful company: hillstream loaches, small rasboras and shrimp.$d$),
($d$Stigmatogobius sadanundio$d$, $d$Knight Goby$d$, 9.0, 80, 1, 20, 26, 7.2, 8.5, 10, 25, 'TERRITORIAL', 'INTERMEDIATE', 'CARNIVORE', TRUE, 'FISH',
 $d$An Indian native. It lives mostly in fresh water in estuaries and tidal rivers, sometimes in brackish water. It does best in hard, alkaline water, and a little salt (one or two teaspoons per ten litres) helps it. The tank checker has no salinity field, so ask in the shop before mixing it with soft-water fish. Keep one per tank, or one pair in a large tank: it is fiercely territorial with its own kind. Give it rocks, caves and boundaries to defend. It eats anything that fits in its mouth, shrimp included.$d$,
 $d$The knight goby is a stocky, big-headed goby from the coasts of India and Sri Lanka, the Andaman Islands and on into South-East Asia. Its pale, almost silvery body is scattered with black spots, and the male's tall first dorsal fin, black-spotted with a yellow or white edge, is raised like a banner whenever another fish comes near.

It is a fish of character. A knight goby picks a stone or a cave and defends it against everything, then sits at the entrance watching the room. In a tank with hard water, a little salt, plenty of rock and robust tankmates such as mollies and swordtails, it is hardy and long-lived. A pair spawns in a cave, and the male guards the eggs, which can number in the hundreds. It is a better centrepiece for a small rocky tank than most cichlids its size.$d$),
($d$Rhinogobius zhoui$d$, $d$Zhou's Scarlet Goby$d$, 4.0, 40, 1, 18, 24, 6.8, 7.8, 4, 12, 'TERRITORIAL', 'ADVANCED', 'CARNIVORE', TRUE, 'FISH',
 $d$Captive-bred only. The wild population at the stream where the species was found is now endangered, partly from collecting for the aquarium trade, so the shop sells only tank-bred fish. A cool-water goby: it wants 18 to 24 °C, so it does not belong in a warm tropical tank. Clean, well-oxygenated, flowing water and stones to nest under. Males fight; keep one male, or one male with females in a long tank. It eats live and frozen food and will eat shrimp small enough to catch.$d$,
 $d$Zhou's scarlet goby is a tiny, fierce jewel from the mountain streams of Guangdong and Guangxi in southern China. A male in breeding colour is brick-red to scarlet from the gills back, with a blue-edged dorsal fin and red cheeks, and he displays it at every other male in reach with his fins spread wide. Females are smaller and plainer.

It belongs to Rhinogobius, the stream gobies of East Asia, and lives under and between stones in cool, clear, fast water. In the aquarium it wants the same: a cool room or a chiller, a filter that moves the water, and flat stones laid on sand for the male to dig a nest beneath. Kept that way, it breeds readily, and the male guards the eggs under his stone. It is a fish for a dedicated stream tank rather than a warm community tank.$d$);

-- ============================================================ products ==

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id, image_key)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE,
       (SELECT id FROM category WHERE slug = v.category),
       (SELECT id FROM species_profile WHERE scientific_name = v.scientific_name), NULL
  FROM (VALUES
    ($d$FSH-GOB-01$d$, $d$bumblebee-goby$d$, $d$Bumblebee Goby$d$,
     $d$Usually wild-caught. Black and yellow, 4 cm, and full of character. Prefers hard water with a little salt: read the care notes first.$d$,
     15000, $d$gobies$d$, $d$Brachygobius doriae$d$),
    ($d$FSH-GOB-02$d$, $d$peacock-gudgeon$d$, $d$Peacock Gudgeon$d$,
     $d$Captive-bred only: Vulnerable in the wild. Pastel blue with red and gold spots. Peaceful and easy in a planted tank.$d$,
     25000, $d$gobies$d$, $d$Tateurndina ocellicauda$d$),
    ($d$FSH-GOB-03$d$, $d$philippine-neon-goby$d$, $d$Philippine Neon Goby$d$,
     $d$Wild-caught: no farm breeds it. Velvet black with an electric blue stripe. Needs a mature stream tank with algae to graze.$d$,
     45000, $d$gobies$d$, $d$Stiphodon atropurpureus$d$),
    ($d$FSH-GOB-04$d$, $d$knight-goby$d$, $d$Knight Goby$d$,
     $d$Usually wild-caught, in India. A native goby with a banner-like dorsal fin. One per tank, hard water, and no small shrimp.$d$,
     30000, $d$gobies$d$, $d$Stigmatogobius sadanundio$d$),
    ($d$FSH-GOB-05$d$, $d$zhous-scarlet-goby$d$, $d$Zhou's Scarlet Goby$d$,
     $d$Captive-bred only. A scarlet stream goby from southern China. Cool water (18-24 °C) and a stream tank.$d$,
     60000, $d$gobies$d$, $d$Rhinogobius zhoui$d$)
  ) AS v(sku, slug, name, summary, price_minor, category, scientific_name);
