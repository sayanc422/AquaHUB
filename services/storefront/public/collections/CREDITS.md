# Collection photograph provenance

The homepage's "Collections" panels (`collections` in `src/views.ts`) choose their own photographs,
because a collection panel has a fixed shape and the section's 16:9 scene photo is the wrong one for
it. Most panels reuse a product photograph already recorded in `../species/CREDITS.md`:

| Panel | File | Recorded in |
|---|---|---|
| Arowana (panorama) | `species/asian-arowana-red-tail-golden.jpg` | `../species/CREDITS.md` |
| Badis & Dario | `species/scarlet-badis.jpg` | `../species/CREDITS.md` |
| Goldfish | `species/ryukin-goldfish.jpg` | `../species/CREDITS.md` |

Files that live in this directory are listed below. The protocol is the same as the species and
section tables: queried the Commons API, `extmetadata.LicenseShortName` read off the actual
response, `Restrictions` confirmed empty, artist from `extmetadata.Artist`, CC0 / public domain /
CC-BY / CC-BY-SA only. The caption was read as well as the thumbnail, per `agent_learningz.md`.

| File | Panel | Source | Licence | Notes |
|---|---|---|---|---|
| `betta-female-crowntail.jpg` | Bettas & Gouramis | Wikimedia Commons, [File:Betta splendens (w) dunkelrot ct.JPG](https://commons.wikimedia.org/wiki/File:Betta_splendens_(w)_dunkelrot_ct.JPG), DefenderRegina, 16 March 2010 | Public domain (PD-self) | ✅ Caption "Kampffischweibchen (betta splendens) dunkelrot var. Crowntail" (female, dark red, crowntail), filed under *Betta splendens (female)*, which matches the photo: a dark-bodied female with red crowntail fins. Source 3072×2304 (4:3), downscaled with Lanczos to 1600×1200, not cropped. Chosen on 28 September 2026 at the owner's request for a betta that fits a tile uncropped; replaces the section photo `sections/anabantoids.jpg` in this panel only. |
