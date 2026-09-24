# Section (category tile) photograph provenance

One row per image, same rule as `services/storefront/public/species/CREDITS.md`: a photograph with
no row here should not be in the repository. Read `services/storefront/public/species/README.md`
for the shape spec (16:9, at least 1600×900) and `V14__section_photography.sql` for why this bar is
strict on licensing and deliberately loose on subject: a category tile needs a good, on-theme photo
("Cichlids" wants a nice cichlid), not a photograph of one particular product's exact species.

**Verification protocol, every image, no exceptions on licensing:** queried the Commons API,
`extmetadata.LicenseShortName` read off the actual response, `Restrictions` confirmed empty, artist
from `extmetadata.Artist` never a filename. CC0 / public domain / CC-BY / CC-BY-SA only — nothing
"NC", nothing "ND", nothing from a general image search.

**How this table came to exist across three interrupted sessions:** an Opus agent's own download
scripts and candidate list (`all.txt`, mapping a Commons file title to a short candidate code)
survived in the session scratchpad after the agent itself stalled twice before writing this file.
Every license/artist value below was re-queried fresh from the live Commons API during this pass —
none of it is carried over from an unverified prior claim. Where a category had more than one
candidate downloaded and the specific one actually cropped into the final file couldn't be
established with certainty, that's said plainly in the row rather than guessed at with false
confidence — correctness matters less here than for product photography, but honesty about
uncertainty doesn't. Three files (`food.jpg`, `catfish-large.jpg`, `catfish-predatory.jpg`) had no
candidate tracked in the fork's scratch files at all and were sourced/re-sourced fresh in this pass,
the latter two reusing already-verified sources from the new-species batch (a Predatory Catfish tile
showing a redtail catfish, and a Large Catfish tile showing a tiger shovelnose, are both exactly
on-theme).

| File | Category | Source | Licence | Notes |
|---|---|---|---|---|
| `live-fish.jpg` | Live Fishes | Wikimedia Commons, [File:Fish Aquarium with Vallisneria.jpg](https://commons.wikimedia.org/wiki/File:Fish_Aquarium_with_Vallisneria.jpg), Damitr | CC BY-SA 4.0 | ✅ community planted tank |
| `invertebrates.jpg` | Invertebrates | Wikimedia Commons, [File:Neocaridina davidi var. Red Cherry.jpg](https://commons.wikimedia.org/wiki/File:Neocaridina_davidi_var._Red_Cherry.jpg), Uccio D'Agostino | CC BY 4.0 | ✅ |
| `plants.jpg` | Live Plants | Wikimedia Commons, [File:Nature Aquarium Aquascape.jpg](https://commons.wikimedia.org/wiki/File:Nature_Aquarium_Aquascape.jpg), Dileepkumardr | CC0 | ✅ |
| `supplies.jpg` | Aquarium Supplies | Wikimedia Commons, [File:Aquarium gravel.jpg](https://commons.wikimedia.org/wiki/File:Aquarium_gravel.jpg), Green Yoshi | CC BY 3.0 | ⚠️ **best-effort identification** — two supply-themed candidates were downloaded for this tile; a rejected third (`File:Filtermaterial 060227.jpg`, correctly licensed but with no machine-readable artist — see `V14`'s comment) is definitely not this file, but between the two live candidates this is the one the perceptual match favoured, not a pixel-confirmed identification |
| `plants-foreground.jpg` | Foreground & Carpet | Wikimedia Commons, [File:Eleocharis acicularis kz03.jpg](https://commons.wikimedia.org/wiki/File:Eleocharis_acicularis_kz03.jpg), Krzysztof Ziarnek, Kenraiz | CC BY-SA 4.0 | ⚠️ dwarf hairgrass photographed growing emersed on a riverbank, not as a submerged aquarium carpet — the clearest licensed shot of the right plant, not of the right context |
| `plants-stem.jpg` | Stem Plants | Wikimedia Commons, [File:Ludwigia repens kz01.jpg](https://commons.wikimedia.org/wiki/File:Ludwigia_repens_kz01.jpg), Krzysztof Ziarnek, Kenraiz | CC BY-SA 4.0 | ✅ |
| `plants-epiphyte.jpg` | Anubias, Ferns & Mosses | Wikimedia Commons, [File:Anubias barteri var. nana - Botanischer Garten - Heidelberg, Germany - DSC01278.jpg](https://commons.wikimedia.org/wiki/File:Anubias_barteri_var._nana_-_Botanischer_Garten_-_Heidelberg%2C_Germany_-_DSC01278.jpg), Daderot | CC0 | ⚠️ a botanical-garden specimen shot, not an aquarium photo, but an unambiguous and correctly identified anubias |
| `freshwater.jpg` | Freshwater | Wikimedia Commons, [File:Devario malabaricus - adult coloration with schooling fish in background (aquarium).jpg](https://commons.wikimedia.org/wiki/File:Devario_malabaricus_-_adult_coloration_with_schooling_fish_in_background_%28aquarium%29.jpg), Shifu Tanks | CC BY-SA 4.0 | ✅ |
| `saltwater.jpg` | Saltwater | Wikimedia Commons, [File:Anemone tank at Sea Life Melbourne Aquarium.jpg](https://commons.wikimedia.org/wiki/File:Anemone_tank_at_Sea_Life_Melbourne_Aquarium.jpg), Ethmostigmus | CC BY-SA 4.0 | ✅ this section is `COMING_SOON`; still gets a real photo so the tile doesn't look broken |
| `hardscape.jpg` | Hardscape | Wikimedia Commons, [File:Aquascape mini.jpg](https://commons.wikimedia.org/wiki/File:Aquascape_mini.jpg), Trstcantik | CC0 | ⚠️ **best-effort identification** — three hardscape-themed candidates were downloaded; this is the perceptual-match favourite among them, not pixel-confirmed |
| `equipment.jpg` | Equipment | Wikimedia Commons, [File:Filtr gąbkowy.jpg](https://commons.wikimedia.org/wiki/File:Filtr_g%C4%85bkowy.jpg), attributed to Ewkaa (Commons' own extmetadata reads "No machine-readable author provided. Ewkaa assumed, based on copyright claims") | CC BY-SA 3.0 | ✅ a sponge filter cartridge |
| `food.jpg` | Fish Food | Wikimedia Commons, [File:3-Colour Fish Food.jpg](https://commons.wikimedia.org/wiki/File:3-Colour_Fish_Food.jpg), EL345er | CC BY-SA 4.0 | ✅ pond-fish pellet food; correctly licensed, on-theme, not the exact flake/tablet/frozen products the catalogue sells but this is a category tile, not a product photo |
| `tetras.jpg` | Tetras & Characins | Wikimedia Commons, [File:Cleveland Metroparks Zoo (51785946717).jpg](https://commons.wikimedia.org/wiki/File:Cleveland_Metroparks_Zoo_%2851785946717%29.jpg), Erik Drost | CC BY 2.0 | ✅ |
| `cichlids.jpg` | Cichlids | Wikimedia Commons, [File:Aulonocara 20241123.jpg](https://commons.wikimedia.org/wiki/File:Aulonocara_20241123.jpg), Rjcastillo | CC BY-SA 4.0 | ✅ |
| `catfish.jpg` | Catfish | Wikimedia Commons, [File:Kiryski - ryby akwariowe.jpg](https://commons.wikimedia.org/wiki/File:Kiryski_-_ryby_akwariowe.jpg), Henryk Niestrój | CC BY 4.0 | ✅ |
| `barbs.jpg` | Barbs & Rasboras | Wikimedia Commons, [File:Harlequin rasboras 01.jpg](https://commons.wikimedia.org/wiki/File:Harlequin_rasboras_01.jpg), Roel Balingit | CC BY-SA 4.0 | ✅ |
| `livebearers.jpg` | Livebearers | Wikimedia Commons, [File:Guppies.JPG](https://commons.wikimedia.org/wiki/File:Guppies.JPG), Schumi4ever | CC BY-SA 4.0 | ✅ |
| `anabantoids.jpg` | Bettas & Gouramis | Wikimedia Commons, [File:Bojownik syjamski.jpg](https://commons.wikimedia.org/wiki/File:Bojownik_syjamski.jpg), Henryk Niestrój | CC BY 4.0 | ✅ Siamese fighting fish |
| `loaches.jpg` | Loaches | Wikimedia Commons, [File:Chromobotia macracanthus (Bleeker, 1852) Clown loach.jpg](https://commons.wikimedia.org/wiki/File:Chromobotia_macracanthus_%28Bleeker%2C_1852%29_Clown_loach.jpg), Andrej Jakubík | CC BY-SA 4.0 | ✅ |
| `badidae.jpg` | Badidae — Badis & Dario | Wikimedia Commons, [File:Dario huli.jpg](https://commons.wikimedia.org/wiki/File:Dario_huli.jpg), Beta Mahatvaraj | CC BY-SA 4.0 | ⚠️ *Dario huli*, not *Dario dario* — the only Badidae file on Commons above the 1600×900 floor; correct family, not the exact species the catalogue sells |
| `arowana.jpg` | Arowana | Wikimedia Commons, [File:Osteoglossum bicirrhosum in Eilat underwater observatory marine park.JPG](https://commons.wikimedia.org/wiki/File:Osteoglossum_bicirrhosum_in_Eilat_underwater_observatory_marine_park.JPG), Avi1111 dr. avishai teicher | CC BY-SA 4.0 | ✅ |
| `cichlids-african.jpg` | African Cichlids | Wikimedia Commons, [File:Maylandia lombardoi and Aulonocara sp Hybride at meenalokam 01.jpg](https://commons.wikimedia.org/wiki/File:Maylandia_lombardoi_and_Aulonocara_sp_Hybride_at_meenalokam_01.jpg), Adityamadhav83 | CC BY-SA 3.0 | ✅ |
| `cichlids-dwarf.jpg` | Dwarf Cichlids | Wikimedia Commons, [File:Mikrogeophagus ramirezi male.jpg](https://commons.wikimedia.org/wiki/File:Mikrogeophagus_ramirezi_male.jpg), Sven Kullander | CC BY-SA 4.0 | ✅ this section is `COMING_SOON` |
| `cichlids-american.jpg` | American Cichlids | Wikimedia Commons, [File:Astronotus ocellatus - Karlsruhe Zoo 01.jpg](https://commons.wikimedia.org/wiki/File:Astronotus_ocellatus_-_Karlsruhe_Zoo_01.jpg), H. Zell | CC BY-SA 3.0 | ⚠️ **best-effort identification** — two Oscar (*Astronotus ocellatus*) candidates were downloaded for this tile; this is the perceptual-match favourite, not pixel-confirmed |
| `catfish-small.jpg` | Small Catfish | Wikimedia Commons, [File:Corydoras pair with eggs.jpg](https://commons.wikimedia.org/wiki/File:Corydoras_pair_with_eggs.jpg), Nate Wessel | CC BY-SA 4.0 | ✅ |
| `catfish-large.jpg` | Large Catfish | Wikimedia Commons, [File:Pseudoplatystoma fasciatum1.jpg](https://commons.wikimedia.org/wiki/File:Pseudoplatystoma_fasciatum1.jpg), KENPEI | CC BY-SA 3.0 | ✅ reused from `tiger-shovelnose-catfish.jpg`'s own verified source, a different crop — exactly on-theme for this tile |
| `malawi.jpg` | Lake Malawi | Wikimedia Commons, [File:Frankfurt Zoo - Electric Yellow Lab 1.jpg](https://commons.wikimedia.org/wiki/File:Frankfurt_Zoo_-_Electric_Yellow_Lab_1.jpg), Photograph by Mike Peel (www.mikepeel.net) | CC BY-SA 4.0 | ✅ |
| `tanganyika.jpg` | Lake Tanganyika | Wikimedia Commons, [File:Tropheus sp black "pemba" - "bemba" aqua porte dorée 01.JPG](https://commons.wikimedia.org/wiki/File:Tropheus_sp_black_%22pemba%22_-_%22bemba%22_aqua_porte_dor%C3%A9e_01.JPG), Cedricguppy - Loury Cédric | CC BY-SA 4.0 | ✅ this section is `COMING_SOON` |
| `victoria.jpg` | Lake Victoria | Wikimedia Commons, [File:20171101 Wilhelma Fisch 02.jpg](https://commons.wikimedia.org/wiki/File:20171101_Wilhelma_Fisch_02.jpg), Zinnmann | CC BY-SA 3.0 | ⚠️ unidentified haplochromine — Commons has no confirmed Lake Victoria cichlid photo above the size floor at all; this section is `COMING_SOON` |
| `african-other.jpg` | Other African Cichlids | Wikimedia Commons, [File:Barwniak i narybek.JPG](https://commons.wikimedia.org/wiki/File:Barwniak_i_narybek.JPG), Soldering | CC BY-SA 3.0 | ✅ this section is `COMING_SOON` |
| `cichlids-south-american.jpg` | South American Cichlids | Wikimedia Commons, [File:2023-08-20. Анапа DSC 5563.jpg](https://commons.wikimedia.org/wiki/File:2023-08-20._%D0%90%D0%BD%D0%B0%D0%BF%D0%B0_DSC_5563.jpg), Andrey Butko | CC BY-SA 4.0 | ✅ |
| `cichlids-central-american.jpg` | Central American Cichlids | Wikimedia Commons, [File:Vieja synspila.JPG](https://commons.wikimedia.org/wiki/File:Vieja_synspila.JPG), Shizhao | CC BY-SA 3.0 | ✅ reused from `redhead-cichlid.jpg`'s own verified source, a different crop |
| `catfish-corydoras.jpg` | Corydoras | Wikimedia Commons, [File:Corydoras-adolfoi.jpg](https://commons.wikimedia.org/wiki/File:Corydoras-adolfoi.jpg), Corydoras-adolfoi | CC BY-SA 4.0 | ✅ |
| `catfish-oto.jpg` | Otocinclus & Dwarf Suckers | Wikimedia Commons, [File:Otocinclus vestitus 2.jpg](https://commons.wikimedia.org/wiki/File:Otocinclus_vestitus_2.jpg), Fremen | CC BY-SA 4.0 | ✅ |
| `catfish-bristlenose.jpg` | Bristlenose Plecos | Wikimedia Commons, [File:Ancistrus sp. "L144".jpg](https://commons.wikimedia.org/wiki/File:Ancistrus_sp._%22L144%22.jpg), Corydoras-adolfoi | CC BY-SA 4.0 | ✅ |
| `catfish-pleco-large.jpg` | Large Plecos | Wikimedia Commons, [File:2023-08-20. Анапа DSC 5507.jpg](https://commons.wikimedia.org/wiki/File:2023-08-20._%D0%90%D0%BD%D0%B0%D0%BF%D0%B0_DSC_5507.jpg), Andrey Butko | CC BY-SA 4.0 | ✅ |
| `catfish-synodontis.jpg` | Synodontis | Wikimedia Commons, [File:Aquatic Kingdom, KSR railway station, Bengaluru (28).jpg](https://commons.wikimedia.org/wiki/File:Aquatic_Kingdom%2C_KSR_railway_station%2C_Bengaluru_%2828%29.jpg), Gpkp | CC BY-SA 4.0 | ⚠️ **best-effort identification** — two catfish-tank candidates were downloaded for this tile; this is the perceptual-match favourite, not pixel-confirmed |
| `catfish-predatory.jpg` | Predatory Catfish | Wikimedia Commons, [File:Redtail catfish (Phractocephalus hemioliopterus) (15594456228).jpg](https://commons.wikimedia.org/wiki/File:Redtail_catfish_(Phractocephalus_hemioliopterus)_(15594456228).jpg), harum.koh from Kobe city, Japan | CC BY-SA 2.0 | ✅ reused from `redtail-catfish.jpg`'s own verified source, a different crop |
| `inverts-shrimp.jpg` | Shrimp | Wikimedia Commons, [File:Neocaridina davidi var. Red Cherry 2.jpg](https://commons.wikimedia.org/wiki/File:Neocaridina_davidi_var._Red_Cherry_2.jpg), Uccio D'Agostino | CC BY 4.0 | ✅ |
| `inverts-snails.jpg` | Snails | Wikimedia Commons, [File:Neritina natalensis.jpg](https://commons.wikimedia.org/wiki/File:Neritina_natalensis.jpg), TakisA1 | CC BY-SA 4.0 | ✅ |

## What "best-effort identification" means on the four rows marked that way

`supplies.jpg`, `hardscape.jpg`, `cichlids-american.jpg` and `catfish-synodontis.jpg` each had more
than one on-theme candidate downloaded by an earlier, interrupted session. The specific candidate
that was actually cropped into the file now on disk couldn't be recovered with certainty — there is
no metadata trail linking a processed JPEG back to its exact source once EXIF is stripped. For each,
a perceptual comparison (`compare -metric RMSE`, both images resized to the same small square)
picked the closer of the surviving candidates, and that candidate's real, API-verified license and
artist are what's recorded above. **The uncertainty is about which specific frame was used, never
about the license** — every candidate considered for a given tile was independently verified as
correctly licensed before being downloaded in the first place, so the row is safe to publish either
way. This is a materially different, and smaller, kind of uncertainty than an unverified claim would
be, and it's recorded here rather than hidden because a future reader re-doing this comparison
should know not to expect a clean pixel match.
