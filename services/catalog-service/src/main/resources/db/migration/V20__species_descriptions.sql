-- "About this fish": a longer description for every fish species profile,
-- 141 of them -- the 44 profiles behind the 47 fish that predate V17 and the
-- 97 V17 added for its 102 products. Shrimp and snail profiles are untouched.
--
-- A new column, not a longer care_notes. care_notes is the shop's short,
-- practical note (group size, India's hard water and summer heat); this is
-- what the animal is: where it comes from, how to tell the sexes apart, how
-- it behaves, how it breeds, what it eats. The product page shows it above
-- the care profile.
--
-- Where the facts came from. The owner asked for descriptions taken from
-- liveaquaria.com's freshwater range. 131 of the 141 species have a listing
-- there; its product pages (read 26 September 2026) were used as a factual
-- reference for origin, appearance, behaviour and breeding. The PROSE IS NOT
-- THEIRS -- V17's rule stands, nothing is copied from that retailer -- and it
-- was not taken on trust: where their copy is wrong it was corrected against
-- the literature, e.g. they place the zebra loach (Botia striata, Western
-- Ghats) in Indonesia and the dwarf chain loach (Thailand) in India, and
-- file the Boeseman's rainbow under Telmatherina. The ten with no listing
-- there were written from general knowledge: bristlenose, saulosi, auratus,
-- johanni, red melon badis, pygmy cory, iridescent shark, redhead vieja,
-- jardini and Asian arowana.
--
-- The numbers were NOT changed. Their stats were compared against ours and
-- several are looser than a responsible shop should print (a 189 L minimum for
-- a 30 cm bala shark, 114 L for a 45 cm black ghost knifefish), so the care
-- figures stay as V7/V13/V17 set them.
--
-- Dollar-quoted, not single-quoted: V19 exists because V17's generator lost
-- every apostrophe. $d$ ... $d$ needs no escaping at all.

ALTER TABLE species_profile ADD COLUMN description TEXT;


UPDATE species_profile SET description = $d$The convict cichlid is a Central American cichlid from Guatemala to Costa Rica. It is grey-white with bold black vertical bars; females have orange scaling on the belly and are smaller, while males are larger with a steeper forehead. Pink and white forms are common.

About 12-15 cm, very hardy and extremely prolific: pairs breed often and defend their fry against much larger fish. Aggressive for its size, especially while breeding. Needs caves, and tankmates that can hold their own. Feed pellets, flake and frozen foods.$d$
 WHERE scientific_name = $n$Amatitlania nigrofasciata$n$;

UPDATE species_profile SET description = $d$The dwarf chain loach comes from the Mae Klong and Chao Phraya basins of Thailand, where it was nearly wiped out by dam building and is now listed as Endangered. Almost all trade fish are captive-bred. It has a gold-cream body with a chain-like black network along the back and grows to only 5-6 cm.

Unlike most loaches it swims in open water as well as on the bottom. It must be kept in a group of six or more, and it eats small snails, making it a useful snail control in smaller tanks. Needs soft sand, caves and current. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Ambastaia sidthimunki$n$;

UPDATE species_profile SET description = $d$The red devil is a large Central American cichlid from the lakes of Nicaragua. Adults are red, orange, yellow or white, often with a large nuchal hump and thick lips. It is frequently confused with the Midas cichlid, Amphilophus citrinellus, and many trade fish are crosses.

Powerful and highly aggressive, reaching 30 cm or more, so it usually has to be kept alone or as a pair in a large tank. It digs and moves rocks, so décor must sit on the tank floor. Pairs are devoted parents. Feed quality large cichlid pellets and meaty foods.$d$
 WHERE scientific_name = $n$Amphilophus labiatus$n$;

UPDATE species_profile SET description = $d$The bristlenose pleco is a small South American suckermouth catfish, and the trade fish are long-established captive-bred Ancistrus -- brown, albino, super red and longfin forms. Adult males grow branching fleshy tentacles on the snout; females have few or none.

It stays around 12-15 cm, which makes it the right pleco for most home aquariums, unlike the common pleco. It needs driftwood to rasp for fibre, caves to shelter in, and a diet built on algae wafers and blanched vegetables with some protein. Males guard eggs and fry in a cave and breed readily. Peaceful, though males squabble over caves.$d$
 WHERE scientific_name = $n$Ancistrus cirrhosus$n$;

UPDATE species_profile SET description = $d$The blue acara is a South American cichlid from Venezuela, Colombia and Trinidad. It is grey-brown with electric blue lines and spots on the face and body. It grows to about 15 cm and is one of the easiest cichlids to breed.

Peaceful for a cichlid and can share a tank with other medium-sized fish, although pairs become territorial when spawning. Pairs lay eggs on a cleaned stone and raise the fry together. It digs, so root plants well. Feed pellets, flake and frozen foods.$d$
 WHERE scientific_name = $n$Andinoacara pulcher$n$;

UPDATE species_profile SET description = $d$The green terror is a South American cichlid from the Pacific coastal rivers of Ecuador and Peru. It has an iridescent blue-green body, blue marks on the face and, in the 'gold saum' form, a gold or orange edge to the tail and dorsal fin. Males develop a large nuchal hump.

Territorial and powerful, growing to around 25-30 cm, so it needs a large tank and tankmates of its own size and temperament. Pairs spawn on flat stones and guard the fry fiercely. Feed quality cichlid pellets and meaty frozen foods.$d$
 WHERE scientific_name = $n$Andinoacara rivulatus$n$;

UPDATE species_profile SET description = $d$Agassiz's dwarf cichlid is from the Amazon basin, where it lives among leaf litter in shallow, soft, acidic water. Males reach about 8 cm, with a lance-shaped tail edged in colour; captive-bred flame red, double red and gold forms are the ones sold. Females are smaller and turn yellow and black when guarding fry.

Kept as one male with two or three females, each with her own cave or coconut shell. Soft, acidic, clean water, leaf litter, plants and subdued light bring out its colours. The female guards the eggs in a cave and leads the fry. Feed small pellets and live or frozen foods such as brine shrimp and bloodworm.$d$
 WHERE scientific_name = $n$Apistogramma agassizii$n$;

UPDATE species_profile SET description = $d$The cockatoo dwarf cichlid is from Peru and Colombia in the upper Amazon. Males have a crest of extended dorsal rays like a cockatoo's, a large mouth and a colourful tail; orange flash, double red and triple red are captive-bred colour forms. Females are smaller and yellow.

One of the hardiest Apistogramma, tolerating harder and more neutral water than most, which makes it a good first dwarf cichlid in India. Keep one male with several females and a cave each. Females guard eggs in the cave and then herd the fry. Feed small pellets, frozen and live foods.$d$
 WHERE scientific_name = $n$Apistogramma cacatuoides$n$;

UPDATE species_profile SET description = $d$The black ghost knifefish comes from the Amazon basin. It has a velvety black body, two white rings on the tail and a long ribbon-like fin along its belly that lets it swim forward and backward. It generates a weak electric field to navigate and hunt in the dark.

Nocturnal and shy, growing to about 45 cm. Needs a large tank with hiding places and dim light, and will eat small fish. Feed live and frozen foods such as bloodworm and brine shrimp.$d$
 WHERE scientific_name = $n$Apteronotus albifrons$n$;

UPDATE species_profile SET description = $d$The oscar is a large South American cichlid from the Amazon basin. Wild fish are olive with orange-ringed spots near the tail; tiger, red, albino, lemon and longfin forms are captive-bred. It grows to 30-35 cm and is known for recognising its owner and begging at the glass.

A heavy eater and heavy polluter, it needs a large, strongly filtered tank and frequent water changes. It rearranges decorations and uproots plants. It will eat any fish small enough to swallow. Feed quality large cichlid pellets with krill, shrimp and earthworms, and do not feed live feeder fish, which carry disease.$d$
 WHERE scientific_name = $n$Astronotus ocellatus$n$;

UPDATE species_profile SET description = $d$The Nkhomo-Benga peacock, or yellow regal peacock, is an Aulonocara from the Nkhomo reef near Benga in Lake Malawi. Males are bright yellow with blue on the face and fins; females are brown-grey. Peacocks hunt insect larvae in the sand, using sensory pores on the head to hear them.

Less aggressive than mbuna, so it does better with other peacocks and haps than with Mbuna. Keep one male with three or four females in a tank with open sand and rockwork. Females mouthbrood the eggs for about three weeks. Feed a varied diet of pellets and meaty frozen foods -- not the spirulina-only diet mbuna need.$d$
 WHERE scientific_name = $n$Aulonocara baenschi$n$;

UPDATE species_profile SET description = $d$The blue badis, or chameleon fish, is native to India, Bangladesh, Nepal and Pakistan, found in slow, well-vegetated streams and ponds. It changes colour with mood within seconds: brown with dark bars when calm, and blue-black with red and iridescent blue fins when displaying or breeding.

A shy micro-predator, about 6-8 cm, that is territorial toward its own kind but peaceful with others. It needs caves, plants and a calm tank. Males spawn in caves and guard the eggs. It often refuses dry food, so feed frozen and live foods such as bloodworm, daphnia and brine shrimp.$d$
 WHERE scientific_name = $n$Badis badis$n$;

UPDATE species_profile SET description = $d$The bala shark is not a shark but a cyprinid from the large rivers of Borneo, Sumatra and the Malay peninsula, where it is now listed as Endangered. It has a silver torpedo-shaped body and black-edged fins, and it grows to about 30-35 cm.

An active, peaceful schooling fish that needs a group of five or more and a very long tank; it jumps when startled, so keep the tank covered. Feed flake, pellets, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Balantiocheilos melanopterus$n$;

UPDATE species_profile SET description = $d$The tinfoil barb comes from the rivers of Thailand, Malaysia, Sumatra and Borneo. It has a silver body, red fins with black edges, and grows to about 35 cm.

A peaceful schooling fish that needs a group of five or more and a very large tank with strong filtration. It eats plants and small fish. Feed pellets, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Barbonymus schwanefeldii$n$;

UPDATE species_profile SET description = $d$The gold nugget pleco (L018, L081 and L085 are the same species from different sites) is a South American suckermouth catfish from the Xingu river in Brazil. It has a black body covered in yellow-gold spots and gold edges to the dorsal and tail fins.

It needs warm, highly oxygenated, fast-flowing water, and caves among rocks. It grows to about 20-25 cm and is territorial toward other plecos. Feed sinking wafers and frozen foods.$d$
 WHERE scientific_name = $n$Baryancistrus xanthellus$n$;

UPDATE species_profile SET description = $d$The Siamese fighting fish comes from the rice paddies, ditches and slow, shallow waters of Thailand and the Mekong basin. Wild fish are short-finned and dull; the halfmoon, plakat, crowntail and super delta forms in shops are the product of generations of selective breeding. A halfmoon's tail spreads to a full 180 degrees.

Bettas are labyrinth fish and breathe air from the surface, so the surface must stay open and the air above it warm. Males fight each other and flare at anything with long fins -- one male per tank. The male builds a bubble nest and guards the eggs alone. A carnivore: feed betta pellets with frozen bloodworm or brine shrimp, and not too much.$d$
 WHERE scientific_name = $n$Betta splendens$n$;

UPDATE species_profile SET description = $d$The yoyo loach comes from the foothill rivers of northern India and Nepal. Young fish have dark markings on a silver body that spell out 'Y-O-Y-O'; with age the pattern breaks into a lace-like network. Much of the trade sells it as Botia lohachata, a closely related species.

Active, playful and a good snail-eater, reaching about 12-15 cm. Keep a group of five or more, because single fish become aggressive toward other bottom-dwellers. Needs caves, soft sand and current. It clicks when feeding. Feed sinking pellets, frozen foods and snails.$d$
 WHERE scientific_name = $n$Botia almorhae$n$;

UPDATE species_profile SET description = $d$The zebra loach is endemic to the Western Ghats of India, in the fast, clear streams of Karnataka and Maharashtra. It is banded with narrow, alternating stripes of cream and dark brown-green over the body and fins, and grows to about 8-10 cm.

One of the most peaceful botiid loaches, but still social: keep a group of five or more with caves, soft sand and current. Wild populations are declining, so captive-bred fish are the better choice. Feed sinking pellets, frozen foods and small snails.$d$
 WHERE scientific_name = $n$Botia striata$n$;

UPDATE species_profile SET description = $d$Goldfish are domesticated from the Prussian carp of East Asia, bred in China for over a thousand years. Fancy forms have round bodies, double tails, head growths ('wen') on orandas and ranchus, or telescope eyes on moors; single-tailed comets and shubunkins are sleeker and faster.

They are cool-water fish, happiest at 18-24 C, and they grow large and produce heavy waste, so they need a large, strongly filtered tank -- never a bowl. Fancy and single-tailed varieties should not be mixed, because the fast ones out-compete the slow ones for food. Feed sinking goldfish pellets with vegetable matter.$d$
 WHERE scientific_name = $n$Carassius auratus$n$;

UPDATE species_profile SET description = $d$The pea puffer, or Malabar puffer, is endemic to the rivers of Kerala and Karnataka. At about 2.5 cm it is the smallest puffer in the world, and it is fully freshwater. Males have a dark stripe on the belly and a yellow tint; females are rounder and spotted.

Wild populations are listed as Vulnerable because of collection for the aquarium trade, so buy only captive-bred fish. It is territorial and nips fins, so keep it in a species tank with plants and cover. A carnivore: feed live and frozen foods and small snails, which also help to wear down its teeth.$d$
 WHERE scientific_name = $n$Carinotetraodon travancoricus$n$;

UPDATE species_profile SET description = $d$The demasoni is a small mbuna from Pombo Rocks on the Tanzanian coast of Lake Malawi, only about 8 cm long. Both sexes carry alternating dark and light blue bars. Despite its size it is one of the most aggressive mbuna.

It must be kept either in a large group of a dozen or more, where aggression spreads out, or not at all; a small group ends with one survivor. Provide plenty of rockwork with caves and hard, alkaline water. Mouthbrooder. An algae grazer, so feed spirulina-based pellets and flake and avoid rich meaty foods, which cause Malawi bloat.$d$
 WHERE scientific_name = $n$Chindongo demasoni$n$;

UPDATE species_profile SET description = $d$The clown loach comes from the rivers of Sumatra and Borneo. It has a bright orange body with three thick black bands and red fins. Juveniles are sold at 5 cm, but adults reach 20-30 cm and live for 20 years or more.

A social fish that must be kept in a group of five or more; alone it hides and pines. It clicks audibly when feeding and sometimes rests lying on its side, which is normal. It eats small snails eagerly. It has a sharp spine under each eye, so catch it with a container, and it is prone to white spot. Needs a large tank, caves and current. Feed sinking pellets, frozen foods and snails.$d$
 WHERE scientific_name = $n$Chromobotia macracanthus$n$;

UPDATE species_profile SET description = $d$The yellowfin borleyi is a Malawi hap from the southern half of the lake, where it schools above the rocks and feeds on zooplankton. Males show a blue or red body with bright yellow fins depending on location variant ('Kadango', 'Red Fin'); females are silver-brown.

Relatively peaceful for a Malawi cichlid, and good in a hap and peacock tank. It likes open water with rockwork nearby and a sandy floor. Hard, alkaline water. Mouthbrooder. Feed small pellets, flake and frozen foods such as mysis and brine shrimp.$d$
 WHERE scientific_name = $n$Copadichromis borleyi$n$;

UPDATE species_profile SET description = $d$The bronze cory is one of the hardiest and most widespread corydoras, found across much of South America east of the Andes. It has a metallic bronze-green flank and pale belly; the albino form is pink-white with red eyes. Both are widely captive-bred.

A peaceful bottom dweller that forages constantly through the substrate with its barbels, so soft sand or smooth gravel matters. Keep six or more. It spawns readily: the female holds eggs between her pelvic fins and sticks them to the glass or plants, often after a cool water change. Feed sinking pellets and frozen or live foods; leftovers alone are not enough.$d$
 WHERE scientific_name = $n$Corydoras aeneus$n$;

UPDATE species_profile SET description = $d$The skunk cory, or arched cory, comes from the Rio Negro and upper Amazon. It is cream to pale pink with a single black stripe that arches from the snout along the back to the lower lobe of the tail, a pattern that sets it apart from look-alikes.

Most specimens are wild-caught, so they need clean, mature, slightly acidic water to settle. Keep six or more on soft sand with some current and plenty of open floor. Like other corys it gulps air at the surface now and then; that is normal. Feed sinking pellets and frozen or live foods.$d$
 WHERE scientific_name = $n$Corydoras arcuatus$n$;

UPDATE species_profile SET description = $d$The peppered cory is from the rivers of south-eastern Brazil, Uruguay and northern Argentina. It has an olive-grey body mottled with dark patches and a pale belly, with long-finned forms also available. One of the first corydoras ever kept in aquariums, and still captive-bred in huge numbers.

It comes from subtropical waters and prefers it cooler than most tropicals, about 20-24 C, so an Indian summer tank without cooling stresses it. Keep six or more on soft sand. It spawns readily after a cooler water change. Feed sinking pellets, flake, and frozen bloodworm and brine shrimp.$d$
 WHERE scientific_name = $n$Corydoras paleatus$n$;

UPDATE species_profile SET description = $d$The panda cory is from the upper Amazon tributaries of Peru, a pale pink-white cory with black patches over the eye, the dorsal fin and the base of the tail. It is small, peaceful and one of the most popular corydoras.

Like all corys it lives in groups on sandy bottoms and should be kept in six or more on soft sand or smooth gravel, because rough gravel wears away the barbels it uses to find food. It prefers cooler, softer water than bronze corys, around 22-25 C. Feed sinking pellets and wafers, frozen bloodworm and brine shrimp -- not just leftovers.$d$
 WHERE scientific_name = $n$Corydoras panda$n$;

UPDATE species_profile SET description = $d$The pygmy cory is one of the smallest corydoras, barely 2.5 cm, from the Rio Madeira basin in Brazil. It is silvery with a black lateral line and, unlike most corys, spends much of its time swimming in loose schools in the middle of the water rather than on the bottom.

A nano and planted-tank fish that needs a group of eight to ten or more and gentle tankmates -- anything with a larger mouth will treat it as food. Soft substrate, plants and stable, clean water. Feed small sinking foods, micro-pellets, crushed flake and baby brine shrimp or daphnia.$d$
 WHERE scientific_name = $n$Corydoras pygmaeus$n$;

UPDATE species_profile SET description = $d$The emerald green cory -- sold for years as Brochis splendens -- is a large, deep-bodied corydoras from the upper Amazon. It has a metallic emerald body with a pale underside and grows to about 8 cm.

Hardy, peaceful and tolerant of warmth, which makes it a good cory for Indian conditions. It lives in groups like other corys, so keep five or more on soft sand with plants and driftwood for shade. The female carries eggs between her pelvic fins and scatters them singly on plants and surfaces, sometimes hundreds at once. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Corydoras splendens$n$;

UPDATE species_profile SET description = $d$Sterba's cory comes from the upper Rio Guapore in Brazil and Bolivia. It is dark with white spots on the head and body and orange-edged pectoral and pelvic fins, and is often confused with Corydoras haraldschultzi, which has a paler body and darker spots.

It tolerates warmer water than most corys (up to about 28 C), so it pairs well with discus and rams and suits Indian summers. Keep six or more on soft sand with some current and open floor space. The female carries eggs in a pouch formed by her pelvic fins and sticks them to leaves and glass. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Corydoras sterbai$n$;

UPDATE species_profile SET description = $d$Almost every 'julii cory' in the trade is actually the three-stripe cory, Corydoras trilineatus, from the upper Amazon in Peru. The true C. julii is rare in shops. The two differ in pattern: trilineatus has a more reticulated head and a sharper black stripe along the flank.

Peaceful, active and hardy, it lives in groups on sandy bottoms and should be kept in six or more on soft substrate to protect the barbels. Plants and wood give it shade to rest in. It spawns like other corys, sticking eggs to glass and leaves. Feed sinking pellets, wafers and frozen foods.$d$
 WHERE scientific_name = $n$Corydoras trilineatus$n$;

UPDATE species_profile SET description = $d$The Siamese algae eater is a cyprinid from the fast-flowing rivers of Thailand, Malaysia and Indonesia. It has a slim, silver-gold body with a black stripe from snout to tail that extends into the tail fin. Many fish sold under the name are look-alikes; the true SAE's stripe runs right to the end of the tail.

Young fish are among the few that eat black beard algae. It grows to about 15 cm and is best in a group. Feed algae wafers, vegetables and some protein.$d$
 WHERE scientific_name = $n$Crossocheilus oblongus$n$;

UPDATE species_profile SET description = $d$The frontosa is a large cichlid from the deep rocky slopes of Lake Tanganyika. It has a blue-white body with six dark vertical bars, long flowing fins, and a big hump on the forehead in adult males. Kigoma, Burundi and other regional forms differ in the number of bars and the blue on the face.

Slow-growing, long-lived and calm, but it swallows any fish that fits in its mouth. It lives in groups and needs a very large tank with hard, alkaline water and rock caves. Females mouthbrood the eggs for four weeks or more. Feed quality sinking pellets, krill, mysis and shrimp.$d$
 WHERE scientific_name = $n$Cyphotilapia frontosa$n$;

UPDATE species_profile SET description = $d$The dolphin cichlid, or blue dolphin moorii, is a Malawi hap from the sandy shallows of the lake. It is powder-blue, and both sexes grow a pronounced forehead hump with age. In the wild it follows sand-sifting fish and picks up the invertebrates they disturb.

A calm fish for a Malawi hap tank, reaching around 20 cm, that does best with other mild haps and peacocks rather than aggressive mbuna. Needs open sand and hard, alkaline water. Mouthbrooder. Feed quality cichlid pellets and meaty frozen foods.$d$
 WHERE scientific_name = $n$Cyrtocara moorii$n$;

UPDATE species_profile SET description = $d$The pearl danio comes from Myanmar, Thailand, Laos and Sumatra. Its body has a pearly, blue-violet iridescence, with a red-orange stripe running toward the tail. It grows to about 6 cm.

Fast, active and peaceful, it needs a group of six or more, a long tank with open space and a tight lid. It scatters eggs over plants. Feed flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Danio albolineatus$n$;

UPDATE species_profile SET description = $d$The glowlight danio comes from the streams of northern Myanmar. It has a gold-orange body with bright blue-green vertical bars toward the front and orange-red on the fins, and grows to about 3 cm.

Active, peaceful and tolerant of a range of water, it suits a planted community tank. Keep a group of six or more and a covered tank; like other danios it jumps. It scatters eggs over plants or gravel. Feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Danio choprae$n$;

UPDATE species_profile SET description = $d$The celestial pearl danio, or galaxy rasbora, is a tiny fish from the highland ponds of Myanmar, discovered in 2006. It has a dark blue body covered in pearly spots, and orange-and-black barred fins. Males are brighter, with red bellies.

A nano-tank fish, about 2.5 cm, that needs a group of eight or more and a planted tank. It is shy. It scatters eggs among plants. Feed fine flake and small frozen foods.$d$
 WHERE scientific_name = $n$Danio margaritatus$n$;

UPDATE species_profile SET description = $d$The zebra danio is native to India, Bangladesh and Nepal, from the Ganges and Brahmaputra floodplains to slow streams and rice paddies. Horizontal blue-and-gold stripes run from gill cover to tail; longfin, leopard and golden forms are selectively bred. It is also one of the world's most important laboratory animals.

Very active, hardy and tolerant of a wide temperature range. Keep a group of six or more with open swimming room and a covered tank, because it jumps. It scatters eggs over gravel or plants and eats them afterwards. An omnivore that takes almost any flake or small pellet.$d$
 WHERE scientific_name = $n$Danio rerio$n$;

UPDATE species_profile SET description = $d$The scarlet badis is one of India's smallest fish, from clear, shallow, vegetated streams in West Bengal and Assam. Males reach about 2 cm and are bright red with seven blue-white vertical bars and white-edged fins; females are plain grey and smaller.

A shy micro-predator that suits a densely planted nano tank of its own. Males are territorial, so keep one male per small tank with a few females. It feeds on tiny live food and rarely accepts dry food: feed cyclops, daphnia, baby brine shrimp and grindal worms.$d$
 WHERE scientific_name = $n$Dario dario$n$;

UPDATE species_profile SET description = $d$The red melon badis is a small badis from the streams of northern Myanmar, closely related to India's scarlet badis. Males reach about 2.5 cm and are orange-red with faint dark bars and blue-edged pelvic fins; females are smaller and plain grey-brown.

A micro-predator that picks tiny live food off plants and the bottom, it rarely accepts dry food, so plan on frozen and live foods -- cyclops, daphnia, baby brine shrimp, grindal worms. Best in a densely planted nano tank of its own, one male per small tank. Males guard eggs in a cave or among plants.$d$
 WHERE scientific_name = $n$Dario hysginon$n$;

UPDATE species_profile SET description = $d$The giant danio comes from the rivers of India, Nepal, Sri Lanka and Myanmar. It has a steel-blue body with gold stripes and spots and grows to about 10 cm.

Fast and active, it needs a group of six or more, a long tank with open space and current, and a tight lid -- it jumps. It scatters eggs over plants or gravel. Feed flake, pellets and frozen foods.$d$
 WHERE scientific_name = $n$Devario aequipinnatus$n$;

UPDATE species_profile SET description = $d$The red-tailed black shark is a cyprinid from Thailand's Chao Phraya basin, where it was believed extinct in the wild and is now Critically Endangered. It has a velvet-black body and a bright red tail. All trade fish are farmed.

Territorial and aggressive toward other bottom-dwellers and fish of similar colour, especially as it grows to about 12-15 cm. Keep one per tank with plenty of caves and plants. It grazes algae. Feed sinking pellets, algae wafers, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Epalzeorhynchos bicolor$n$;

UPDATE species_profile SET description = $d$The rainbow shark is a cyprinid from the Mekong, Chao Phraya and Mae Klong basins. It has a grey-black or albino-pink body and bright red fins.

Territorial like the red-tail shark, especially toward similar fish, and grows to about 15 cm. Keep one per tank with plenty of caves and plants. It grazes algae. Feed sinking pellets, algae wafers, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Epalzeorhynchos frenatum$n$;

UPDATE species_profile SET description = $d$The silver hatchetfish comes from the Amazon basin and the Guianas. It has a deep, keel-shaped chest that houses powerful muscles, used to leap from the water and flap-glide short distances to escape predators.

A surface-dwelling schooling fish that needs a group of six or more, calm tankmates and a tight lid with no gaps -- it will find any. Floating plants give it cover. Feed floating flake and small insects such as fruit flies.$d$
 WHERE scientific_name = $n$Gasteropelecus sternicla$n$;

UPDATE species_profile SET description = $d$The red rainbowfish, or red Irian rainbowfish, is endemic to Lake Sentani in West Papua. Mature males are deep red with a high, compressed back; females are olive-gold.

A schooling fish that needs a group of six or more, a long tank and hard, alkaline water. It spawns on moss or fine-leaved plants. Feed flake, pellets and frozen foods.$d$
 WHERE scientific_name = $n$Glossolepis incisus$n$;

UPDATE species_profile SET description = $d$The black skirt tetra comes from the Paraguay and Guapore basins. It has a deep silver body with black bars and a black, skirt-like anal fin. Longfin and white forms are bred.

Hardy, but can nip fins in small groups. Keep in a group of six or more. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Gymnocorymbus ternetzi$n$;

UPDATE species_profile SET description = $d$The Chinese algae eater is not from China: it comes from the rivers of Thailand, Laos, Cambodia and Vietnam. It has a slim body with a suckermouth, and gold and albino forms are sold.

Young fish graze algae, but adults (about 25 cm) lose interest in algae and become territorial, sometimes latching onto the sides of flat-bodied fish such as angelfish and discus. Feed algae wafers, vegetables and some protein.$d$
 WHERE scientific_name = $n$Gyrinocheilus aymonieri$n$;

UPDATE species_profile SET description = $d$The kissing gourami comes from South-East Asia, where it is farmed as a food fish. It has a pink or silver-green body and thick, protrusible lips that it uses to scrape algae from surfaces. The 'kissing' between two fish is a territorial test of strength, not affection.

It grows to about 20-30 cm and needs a large tank. It eats soft plants and algae. Generally peaceful, but it can harass smaller fish. Feed flake, vegetable-based pellets, greens and frozen foods.$d$
 WHERE scientific_name = $n$Helostoma temminckii$n$;

UPDATE species_profile SET description = $d$The rummy nose tetra is from the Rio Negro and Rio Meta. It has a silver body, a bright red head and a black-and-white striped tail. The red fades when water quality drops, making it a useful warning sign.

A tight schooling fish, best in a group of eight or more. Needs soft, acidic, stable water and a mature tank. Feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Hemigrammus bleheri$n$;

UPDATE species_profile SET description = $d$The glowlight tetra is from the Essequibo river in Guyana. It has a translucent body with a glowing orange-red line from nose to tail.

Peaceful and hardy, and tolerant of a wider range of water than most tetras. Best in a group of eight or more in a planted tank with subdued light. Feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Hemigrammus erythrozonus$n$;

UPDATE species_profile SET description = $d$The head-and-tail-light tetra comes from the Amazon basin and the Guianas. It has a silvery body with glowing orange-gold spots above the eye and at the base of the tail, like headlights and tail-lights.

Peaceful, hardy and easy to keep. Best in a group of six or more in a planted tank. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Hemigrammus ocellifer$n$;

UPDATE species_profile SET description = $d$The Texas cichlid is the only cichlid native to the United States, found in the Rio Grande of Texas and north-eastern Mexico. It is grey to green with a scattering of pearly blue-white spots over the body and fins.

Territorial and often aggressive, reaching around 25-30 cm, and needs a large tank with robust tankmates. It digs and uproots plants. It is sensitive to poor water quality, so filtration and water changes matter. Pairs spawn on flat stones and guard the fry. Feed pellets, frozen foods and some vegetable matter.$d$
 WHERE scientific_name = $n$Herichthys cyanoguttatus$n$;

UPDATE species_profile SET description = $d$The severum, or banded cichlid, is a South American cichlid from the Amazon and Orinoco basins. The green form is olive-green with faint bars; the gold form is widely bred. Adults reach around 20 cm, and males develop red-brown spotting on the face.

Calmer than most large cichlids, it can live with larger community fish of similar size. It prefers soft, slightly acidic water, driftwood and robust plants, which it may eat. Pairs spawn on flat surfaces and guard the young. An omnivore that likes some vegetable matter: pellets, frozen foods and blanched greens.$d$
 WHERE scientific_name = $n$Heros severus$n$;

UPDATE species_profile SET description = $d$The flowerhorn is a hybrid cichlid developed in Malaysia and Taiwan in the late 1990s from Central American species including Amphilophus and Vieja. It is prized for the large forehead hump ('kok'), the lateral 'flower' markings and bright red, pink or gold colour; strains such as Kamfa, Zhen Zhu and Thai silk are bred for them.

Very aggressive and always kept alone. It grows to around 30 cm, needs a large, strongly filtered tank and learns to recognise its owner. It is a manmade fish and does not belong in any natural waterway. Feed quality flowerhorn pellets with some meaty food.$d$
 WHERE scientific_name = $n$Hybrid (Amphilophus spp. x others)$n$;

UPDATE species_profile SET description = $d$The blood parrot is a manmade hybrid cichlid first produced in Taiwan around 1986, probably from Central American species such as Amphilophus citrinellus and Vieja synspila. It has a rounded body, a small beak-like mouth that cannot fully close, and red-orange colour that develops as it matures. Most males are infertile.

Peaceful and sociable, but its mouth shape makes it a slow, clumsy eater, so it loses food to faster tankmates. Needs a spacious tank with caves; pairs often lay eggs even though they rarely hatch. Avoid dyed and tattooed fish. Feed small, sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Hybrid (blood parrot cichlid)$n$;

UPDATE species_profile SET description = $d$The snowball pleco, L201, is a South American suckermouth catfish from the upper Orinoco and Rio Negro. It has a dark grey-black body covered in white or yellow spots.

Peaceful, about 13 cm, and suitable for most community tanks. It needs caves, driftwood and clean, oxygenated water. Mainly carnivorous: feed sinking pellets and frozen foods rather than only vegetable wafers.$d$
 WHERE scientific_name = $n$Hypancistrus inspector$n$;

UPDATE species_profile SET description = $d$The ember tetra comes from the Araguaia basin in central Brazil and was named after Amanda Bleher, mother of the explorer who collected it. It is a tiny, fiery orange-red tetra of about 2 cm.

A peaceful nano-tank fish that is safe with shrimp. Keep a group of ten or more in a planted tank with subdued light. It spawns among fine-leaved plants. Feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon amandae$n$;

UPDATE species_profile SET description = $d$The Buenos Aires tetra is a hardy South American tetra from Argentina, Paraguay and southern Brazil. It has a silver body, a black diamond-shaped spot at the tail and red-tinged fins.

Tolerant of cooler water and a wide range of conditions. It eats soft plants and can nip fins. Keep in a group of six or more. Feed flake, vegetable matter and frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon anisitsi$n$;

UPDATE species_profile SET description = $d$The serpae tetra comes from the Amazon and Paraguay basins. It has a red body, a black spot behind the gill cover and a black dorsal fin.

Hardy and active, but a known fin-nipper, especially in small groups. Keep in a group of eight or more and away from slow, long-finned fish. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon eques$n$;

UPDATE species_profile SET description = $d$The bleeding heart tetra is a South American tetra from the upper Amazon. It has a deep, pink-silver body with a red spot on the side like a bleeding heart, and males have a tall dorsal fin.

Peaceful and a good centrepiece schooling fish. Best in a group of six or more in a planted tank. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon erythrostigma$n$;

UPDATE species_profile SET description = $d$The black neon tetra comes from the Paraguay basin in Brazil. It has a black lower body under a bright green-white stripe, and a red top to the eye. It grows to about 4 cm.

Peaceful and hardy, and tolerant of a wider range of water than the true neon. Best in a group of eight or more in a planted tank. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon herbertaxelrodi$n$;

UPDATE species_profile SET description = $d$The black phantom tetra is a South American tetra from the Guapore and Paraguay basins. It has a smoky, translucent body with a black shoulder patch; males have a tall black dorsal fin, and females have red on the fins.

Peaceful; males display to each other without harm. Best in a group of six or more in a planted tank. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Hyphessobrycon megalopterus$n$;

UPDATE species_profile SET description = $d$The common pleco is a large suckermouth catfish from South America. The fish sold as 'common pleco' in India are often Pterygoplichthys species. It is sold as a small algae eater but grows to 30-50 cm, eats only some algae, and produces a lot of waste.

It needs a large tank with driftwood and strong filtration. It is nocturnal and territorial toward other plecos. Feed sinking wafers, vegetables and some protein.$d$
 WHERE scientific_name = $n$Hypostomus plecostomus$n$;

UPDATE species_profile SET description = $d$The threadfin rainbowfish is a tiny rainbowfish from northern Australia and southern New Guinea. Males have long, threadlike rays on the dorsal and anal fins.

Peaceful, delicate and slow, with a tiny mouth. Keep a group of six or more with calm, small tankmates that will not nip its threads. It spawns on moss. Feed fine flake and small live and frozen foods.$d$
 WHERE scientific_name = $n$Iriatherina werneri$n$;

UPDATE species_profile SET description = $d$The glass catfish is a transparent catfish from the rivers of southern Thailand. It was sold for decades as Kryptopterus bicirrhis, a larger relative. Its body is so clear that the skeleton and organs are visible, and it shimmers faintly in the light.

Unlike most catfish it swims in open water, hanging in a loose school facing the current. It must be kept in a group of six or more; alone it stops eating. Needs subdued light, plants, gentle current and clean, stable water. Feed fine flake, micro-pellets and small frozen foods such as daphnia and brine shrimp.$d$
 WHERE scientific_name = $n$Kryptopterus vitreolus$n$;

UPDATE species_profile SET description = $d$The yellow lab, or electric yellow, is an mbuna from the north-west coast of Lake Malawi between Charo and Mbowe island. Both sexes are bright yellow; the male's dorsal and pelvic fins are edged in black, and the female's less so.

The most peaceful of the popular mbuna, and a good choice for a first Malawi tank. Still territorial toward fish of similar shape and colour. Hard, alkaline water, sand and plenty of rockwork. Females mouthbrood for about three weeks. Its natural diet includes more small invertebrates than most mbuna, so feed quality cichlid pellets with some meaty food.$d$
 WHERE scientific_name = $n$Labidochromis caeruleus$n$;

UPDATE species_profile SET description = $d$The ocellatus is a shell-dwelling cichlid from Lake Tanganyika, only 5-6 cm long, that lives in and around empty snail shells on the sand. Males are larger and gold to bronze with a blue sheen; they dig shells into the substrate and defend them fiercely.

A small tank with sand and one empty shell per fish is all it needs, but it is bold and will attack much larger fish that come near its shell. Hard, alkaline water. Females lay eggs inside their shells. Feed small pellets and frozen foods such as brine shrimp and cyclops.$d$
 WHERE scientific_name = $n$Lamprologus ocellatus$n$;

UPDATE species_profile SET description = $d$The paradise fish is a labyrinth fish from southern China, Taiwan, Korea and Vietnam, and one of the first tropical fish ever kept in European aquariums, in the 1860s. Males have alternating red and blue-green vertical bands and long, trailing fins; females are duller. Albino and black forms exist.

It tolerates cool water (16-26 C) and a wide range of conditions, but it is aggressive: males fight like bettas and will eat small tankmates. Keep one male, ideally with a female, in a planted, covered tank -- it jumps. The male builds a bubble nest under floating plants and guards the eggs. Feed flake, pellets and frozen foods.$d$
 WHERE scientific_name = $n$Macropodus opercularis$n$;

UPDATE species_profile SET description = $d$The tire track eel is a spiny eel from South and South-East Asia, including India. It has a brown body with a zig-zag pattern like a tyre track. It is not a true eel. It grows to about 70 cm.

It burrows in soft sand, needs a large tank with a tight lid and hiding places, and will eat small fish. Feed live and frozen foods such as bloodworm, earthworms and prawns.$d$
 WHERE scientific_name = $n$Mastacembelus armatus$n$;

UPDATE species_profile SET description = $d$The fire eel is a spiny eel from the rivers of South-East Asia, with a dark brown body striped and spotted in red. It is not a true eel. It grows to 1 m.

It burrows in soft sand, needs a large tank with a tight lid and hiding places, and will eat small fish. Feed live and frozen foods such as bloodworm, earthworms and prawns.$d$
 WHERE scientific_name = $n$Mastacembelus erythrotaenia$n$;

UPDATE species_profile SET description = $d$The cobalt blue zebra is an mbuna from the northern and central coasts of Lake Malawi. It is solid powder-blue, often with faint barring; the male has yellow-orange egg spots on the anal fin. A white 'OB'-type form also exists.

Robust and aggressive, like most Maylandia. Keep one male with several females among plenty of rockwork and caves, in hard, alkaline water. Females mouthbrood the eggs for around three weeks. Algae grazer: feed spirulina-based pellets and flake, keep meaty food to a minimum, and do not overfeed.$d$
 WHERE scientific_name = $n$Maylandia callainos$n$;

UPDATE species_profile SET description = $d$The red zebra is an mbuna from the east coast of Lake Malawi, in Mozambique. In the wild most males are pale blue and most females orange; in aquarium strains both sexes are often orange-red, with the males developing egg spots on the anal fin.

A tough, territorial mbuna that bullies anything smaller or similar in shape. Keep one male with several females in a tank with plenty of rockwork and hard, alkaline water. Mouthbrooder. An algae grazer, so feed spirulina-based pellets and flake and avoid too much meaty food.$d$
 WHERE scientific_name = $n$Maylandia estherae$n$;

UPDATE species_profile SET description = $d$The kenyi is an mbuna from Mbenji Island in Lake Malawi. It shows reverse sexual dichromatism: females and juveniles are blue with dark bars, while adult males turn yellow-gold. That makes a group of juveniles look like two species.

Among the more aggressive mbuna, even toward females, so keep one male with several females in a large tank with plenty of rockwork. Hard, alkaline water with sand. Females mouthbrood for about three weeks. Feed spirulina-rich pellets and flake, with little meaty food.$d$
 WHERE scientific_name = $n$Maylandia lombardoi$n$;

UPDATE species_profile SET description = $d$The auratus, or golden mbuna, is from the southern rocky shores of Lake Malawi. Juveniles and females are golden-yellow with black and white horizontal stripes; dominant males reverse it, turning almost black with yellow-white stripes.

Among the most aggressive mbuna, harassing females and other fish relentlessly, so it belongs in a large, heavily rocked tank with other robust mbuna, one male to several females. Hard, alkaline water. Mouthbrooder. Feed spirulina-based pellets and flake with some meaty food.$d$
 WHERE scientific_name = $n$Melanochromis auratus$n$;

UPDATE species_profile SET description = $d$The johanni is an mbuna from the south-eastern shores of Lake Malawi. Males are deep blue with black horizontal stripes; females and juveniles are bright orange-yellow, so the species is often bought as two different fish.

Aggressive, especially males to each other, and needs a spacious rocky tank shared with other robust mbuna. Keep one male with several females. Hard, alkaline water. Females mouthbrood for about three weeks. Omnivorous: spirulina-based pellets with some meaty foods such as brine shrimp.$d$
 WHERE scientific_name = $n$Melanochromis johannii$n$;

UPDATE species_profile SET description = $d$The Boeseman's rainbowfish comes from the Ajamaru Lakes in West Papua, Indonesia, where it is listed as Endangered. Males are blue-violet at the front and orange-yellow at the back; females are plainer silver.

A schooling fish that needs a group of six or more and a long tank with open swimming room. It colours up with age and does best in hard, alkaline water. It spawns on fine-leaved plants or moss over several days. Feed flake, small pellets and frozen foods.$d$
 WHERE scientific_name = $n$Melanotaenia boesemani$n$;

UPDATE species_profile SET description = $d$The dwarf neon rainbowfish comes from the Mamberamo river basin in northern West Papua. It has an iridescent blue body; males have red fins, females yellow-orange fins.

Peaceful and small, about 5-6 cm, making it the rainbowfish for a smaller tank. Keep a group of six or more. It spawns on moss or fine-leaved plants. Feed fine flake and small frozen foods.$d$
 WHERE scientific_name = $n$Melanotaenia praecox$n$;

UPDATE species_profile SET description = $d$The silver dollar is a South American characin related to the piranha and pacu. It has a round, flat, silver body and grows to about 15 cm.

A peaceful schooling fish that needs a group of five or more and a large tank. It eats most plants, so use hardy or artificial plants. Feed vegetable-based flake, pellets and greens.$d$
 WHERE scientific_name = $n$Metynnis argenteus$n$;

UPDATE species_profile SET description = $d$The ram, or German blue ram, is a small cichlid from the warm, soft, slow waters of the Llanos savannah in Venezuela and Colombia. It has a gold-to-blue body, a black bar through a red eye, and a tall front dorsal fin. Electric blue, gold and balloon forms are captive-bred.

Peaceful and pairs faithfully, but it needs warm (27-30 C), clean, stable soft water and does badly in tanks that swing. Provide open sand to sift, plants and a few caves or flat stones. Both parents guard eggs laid on a stone or in a pit. Feed small pellets, flake and frozen foods several times a day.$d$
 WHERE scientific_name = $n$Mikrogeophagus ramirezi$n$;

UPDATE species_profile SET description = $d$The diamond tetra comes from Lake Valencia and nearby rivers in Venezuela. Adults have scales that glitter like diamonds; males also develop long, flowing dorsal and anal fins with a purple tint.

Peaceful and hardy, and a good centrepiece tetra for a planted community tank. It takes several months to develop its full sparkle. Keep a group of six or more. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Moenkhausia pittieri$n$;

UPDATE species_profile SET description = $d$The red eye tetra is a South American tetra from the Paraguay and Parana basins. It has a silver body, a black band at the tail and a bright red upper eye.

Hardy, adaptable and tolerant of a wide range of water. It can nip fins in small groups. Keep in a group of six or more. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Moenkhausia sanctaefilomenae$n$;

UPDATE species_profile SET description = $d$The emperor tetra is from the San Juan and Atrato rivers of Colombia. It has a purple-blue body with a black stripe, and males have a three-pointed tail with an extended middle ray.

Peaceful and hardy. Males are territorial with each other. Best in a group of six or more in a planted tank. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Nematobrycon palmeri$n$;

UPDATE species_profile SET description = $d$The brichardi, or fairy cichlid, is a small Lake Tanganyika cichlid with lyre-shaped tail tips and a pale fawn body; albino forms are also sold. It lives in colonies along the rocky shore, and older offspring help guard their younger siblings -- one of the best-known examples of cooperative breeding in fish.

Keep a group or pair in a tank with plenty of rockwork and caves in hard, alkaline water. It can become territorial as the colony grows. A cave spawner that breeds readily. Feed small pellets, flake and meaty frozen foods.$d$
 WHERE scientific_name = $n$Neolamprologus brichardi$n$;

UPDATE species_profile SET description = $d$The lemon cichlid is a small Lake Tanganyika cave-dweller, bright yellow to orange with a large mouth. Its colour depends on diet and substrate: pale sand and carotene-rich foods keep it bright, while dark gravel makes it darker.

Territorial and fairly aggressive for its size, particularly with other cave-dwellers. Keep a pair in a rocky tank with plenty of caves and hard, alkaline water. It spawns secretively in caves. Feed meaty frozen foods such as mysis and brine shrimp alongside quality pellets.$d$
 WHERE scientific_name = $n$Neolamprologus leleupi$n$;

UPDATE species_profile SET description = $d$The venustus, or giraffe cichlid, is a large Malawi hap from the sandy parts of the lake. Its tan-and-brown blotched pattern gives the common name; mature males develop a blue face and yellow on the head. In the wild it lies on the sand, playing dead, and ambushes small fish that come to investigate.

A predator that grows to about 25 cm and needs a large tank with open sand, rockwork and robust tankmates of similar size. Hard, alkaline water. Mouthbrooder. Feed meaty foods: quality cichlid pellets, krill, shrimp and mysis.$d$
 WHERE scientific_name = $n$Nimbochromis venustus$n$;

UPDATE species_profile SET description = $d$The silver arowana is a large surface-hunting fish from the Amazon basin, with a long, silver, ribbon-like body and two chin barbels. In the wild it leaps out of the water to snatch insects and small animals from overhanging branches, and it can reach close to a metre.

It needs a very large tank with a heavy, secure lid; it jumps. Keep it with other large, peaceful fish. Males mouthbrood the eggs and fry. Feed meaty foods: quality floating pellets, prawns, crickets and fish fillet, never live feeder fish.$d$
 WHERE scientific_name = $n$Osteoglossum bicirrhosum$n$;

UPDATE species_profile SET description = $d$Otocinclus are tiny South American suckermouth catfish from well-planted, fast-flowing streams. They are tan with a dark lateral stripe and are prized in planted tanks for grazing soft green algae and biofilm from leaves and glass without harming the plants.

Most otos sold are still wild-caught and many arrive thin, so they need a mature tank with established biofilm and should be kept in groups of five or more. Once the natural algae runs out they starve quietly, so supplement with algae wafers and blanched vegetables such as zucchini or cucumber. Peaceful with everything; needs good filtration and oxygen.$d$
 WHERE scientific_name = $n$Otocinclus vittatus$n$;

UPDATE species_profile SET description = $d$The royal pleco is a large wood-eating suckermouth catfish from South America. It has a grey-green body with dark lines and red eyes. It rasps driftwood constantly, and wood is a necessary part of its diet.

It grows to 40 cm or more, needs a large tank with plenty of driftwood, and is territorial toward other plecos. Feed vegetables such as zucchini and sweet potato alongside sinking wafers.$d$
 WHERE scientific_name = $n$Panaque nigrolineatus$n$;

UPDATE species_profile SET description = $d$The iridescent shark is not a shark but a large catfish from the Mekong and Chao Phraya rivers of South-East Asia. It is widely farmed as a food fish (pangas or basa), including in India. Juveniles have an iridescent sheen that fades with age.

It grows to 1.3 m, is a nervous schooling fish that crashes into walls when frightened, and needs a very large tank. It is rarely a good long-term aquarium fish. Feed pellets, frozen foods and vegetables.$d$
 WHERE scientific_name = $n$Pangasianodon hypophthalmus$n$;

UPDATE species_profile SET description = $d$The kuhli loach is an eel-shaped loach from the soft, shaded forest streams of Malaysia and Indonesia, banded in dark brown over salmon-pink to yellow. Several very similar Pangio species are sold under the same name, including the plain black kuhli.

It is shy and mostly nocturnal, and it only comes into the open when kept in a group of five or more with sand to burrow into and plenty of cover. Keep the substrate soft, since it spends its time in it, and cover filter intakes, which it will squeeze into. Feed sinking pellets, and live or frozen bloodworm and daphnia after lights out.$d$
 WHERE scientific_name = $n$Pangio kuhlii$n$;

UPDATE species_profile SET description = $d$The African butterflyfish comes from the still waters of West and Central Africa. It has large, wing-like pectoral fins and spends almost all its time at the surface waiting for insects. It can jump out of the water.

It needs a tank with a tight lid and floating plants, and it will eat small fish. Feed floating insects and small frozen foods.$d$
 WHERE scientific_name = $n$Pantodon buchholzi$n$;

UPDATE species_profile SET description = $d$The cardinal tetra is from the soft, acidic blackwaters of the Rio Negro and upper Orinoco, where most of the world's supply is still collected by local fishers. It looks like a larger neon, but the red band runs the whole length of the body beneath the blue line.

It needs soft, acidic, stable water and a mature tank more than a neon does, and it likes it warmer (26-29 C), which suits Indian summers better than it suits cool-water fish. Keep a big group under subdued light with plants, wood and leaf litter. Peaceful and small-mouthed: feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Paracheirodon axelrodi$n$;

UPDATE species_profile SET description = $d$The neon tetra comes from the clear and blackwater streams of the upper Amazon in Peru, Colombia and Brazil. An iridescent blue line runs from nose to adipose fin over a red band that covers only the rear half of the body -- the quickest way to tell it from the cardinal, whose red runs the full length. Nearly every neon sold in India is farm-bred in Asia.

A mid-water schooler that looks best in a large group over dark substrate, with plants and wood for cover and some dim areas. Entirely peaceful, and small enough to be eaten by angelfish once those are grown. Eats fine flake, micro-pellets and small frozen foods such as daphnia and baby brine shrimp.$d$
 WHERE scientific_name = $n$Paracheirodon innesi$n$;

UPDATE species_profile SET description = $d$The jaguar cichlid is a large predatory cichlid from the lakes and rivers of Honduras, Nicaragua and Costa Rica. Adults are silver-gold with black blotches and spots like a jaguar's coat, and have a large protrusible mouth with visible teeth.

It grows to 40-50 cm, needs a very large tank and eats any fish it can swallow. Highly aggressive and best kept with large, robust cichlids or on its own. It digs and moves rocks. Pairs spawn on flat surfaces and guard the young. Feed quality large cichlid pellets and meaty foods.$d$
 WHERE scientific_name = $n$Parachromis managuensis$n$;

UPDATE species_profile SET description = $d$The kribensis is a small West African cichlid from the coastal rivers of Nigeria and Cameroon. The female is the more colourful: she turns plum-red on the belly when ready to spawn. Males are longer with pointed fins. Albino forms are common.

It spawns in caves and makes an excellent first cichlid for breeding: provide a cave or coconut shell and a pair will usually raise a cloud of fry together. Territorial while breeding, otherwise peaceful with fish that stay out of the lower level. Digs a little, so root plants firmly. Feed pellets, flake and frozen foods.$d$
 WHERE scientific_name = $n$Pelvicachromis pulcher$n$;

UPDATE species_profile SET description = $d$The rosy barb is native to northern India, Nepal, Bangladesh and Pakistan, and is one of the hardiest barbs. Males turn deep rose-red; females are golden-olive. Both have a black spot near the tail. Longfin and neon forms are bred.

Tolerant of cooler water (18-25 C) and a wide range of conditions. Active and can nip slow fish, so keep a group of six or more. Feed flake, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Pethia conchonius$n$;

UPDATE species_profile SET description = $d$The black ruby barb comes from the rainforest streams of south-western Sri Lanka. Males in breeding colour turn deep ruby-red on the head and black on the body; females are gold with dark bars.

Peaceful for a barb, but it may nip slow fish in small groups. Keep six or more in a planted tank with open space. It scatters eggs among plants. Feed flake, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Pethia nigrofasciata$n$;

UPDATE species_profile SET description = $d$The Odessa barb comes from the Chindwin and Irrawaddy basins of Myanmar. It is named after the Ukrainian city where it first turned up in the aquarium trade. Males have a bright red band along the flank and black-spotted fins; females are silver-gold.

Active and generally peaceful, but it may nip slow fish in small groups. Keep six or more in a planted tank with open space. It scatters eggs among plants. Feed flake, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Pethia padamya$n$;

UPDATE species_profile SET description = $d$The Congo tetra is an African tetra from the Congo basin. Males reach about 8 cm and have large, iridescent bodies in blue, gold and green, with long, flowing fins; females are smaller and plainer.

Peaceful but can be shy, especially if outnumbered by busier fish. It needs a large, planted tank with open space and a group of six or more. It scatters eggs among plants. Feed flake, small pellets and frozen foods.$d$
 WHERE scientific_name = $n$Phenacogrammus interruptus$n$;

UPDATE species_profile SET description = $d$The redtail catfish is a giant South American catfish from the Amazon and Orinoco basins. It has a dark grey back, white belly and red tail, and a huge mouth.

Sold as a cute juvenile, it grows to 1.3 m or more and will swallow any tankmate that fits in its mouth. Very few keepers can house an adult, and public aquariums rarely accept unwanted ones. Buy only with a tank of several thousand litres planned. Feed sinking pellets, fish fillet and prawns.$d$
 WHERE scientific_name = $n$Phractocephalus hemioliopterus$n$;

UPDATE species_profile SET description = $d$The pictus catfish is a small, active South American catfish from the Amazon and Orinoco, with a silver body covered in black spots and very long barbels.

It is peaceful toward fish too big to eat, but it hunts small fish such as neon tetras at night. It is active and should be kept in a group in a long tank. Its fin spines tangle in nets, so catch it with a container. Feed sinking pellets and frozen foods such as bloodworm.$d$
 WHERE scientific_name = $n$Pimelodus pictus$n$;

UPDATE species_profile SET description = $d$The striped raphael catfish is a South American 'talking' catfish, named for the croaking sound it makes by grinding its pectoral spines. It has a dark brown body with a white stripe along the side and a row of spiny plates along its flank.

Peaceful and hardy, reaching about 20 cm. It hides by day and comes out to scavenge at night. It can eat very small fish. Its spines tangle in nets. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Platydoras armatulus$n$;

UPDATE species_profile SET description = $d$The guppy is native to Trinidad, Venezuela and the northern Amazon, and has been bred into hundreds of colour and tail strains -- cobra, tuxedo, mosaic, dumbo-ear and more. Males are small and brilliantly finned; females are larger, plainer and grey-bodied, with a dark gravid spot near the vent.

A livebearer: females store sperm and drop 20-50 fry roughly every four weeks, and the adults will eat them without plenty of fine-leaved plants or moss. Hardy and peaceful, but heavily inbred strains are weaker than they look. An omnivore: good flake, micro-pellets, and frozen or live foods such as daphnia and brine shrimp.$d$
 WHERE scientific_name = $n$Poecilia reticulata$n$;

UPDATE species_profile SET description = $d$Aquarium mollies are livebearers from Central America descended from several wild species -- Poecilia sphenops, P. latipinna and P. velifera -- and most shop fish are hybrids. Black, dalmatian, gold dust, balloon and lyretail forms are all bred. Males have a gonopodium; sailfin males raise a tall dorsal fin in display.

A hard-water fish that often suffers in soft or acidic water; it does well in India's hard tap water. It grazes algae constantly. Females drop 20-60 fry about every four to six weeks. Feed flake with plenty of vegetable matter, plus frozen foods.$d$
 WHERE scientific_name = $n$Poecilia sphenops$n$;

UPDATE species_profile SET description = $d$Endler's livebearer is a small guppy relative from the Laguna de Patos area of north-eastern Venezuela, named after John Endler, who collected it in the 1970s. Males are only about 2.5 cm and have neon orange, green and black markings; females are plain and larger.

It crosses readily with guppies, so pure strains are kept apart. Peaceful, hardy and nano-friendly, and safe with shrimp. Females drop small broods often. Feed fine flake and small frozen foods.$d$
 WHERE scientific_name = $n$Poecilia wingei$n$;

UPDATE species_profile SET description = $d$The ornate bichir comes from the Congo basin and Lake Tanganyika. It has a long, eel-like body with a black-and-white reticulated pattern and a row of small dorsal finlets. It has primitive lungs and must reach the surface to breathe air.

It grows to about 60 cm, needs a large tank with a tight lid and will eat small fish. Feed sinking carnivore pellets and frozen foods.$d$
 WHERE scientific_name = $n$Polypterus ornatipinnis$n$;

UPDATE species_profile SET description = $d$The X-ray tetra is from the Amazon and coastal rivers of the Guianas. It has a translucent body in which the swim bladder is visible, with yellow, black and white bands on the dorsal and anal fins.

Hardy and tolerant of a wide range of water. Best in a group of six or more. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Pristella maxillaris$n$;

UPDATE species_profile SET description = $d$The tiger shovelnose catfish is a large South American predator with a flattened, shovel-like snout, long barbels and a silver body striped and spotted in black.

It grows to about 1 m, is fast and skittish, and easily injures itself on tank walls when startled. It eats fish it can swallow. It needs a very large, long tank with a secure lid and robust tankmates. Feed sinking carnivore pellets, fish fillet and prawns.$d$
 WHERE scientific_name = $n$Pseudoplatystoma fasciatum$n$;

UPDATE species_profile SET description = $d$The acei, or yellow-tail acei, is an mbuna-type cichlid from the north-west coast of Lake Malawi. It has a slender blue to purple body and bright yellow fins; the white-tail form is sold as 'Ngara'. Unusually, in the wild it grazes algae from sunken wood and reeds rather than rocks.

One of the mildest Malawi cichlids and a social fish that does well in a group. Keep it in hard, alkaline water with sand, rockwork and perhaps some wood. Mouthbrooder, with the female holding eggs for about three weeks. Feed spirulina-based pellets and flake with a little meaty food.$d$
 WHERE scientific_name = $n$Pseudotropheus acei$n$;

UPDATE species_profile SET description = $d$The bumblebee cichlid is an mbuna from the rocky shores and caves of Lake Malawi. It has bold yellow and black-brown vertical bars, and can darken almost to black when stressed or dominant. In the wild it is a cleaner fish that picks parasites off a large catfish, Bagrus meridionalis, and eats its eggs.

It grows to around 15 cm and turns aggressive as it matures, so it needs a large tank with plenty of rockwork and other robust mbuna. Hard, alkaline water. Mouthbrooder. Omnivorous: vegetable-based cichlid foods plus some meaty food.$d$
 WHERE scientific_name = $n$Pseudotropheus crabro$n$;

UPDATE species_profile SET description = $d$The saulosi is a small mbuna from Taiwan Reef in Lake Malawi, and one of the clearest cases of sexual dichromatism in cichlids: juveniles and females are bright yellow, while adult males turn blue with dark vertical bars. A group looks like two different fish.

At about 9 cm it suits a smaller mbuna setup, but it is still territorial; keep one male with several females, or a larger group, among plenty of rockwork. Hard, alkaline water. Mouthbrooder. An algae grazer, so feed spirulina-based foods and go easy on protein.$d$
 WHERE scientific_name = $n$Pseudotropheus saulosi$n$;

UPDATE species_profile SET description = $d$The freshwater angelfish is a cichlid from the Amazon basin, where it lives among flooded vegetation and roots. The tall, flat body lets it slip through vertical stems. Captive breeding has produced silver, marble, koi, half-black, black, gold and veil-finned forms.

It grows to about 15 cm long and even taller including fins, so it needs a tall tank. Young angels shoal; adults pair and become territorial while breeding. Pairs lay eggs on a leaf, slate or tank wall and both parents fan and guard them. Adults eat small fish such as neons. Feed quality flake, pellets and frozen bloodworm and brine shrimp.$d$
 WHERE scientific_name = $n$Pterophyllum scalare$n$;

UPDATE species_profile SET description = $d$The sailfin pleco is a large South American suckermouth catfish with a tall dorsal fin of ten or more rays and a brown body patterned in darker spots or reticulation.

It grows to about 50 cm, needs a large tank with driftwood and strong filtration, and produces a lot of waste. Peaceful but can be territorial toward other plecos. Feed sinking wafers, vegetables and some protein.$d$
 WHERE scientific_name = $n$Pterygoplichthys gibbiceps$n$;

UPDATE species_profile SET description = $d$The tiger barb is from Sumatra and Borneo. It has a gold body crossed by four black vertical bars and red-tipped fins. Green, albino and GloFish forms are bred.

Active and famously nippy, especially in small groups. A group of eight or more spreads the chasing among themselves; avoid slow, long-finned tankmates such as bettas and angelfish. Feed flake, pellets and frozen foods.$d$
 WHERE scientific_name = $n$Puntigrus tetrazona$n$;

UPDATE species_profile SET description = $d$The cherry barb is a small barb from the shaded streams of Sri Lanka, where it is listed as Vulnerable. Males turn deep cherry-red; females are brown with a dark lateral stripe.

Peaceful and one of the few barbs that does not nip fins. Keep a group of six or more with more females than males in a planted tank. It scatters eggs among plants. Feed flake, small pellets and frozen foods.$d$
 WHERE scientific_name = $n$Puntius titteya$n$;

UPDATE species_profile SET description = $d$The scissortail rasbora comes from Malaysia, Borneo, Sumatra and the Mekong basin. It has a silver body and a deeply forked tail with black-and-white marks that open and close like scissors as it swims. It grows to about 10 cm.

Active and peaceful, best in a group of six or more with open swimming room in a long, covered tank. Feed flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Rasbora trilineata$n$;

UPDATE species_profile SET description = $d$The Jack Dempsey is a Central American cichlid from Mexico to Honduras, named after the 1920s boxer for its looks and temperament. Adults are dark grey-brown to purple, covered in iridescent blue-green spangles. The electric blue form is a smaller, weaker-growing colour morph.

Grows to about 25 cm and is territorial and aggressive, especially when breeding. Keep with other robust Central Americans in a large tank with caves and hardy plants. Pairs spawn on flat stones and guard the fry. Feed quality cichlid pellets and meaty frozen foods.$d$
 WHERE scientific_name = $n$Rocio octofasciata$n$;

UPDATE species_profile SET description = $d$The Denison barb, also called the red-line torpedo barb or Miss Kerala, is endemic to the fast, clear, well-oxygenated rivers of the Western Ghats in Kerala and Karnataka. It is a slim, silver fish with a black line from snout to tail, a red line above it, and black-and-yellow tips to the tail.

Heavy collection for the aquarium trade pushed it to IUCN Endangered, so only captive-bred fish should be bought. Peaceful and active, it needs a group of five or more, a long tank with current, and a tight lid -- it jumps. An omnivore: flake, pellets, vegetables and frozen foods.$d$
 WHERE scientific_name = $n$Sahyadria denisonii$n$;

UPDATE species_profile SET description = $d$The electric blue ahli is a Malawi hap, a predator that hunts small fish along the rocky shores of Lake Malawi. Mature males are an intense electric blue, often with a white edge to the dorsal fin; females are silver-grey.

Less aggressive than most mbuna but a predator that will eat small fish. Best in a large tank with other haps and peacocks, with open sand and rockwork. Hard, alkaline water. Mouthbrooder, with fry released after about three weeks. Feed quality meaty cichlid pellets and frozen foods such as krill and mysis.$d$
 WHERE scientific_name = $n$Sciaenochromis fryeri$n$;

UPDATE species_profile SET description = $d$The Asian arowana is a large surface predator from South-East Asia, prized in Asian culture as a symbol of luck. The super red, golden crossback, red tail golden and green forms are regional varieties. It grows to 60-90 cm.

It is listed in CITES Appendix I, so international trade is permitted only for registered captive-bred fish from approved farms, each microchipped and certified. It needs a very large tank with a heavy lid. Mouthbrooder. Feed meaty foods: quality floating pellets, prawns, insects and fish.$d$
 WHERE scientific_name = $n$Scleropages formosus$n$;

UPDATE species_profile SET description = $d$The jardini arowana, or Australian pearl arowana, comes from northern Australia and southern New Guinea. It has a bronze-green body with a pearl-pink spot on each scale, giving it its common name.

A powerful surface predator growing to about 60 cm, and more aggressive than the silver arowana. It needs a large tank with a heavy lid, and tankmates must be too big to swallow. Mouthbrooder. Feed meaty foods: pellets, prawns, insects and fish.$d$
 WHERE scientific_name = $n$Scleropages jardinii$n$;

UPDATE species_profile SET description = $d$The reticulated hillstream loach comes from the fast, oxygen-rich mountain streams of Vietnam and Laos. Its flattened body and wide fins act as a suction cup that holds it to rocks against strong current, and its pattern of gold spots on a dark body looks like a tiny stingray.

It needs cool (20-24 C), fast, well-oxygenated water, smooth rocks covered in biofilm, and a mature tank. It grazes algae and biofilm. Keep it in a group. Feed algae wafers, biofilm-rich foods and small frozen foods such as bloodworm.$d$
 WHERE scientific_name = $n$Sewellia lineolata$n$;

UPDATE species_profile SET description = $d$The chocolate gourami comes from the peat swamps of Malaysia, Sumatra and Borneo. It has a chocolate-brown body with three or four gold bars; males have a yellow edge to the anal and tail fins.

One of the more difficult gouramis: it needs very soft, acidic, clean water and is prone to skin and bacterial infections in harder water. Keep a small group in a heavily planted tank with leaf litter and subdued light. Females mouthbrood the eggs for about two weeks. Feed small frozen and live foods.$d$
 WHERE scientific_name = $n$Sphaerichthys osphromenoides$n$;

UPDATE species_profile SET description = $d$Discus are Amazonian cichlids from three wild species, and the fish in shops are domestic strains bred mostly in South-East Asia for decades -- pigeon blood, blue diamond, red melon, stardust and many more. Their colour shifts with mood, health and water.

A demanding fish: it needs warm water (28-31 C), very clean water with large, frequent water changes, and a calm, tall tank. Keep a group of five or more young discus and let pairs form. Pairs lay eggs on a vertical surface and feed the fry on a mucus they secrete from their skin. Feed discus granules, frozen bloodworm and beefheart mixes.$d$
 WHERE scientific_name = $n$Symphysodon spp. (domestic strains)$n$;

UPDATE species_profile SET description = $d$The featherfin synodontis is an African catfish from the Niger, Volta and Nile basins. It has a grey-brown spotted body, a tall feathery dorsal fin and long barbels.

Peaceful, hardy and long-lived, reaching about 20 cm, and a good choice for African cichlid tanks. Nocturnal, so it hides by day. It squeaks when handled. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Synodontis eupterus$n$;

UPDATE species_profile SET description = $d$The cuckoo catfish is a Lake Tanganyika synodontis with a pale body covered in black spots and white-edged fins. It is famous as a brood parasite: during a mouthbrooding cichlid's spawn, it slips its own eggs among the cichlid's eggs, and the catfish fry hatch first and eat the cichlid's young inside the mother's mouth.

Peaceful and active in groups, best kept with Tanganyika or Malawi cichlids in hard, alkaline water. Feed sinking pellets and frozen foods.$d$
 WHERE scientific_name = $n$Synodontis multipunctatus$n$;

UPDATE species_profile SET description = $d$The upside-down catfish is a small African catfish from the Congo basin that habitually swims belly-up, feeding from the surface and the undersides of leaves. Its belly is darker than its back, the reverse of most fish -- countershading adapted to swimming upside-down.

Peaceful, about 10 cm, and best kept in a group with driftwood and caves. Feed sinking pellets, flake and frozen foods.$d$
 WHERE scientific_name = $n$Synodontis nigriventris$n$;

UPDATE species_profile SET description = $d$The White Cloud Mountain minnow is from the cool mountain streams of southern China, near Guangzhou. It is rare in the wild but bred in huge numbers. It has a slim brown-green body with a gold line and red on the fins.

A cool-water fish, happiest at 18-22 C, which makes Indian summers difficult. Peaceful and hardy. Keep a group of six or more. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Tanichthys albonubes$n$;

UPDATE species_profile SET description = $d$The penguin tetra comes from the Amazon basin. It has a silver body with a black stripe that runs down into the lower tail lobe, and it swims at an upward-tilted angle, like a penguin.

Active and peaceful, about 6 cm long. Best in a group of six or more with open swimming room. It scatters eggs among plants. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Thayeria boehlkei$n$;

UPDATE species_profile SET description = $d$The firemouth is a Central American cichlid from the Yucatan peninsula of Mexico, Guatemala and Belize. It has a grey-blue body with dark bars, and a bright red throat and chest that the male flares out in display.

One of the milder Central Americans, at about 15 cm, but territorial when breeding. Keep with fish of similar size in a tank with sand, rocks and some open water. It sifts the sand for food. Pairs spawn on stones or in pits and guard the fry. Feed pellets, flake and frozen foods.$d$
 WHERE scientific_name = $n$Thorichthys meeki$n$;

UPDATE species_profile SET description = $d$The honey gourami is a small labyrinth fish from the Ganges and Brahmaputra floodplains of north-east India and Bangladesh. Most of the year both sexes are silver-brown with a faint stripe; breeding males turn honey-gold with a dark blue-black throat and belly. Red and gold forms are bred.

Peaceful, shy and one of the best gouramis for a community tank, reaching only 4-5 cm. It likes a planted tank with floating plants and calm water. The male builds a small bubble nest and guards the eggs. Feed flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Trichogaster chuna$n$;

UPDATE species_profile SET description = $d$The dwarf gourami is a labyrinth fish native to the Ganges and Brahmaputra floodplains of India and Bangladesh. Males have red-and-blue striped bodies; neon blue, powder blue and flame red forms are bred. Females are silvery and plainer.

Peaceful but shy, about 5-6 cm, and males are territorial with each other. Many farmed fish carry dwarf gourami iridovirus, an incurable infection, so buy healthy, quarantined fish. The male builds a bubble nest using plant fragments. Feed flake and small frozen foods.$d$
 WHERE scientific_name = $n$Trichogaster lalius$n$;

UPDATE species_profile SET description = $d$The pearl gourami comes from the peat swamps of Malaysia, Thailand, Sumatra and Borneo, where it is now listed as Near Threatened. It has a silvery-brown body covered in pearl-white spots, and males develop a deep red-orange throat and extended fins.

Peaceful, hardy and one of the best gouramis for a community tank, reaching 10-12 cm. It prefers a planted tank with floating plants and calm water. The male builds a bubble nest and guards the eggs. Feed flake, pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Trichopodus leerii$n$;

UPDATE species_profile SET description = $d$The three-spot gourami comes from South-East Asia, from the Mekong basin to Indonesia. The name comes from two dark spots on the body plus the eye; blue, gold and opaline forms are bred.

Hardy and adaptable, reaching about 12-15 cm. Males can be aggressive toward other gouramis and each other, so keep one male per tank with a planted layout. The male builds a bubble nest and guards the eggs. Feed flake, pellets and frozen foods.$d$
 WHERE scientific_name = $n$Trichopodus trichopterus$n$;

UPDATE species_profile SET description = $d$The sparkling gourami, or pygmy gourami, is a tiny labyrinth fish from the paddies and swamps of Thailand, Cambodia, Laos and Vietnam. It has a brown-gold body with blue-green spangles and red-edged fins. Males make an audible croaking sound when displaying.

Peaceful and suited to nano tanks, reaching about 3-4 cm. Keep in a planted tank with floating plants and calm water. The male builds a small bubble nest under a leaf. Feed fine flake and small frozen foods.$d$
 WHERE scientific_name = $n$Trichopsis pumila$n$;

UPDATE species_profile SET description = $d$The salvini is a Central American cichlid from southern Mexico, Guatemala and Belize. It has a yellow body with black lateral stripes, turquoise spangling on the fins and a red belly. Males have more pointed fins.

A medium-sized cichlid, about 15 cm, that is territorial and aggressive for its size and needs tankmates that can stand up for themselves. It does not dig heavily. Pairs spawn on flat stones and guard the young. Feed pellets, flake and meaty frozen foods.$d$
 WHERE scientific_name = $n$Trichromis salvini$n$;

UPDATE species_profile SET description = $d$The lambchop rasbora is from south-eastern Thailand and Cambodia. It resembles a smaller, slimmer harlequin, with a copper-orange body and a thinner black patch shaped like a lamb chop.

Peaceful and suited to nano and planted tanks, reaching about 3 cm. Keep a group of eight or more. Pairs lay eggs on the underside of broad leaves. Feed fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Trigonostigma espei$n$;

UPDATE species_profile SET description = $d$The harlequin rasbora comes from peat-swamp streams in Malaysia, southern Thailand, Singapore and Sumatra. It has a coppery-orange body and a black triangular 'pork chop' patch from mid-body to tail. Males have a sharper, straighter lower edge to the patch; females are rounder and slightly larger.

An upper-to-mid-water schooler that looks best in a group of eight or more in a planted tank with open swimming room. Peaceful and a good match for other small community fish. Pairs lay eggs on the underside of broad leaves such as Cryptocoryne. Feeds on fine flake, micro-pellets and small frozen foods.$d$
 WHERE scientific_name = $n$Trigonostigma heteromorpha$n$;

UPDATE species_profile SET description = $d$The redhead cichlid is a large Central American cichlid from the Usumacinta basin of Guatemala, Mexico and Belize. Adult males show a red to purple head, a yellow-green body with dark blotches, and a nuchal hump.

Grows to around 30 cm and needs a large tank. Aggressive, particularly when breeding, and best with other large Central Americans. It eats a lot of vegetable matter in the wild, so its diet should include spirulina-based pellets and blanched greens alongside protein. Pairs are devoted parents.$d$
 WHERE scientific_name = $n$Vieja synspila$n$;

UPDATE species_profile SET description = $d$The swordtail is a Central American livebearer from Mexico to Honduras. Adult males grow a long, sword-shaped extension to the lower lobe of the tail; females are larger and lack it. Red, green, marigold, pineapple, black and wagtail forms are common.

Active and peaceful, but males can be quarrelsome with each other. It likes hard water and room to swim, and it jumps. Females drop fry regularly. Feed flake, vegetable matter and frozen foods.$d$
 WHERE scientific_name = $n$Xiphophorus hellerii$n$;

UPDATE species_profile SET description = $d$The platy is a small Central American livebearer from Mexico, Guatemala and Belize. Mickey mouse, sunset, wagtail, red, blue and tuxedo forms are bred in huge numbers. Males are smaller and carry a gonopodium.

Peaceful, hardy and tolerant of a wide range of hard water, making it one of the best first fish. Keep more females than males. Females drop fry about every month. Feed flake, vegetable matter and small frozen foods.$d$
 WHERE scientific_name = $n$Xiphophorus maculatus$n$;
