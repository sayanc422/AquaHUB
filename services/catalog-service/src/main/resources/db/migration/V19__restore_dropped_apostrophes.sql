-- V17's text lost its apostrophes: "Keralas own river barb", "Endlers
-- Livebearer", "Agassizs Dwarf Cichlid". The generator that wrote V17 held
-- the prose in single-quoted Python literals and wrote Kerala''s meaning an
-- escaped quote -- but in Python that is two adjacent literals, 'Kerala' 's',
-- concatenated to "Keralas". It only showed up on the rendered page. V17 has
-- been applied, so this corrects forward rather than editing it.

UPDATE product SET name = 'Denison Barb (Miss Kerala)', summary = 'Captive-bred only. Kerala''s own river barb -- endangered in the wild. Needs cool, fast, clean water and a long tank.' WHERE sku = 'FSH-BRB-06';
UPDATE product SET name = 'Lambchop Rasbora', summary = 'Tank-bred. The harlequin''s smaller, more orange cousin. For nano and planted tanks.' WHERE sku = 'FSH-RAS-03';
UPDATE product SET name = 'Molly, Assorted (Black, Dalmatian, Gold Dust)', summary = 'Tank-bred. Colours vary. A hard-water fish that likes India''s hard tap water better than most tropicals.' WHERE sku = 'FSH-LIV-02';
UPDATE species_profile SET common_name = 'Platy', care_notes = 'Small, hardy and cheerful, and among the best fish for a child''s first tank. Happy in hard water and a wide temperature range. Keep two or three females per male so no female is chased constantly. Expect fry every month in a mixed group.' WHERE scientific_name = 'Xiphophorus maculatus';
UPDATE product SET name = 'Endler''s Livebearer', summary = 'Tank-bred. A smaller, wilder-looking relative of the guppy with neon colours. Nano and shrimp tank friendly.' WHERE sku = 'FSH-LIV-05';
UPDATE species_profile SET common_name = 'Endler''s Livebearer' WHERE scientific_name = 'Poecilia wingei';
UPDATE product SET name = 'Agassiz''s Dwarf Cichlid', summary = 'Tank-bred. Flame red, double red and gold forms. One male with two or three females, and a cave each.' WHERE sku = 'FSH-DWC-03';
UPDATE species_profile SET common_name = 'Agassiz''s Dwarf Cichlid' WHERE scientific_name = 'Apistogramma agassizii';
UPDATE product SET name = 'Cockatoo Dwarf Cichlid', summary = 'Tank-bred. The male''s dorsal fin rises like a cockatoo''s crest. Hardier than most Apistogramma.' WHERE sku = 'FSH-DWC-04';
UPDATE product SET name = 'Jack Dempsey', summary = 'Tank-bred. Dark body covered in blue-green spangles. Grows to 25 cm and earns its boxer''s name.' WHERE sku = 'FSH-CAM-08';
UPDATE product SET name = 'Emerald Green Cory', summary = 'Tank-bred. A large, metallic-green cory that takes India''s summer heat better than most.' WHERE sku = 'FSH-COR-09';
