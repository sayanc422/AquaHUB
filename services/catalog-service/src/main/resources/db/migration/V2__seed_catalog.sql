-- Seed data. Real care parameters, rounded to the ranges a shop would publish.
-- Prices are in minor units of INR (paise).

INSERT INTO category (slug, name, description, sort_order) VALUES
 ('livestock-fish',    'Freshwater Fish',   'Tank-bred and responsibly sourced community and species-tank fish.', 10),
 ('livestock-inverts', 'Shrimp and Snails', 'Dwarf shrimp, nerites and other clean-up crew.',                     20),
 ('plants',            'Live Plants',       'Tissue-cultured and potted aquatic plants.',                         30),
 ('hardscape',         'Hardscape',         'Wood, stone and substrate for aquascaping.',                         40),
 ('equipment',         'Equipment',         'Filtration, heating, lighting and test kits.',                       50),
 ('food',              'Fish Food',         'Dry, frozen and live foods.',                                        60);

-- ---------------------------------------------------------------- species --

INSERT INTO species_profile
 (scientific_name, common_name, max_size_cm, min_tank_litres, min_group_size,
  temp_min_c, temp_max_c, ph_min, ph_max, dgh_min, dgh_max,
  temperament, care_level, diet, plant_safe, care_notes) VALUES

 ('Paracheirodon innesi','Neon Tetra',3.5,60,8,20.0,26.0,5.5,7.5,2.0,10.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'Schooling tetra that colours up best over dark substrate with floating cover. Keep in groups of eight or more; smaller groups shoal loosely and stay pale. Sensitive to sudden pH swings during acclimatisation.'),

 ('Paracheirodon axelrodi','Cardinal Tetra',5.0,80,8,23.0,28.0,4.6,6.8,1.0,8.0,
  'PEACEFUL','INTERMEDIATE','OMNIVORE',TRUE,
  'Warmer and softer water than the neon tetra, and less tolerant of hard tap water. Wild-caught stock needs a long, slow drip acclimatisation.'),

 ('Betta splendens','Betta (male)',7.0,20,1,24.0,28.0,6.0,7.5,3.0,12.0,
  'AGGRESSIVE','BEGINNER','CARNIVORE',TRUE,
  'One male per tank. Labyrinth organ means it breathes surface air, so surface agitation should stay gentle. Long finnage is easily torn by fin-nipping tankmates.'),

 ('Poecilia reticulata','Guppy',4.0,40,3,22.0,28.0,7.0,8.2,8.0,20.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'Livebearer that prefers harder, alkaline water. Breeds readily, so a mixed-sex group multiplies fast; stock males only unless you want fry.'),

 ('Trigonostigma heteromorpha','Harlequin Rasbora',4.5,60,8,22.0,27.0,6.0,7.5,2.0,12.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'Hardy mid-water schooler, an easier alternative to cardinal tetras in slightly harder water.'),

 ('Corydoras panda','Panda Cory',5.0,60,6,20.0,25.0,6.0,7.4,2.0,12.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'Bottom dweller that needs smooth sand or rounded gravel; sharp substrate erodes barbels. Dislikes temperatures above 26C for long periods.'),

 ('Otocinclus vittatus','Otocinclus',4.0,60,6,21.0,26.0,6.0,7.5,3.0,12.0,
  'PEACEFUL','INTERMEDIATE','HERBIVORE',TRUE,
  'Only for mature, established tanks with visible biofilm and algae; starves in a new setup. Supplement with blanched vegetables.'),

 ('Ancistrus cirrhosus','Bristlenose Pleco',13.0,120,1,22.0,27.0,6.0,7.8,4.0,16.0,
  'PEACEFUL','BEGINNER','HERBIVORE',FALSE,
  'Needs driftwood to rasp for dietary lignin. Produces a heavy waste load, so budget filtration for it rather than treating it as a cleaner.'),

 ('Pangio kuhlii','Kuhli Loach',10.0,80,5,24.0,28.0,5.5,7.0,2.0,10.0,
  'PEACEFUL','INTERMEDIATE','OMNIVORE',TRUE,
  'Nocturnal and burrowing; needs sand and hiding places or it will not be seen. Escapes through uncovered filter intakes and open lids.'),

 ('Danio rerio','Zebra Danio',5.0,60,6,18.0,25.0,6.5,7.5,5.0,16.0,
  'SEMI_AGGRESSIVE','BEGINNER','OMNIVORE',TRUE,
  'Fast, active and tolerant of cooler water. Will nip slow, long-finned tankmates such as male bettas.'),

 ('Caridina multidentata','Amano Shrimp',5.0,40,3,18.0,27.0,6.5,7.8,4.0,16.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'The most effective algae-grazing invertebrate for planted tanks. Copper-based medications are lethal; check treatments before dosing.'),

 ('Neocaridina davidi','Cherry Shrimp',3.0,20,6,18.0,28.0,6.5,8.0,4.0,14.0,
  'PEACEFUL','BEGINNER','OMNIVORE',TRUE,
  'Breeds in the aquarium and needs stable dGH for moulting. Eaten by most fish large enough to fit them in their mouth.');

-- --------------------------------------------------------------- products --

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', TRUE, c.id, s.id
FROM (VALUES
 ('FSH-NEO-01','neon-tetra','Neon Tetra','Classic blue-and-red community schooler, tank-bred.',            7500,'Paracheirodon innesi'),
 ('FSH-CAR-01','cardinal-tetra','Cardinal Tetra','Deeper red than the neon, for soft warm water.',        14000,'Paracheirodon axelrodi'),
 ('FSH-BET-01','betta-male-halfmoon','Betta, Male Halfmoon','Individually housed, photographed on request.',45000,'Betta splendens'),
 ('FSH-GUP-01','guppy-male-trio','Guppy, Male Trio','Three males, mixed strains, hard-water friendly.',    36000,'Poecilia reticulata'),
 ('FSH-HAR-01','harlequin-rasbora','Harlequin Rasbora','Hardy schooler with a copper body and black wedge.',9000,'Trigonostigma heteromorpha'),
 ('FSH-COR-01','panda-cory','Panda Cory','Bottom-dwelling shoaler for sand substrate.',                   22000,'Corydoras panda'),
 ('FSH-OTO-01','otocinclus','Otocinclus','Small algae grazer for mature planted tanks.',                  18000,'Otocinclus vittatus'),
 ('FSH-BNP-01','bristlenose-pleco','Bristlenose Pleco','Wood-rasping pleco that stays under 15 cm.',       35000,'Ancistrus cirrhosus'),
 ('FSH-KUH-01','kuhli-loach','Kuhli Loach','Eel-like nocturnal loach for sand and caves.',                19000,'Pangio kuhlii'),
 ('FSH-ZEB-01','zebra-danio','Zebra Danio','Fast, cool-water tolerant schooler.',                          8000,'Danio rerio'),
 ('INV-AMA-01','amano-shrimp','Amano Shrimp','The benchmark algae-eating shrimp for planted tanks.',      25000,'Caridina multidentata'),
 ('INV-CHE-01','cherry-shrimp','Cherry Shrimp','Colony-forming dwarf shrimp, grade-sorted.',              12000,'Neocaridina davidi')
) AS v(sku, slug, name, summary, price_minor, sci)
JOIN species_profile s ON s.scientific_name = v.sci
JOIN category c ON c.slug = CASE WHEN v.sku LIKE 'INV-%' THEN 'livestock-inverts' ELSE 'livestock-fish' END;

INSERT INTO product (sku, slug, name, summary, price_minor, currency, is_livestock, category_id, species_profile_id)
SELECT v.sku, v.slug, v.name, v.summary, v.price_minor, 'INR', FALSE, c.id, NULL
FROM (VALUES
 ('PLT-ANU-01','anubias-nana-petite','Anubias Nana Petite','Slow-growing rhizome plant; tie to wood, never bury the rhizome.', 45000,'plants'),
 ('PLT-CRY-01','cryptocoryne-wendtii','Cryptocoryne Wendtii','Undemanding rosette plant; expect melt after transplanting.',    28000,'plants'),
 ('PLT-VAL-01','vallisneria-nana','Vallisneria Nana','Fast background runner for a low-tech tank.',                            22000,'plants'),
 ('HRD-SPI-01','spiderwood-medium','Spiderwood, Medium','Branching hardscape wood, 25-35 cm, pre-soaked.',                     65000,'hardscape'),
 ('HRD-SEI-01','seiryu-stone-5kg','Seiryu Stone, 5 kg','Angular aquascaping stone. Raises dGH and pH over time.',              90000,'hardscape'),
 ('EQP-FIL-01','canister-filter-400lph','Canister Filter 400 L/h','External filter for tanks up to 120 litres.',             450000,'equipment'),
 ('EQP-HTR-01','heater-100w','Aquarium Heater 100 W','Thermostatic heater for tanks up to 100 litres.',                      120000,'equipment'),
 ('EQP-TST-01','master-test-kit','Master Test Kit','Liquid tests for pH, ammonia, nitrite and nitrate.',                     185000,'equipment'),
 ('FOD-FLK-01','community-flake-100g','Community Flake, 100 g','Staple flake for mid-water omnivores.',                       32000,'food'),
 ('FOD-WAF-01','algae-wafers-250g','Algae Wafers, 250 g','Sinking wafers for plecos and otocinclus.',                         41000,'food'),
 ('FOD-BLW-01','frozen-bloodworm-100g','Frozen Bloodworm, 100 g','Blister-packed conditioning food. Cold chain on delivery.',  38000,'food')
) AS v(sku, slug, name, summary, price_minor, cat)
JOIN category c ON c.slug = v.cat;
