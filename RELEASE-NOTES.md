# Release notes

Newest first. Each entry says what was built, **what was measured**, and what is still unproven.
A number that has not been measured is written as a target and labelled as one.

---

## Storefront visual redesign: Apple-inspired, then corrected against real feedback (24 September 2026)

Four commits, all in `services/storefront`, no other service touched. The brief was explicit —
"make it look like apple.com... clean and elegant" — then refined twice more against what the user
actually saw running, which is most of what's worth recording here.

**Pass one:** full rewrite of `styles.css` around one set of CSS custom properties, light by
default with a real `prefers-color-scheme` dark mode (no theme picker, no JS). The `-apple-system`
font stack, large tight-tracked headlines, soft-shadow cards with a hover lift instead of hairline
borders, a pill-shaped primary button, a clean two-column spec-sheet layout for the care profile.
Added a homepage hero section that hadn't existed before (the h1/lede previously sat flush under
the nav with no room to breathe).

**Pass two, on explicit follow-up:** a hover dropdown for nav items with subcategories — the one
piece of the Apple reference this hadn't covered. `Live Fishes` has exactly one real child,
`Freshwater`, which is where the nine actual sections live, so `server.ts`'s `nav()` now fetches one
level deeper for any pass-through branch and flattens its children into the dropdown directly rather
than making a customer click through an extra page. Alongside it, a genuine mobile pass rather than
the single small media-query tweak that existed before: below 899px the nav collapses behind a
checkbox-hack hamburger toggle (no JavaScript, holding ADR 0005), and every dropdown that depended on
hover becomes an always-expanded inline list, since a touch screen has no hover to begin with.

**Pass three, on further feedback ("too much blank space," "the font is still small on PC"):**
background shifted from neutral grey-white to a faint blue tint (water), the accent from generic
blue to a planted-tank green — analogous hues, not competing ones. Product price hidden on the
homepage's six-or-seven-item shelf (`card()` takes a `showPrice` argument, false only there) since
that shelf is "here's what we carry," not a price list; every category page keeps it. Base
`font-size` raised twice over the three passes, 100% -> 112.5% -> 118.75%, the one property every
`rem` in the file scales from. And the actual fix behind "blank space": `.grid` and `.tiles` had
been CSS Grid with `auto-fill`/`auto-fit`, but a Grid's column count is fixed for the *whole* grid,
not recalculated per row — six product cards splitting 4-then-2 left the ragged second row's two
cards stranded at their base width with dead space beside them, because the grid still reserved the
four columns row one used. Switched both to flexbox with `flex-wrap`, which resizes each row's items
independently; capped `.card`/`.tile` at a `max-width` so a single card stranded alone on a wide
screen's last row grows generously rather than stretching to the full row.

### Measured

Verified against the live `full-app` cluster with a headless Chromium (`mcr.microsoft.com/playwright`
— this box has no browser and no working native Node on PATH; see `docs/getting-started-locally.md`'s
existing note about the PDF-render script for the same constraint). Checked the hover dropdown, the
mobile panel closed and open, a tablet-width category page, and — after the third pass — the home and
a category page at 1920px, 820px and 390px: **zero horizontal overflow at any of the six
configurations**, product grids fill their rows completely at desktop width, and the mobile hamburger
menu (unrelated to the font/color pass, but a global `font-size` change touches everything) still
opens and renders correctly.

Two apparent bugs surfaced during verification and neither was real, both worth recording because
the instinct to trust a screenshot over the live page would have cost real time chasing them:
`fullPage: true` screenshots interacting with `position: sticky` produced a hero heading that
appeared to overlap the nav bar, and an oversized fixed-height viewport (a workaround for the first
issue) produced faint ghost nav text above the footer. `getBoundingClientRect()` against the live DOM
and an ordinary scrolled, viewport-sized screenshot both showed a clean page in either case — see
`agent_learningz.md` for the general lesson.

### Still unproven

- No real device testing — every mobile/tablet check was a headless Chromium at a given viewport
  size, not an actual phone. Viewport emulation does not catch everything a real touch device would
  (address-bar show/hide reflow, momentum scrolling, real hover-vs-tap ambiguity on a tablet in
  landscape).
- The four-pass iteration was entirely against one person's stated taste and one screen. "Clean and
  elegant" and "fill the blank space" are not universal, measured properties.
<!-- BEGIN: custom tank enquiries (23 September 2026) -->
## Custom tank enquiries: the first table in this repository whose contents nobody can read

The shop front now has a section where a visitor writes, in their own words, what they want their
tank and its stocking to look like, and leaves an email address and a phone number so the shop can
answer. It is one of the shop's main offers, so it sits directly under the section tiles with a
permanent link in the site header, not in a footer.

Three decisions, one record:
[ADR 0021](docs/adr/0021-encrypt-enquiry-contact-details-in-postgres.md).

**It is not a ninth service.** `order-service` already owns "a customer told us what they want and
left an email address" — that is literally what `CustomerOrder.email` is — and it already has a
database, a Flyway sequence, a login role, an image, a deployment, a quota share and probes. The new
work is one table and one handler. The measured argument is in this file already: `full-app`'s eight
services came in at 2234 MiB against a 4 Gi namespace quota, `order-service`'s share being 229 MiB.
A ninth JVM for one write-mostly table does not earn that. **What it costs is blast-radius
isolation** — a checkout-saga defect or an `order-service` OOM now takes enquiries with it, and the
encryption key lives in a process that also handles payments. That is the same trade
[ADR 0003](docs/adr/0003-one-postgres-database-per-service.md) already made for databases, made
again, knowingly.

**Postgres encrypts it, not Java.** `V3__tank_inquiry.sql` creates `pgcrypto` and a table whose
`email`, `phone` **and** free-text message are `BYTEA` holding `pgp_sym_encrypt` output — AES-256,
compression off, because PGP compressing a message before encrypting it leaks content through
ciphertext length and saves nothing against a 4,000-character cap. The message is encrypted too, not
just the contact fields, because it is the field most likely to carry detail the form never asked
for ("deliver to 14 Park Street, ask for Priya"), and a column left in the clear because nobody
expected PII in it is exactly how PII ends up in the clear.

This is the same instinct as `payment-service`'s append-only ledger trigger, applied to secrecy
instead of immutability: an invariant that must not be lost belongs in the database, where the next
service, the next migration and a hand-typed `SELECT` all inherit it. `tank_inquiry` is deliberately
the only table in `order-service` that is **not** a JPA entity — a mapped entity with an
`AttributeConverter` would hold the decrypted address in Hibernate's first-level cache and its
dirty-check snapshot, which is the one thing this design exists to prevent.

### Measured

Everything below was run, against a real PostgreSQL 16, before it was written down.

**`CREATE EXTENSION pgcrypto` works as the non-superuser `orders` role.** This was the question that
could have changed the whole design, so it was answered first rather than assumed: pgcrypto has been
a *trusted* extension since PostgreSQL 13, so a database owner can create it without superuser.
Checked against the running k3d `postgres:16-alpine` as `orders` (the probe extension dropped again
straight afterwards, so the cluster was left as found), then proved for real when `V3` migrated
cleanly onto a fresh `orders_local` database owned by `orders`:

```
Migrating schema "public" to version "3 - tank inquiry"
Started OrderApplication in 6.325 seconds
```

Had it not been trusted, the extension would have needed a superuser step in
`postgres/init-configmap.yaml` and a new line in the add-a-service-database runbook.

**What is on disk is not the plaintext.** After a real submission through the form:

```
message_chars | 73
email_on_disk | \303\r\x04 \x03\x02\255\245\357\323\245I?\324y\322B\x01\377\326}\x18:%,…
pgp_sym_decrypt(email_enc,'<key>')  | priya@example.com
pgp_sym_decrypt(email_enc,'wrong')  | ERROR:  Wrong key or corrupt data
```

A wrong key raises rather than returning rubbish, which matters: it means a cluster rebuilt with a
fresh key fails loudly instead of handing someone mojibake they might mistake for a corrupt row.

**The same address encrypts differently every time.** A fresh session key and IV per call, so two
enquiries from one customer are not linkable without the key — and so there is no index and no
unique constraint on those columns, and "has this person written before?" is not answerable without
decrypting the table. That is the cost of the property that makes the ciphertext worth storing.

**A missing key stops the endpoint, not the service.** Reproduced against a real running jar, with
no `INQUIRY_ENCRYPTION_KEY` set at all:

```
readiness:            {"status":"UP"}
boot log:             WARN TankInquiryRepository - tank enquiries are DISABLED:
                        inquiries.encryption-key is not set (INQUIRY_ENCRYPTION_KEY).
                        Everything else in order-service is unaffected.
POST /v1/inquiries →  503 {"reason":"inquiries.encryption-key is not set (INQUIRY_ENCRYPTION_KEY)",
                           "runbook":"docs/runbooks/rotate-or-create-the-inquiry-key.md",
                           "affects":"tank enquiries only; checkout, carts and orders are unaffected"}
POST /v1/carts     →  201        PUT  /v1/carts/{id}/lines → 200
GET  /v1/carts/{id}→  200        GET  /actuator/prometheus → 200
```

A 7-character placeholder key behaves identically. Restoring a real key and restarting returns the
form to `303` and a decryptable row. Field validation still runs *ahead* of the key check, so a
malformed submission is still `400` rather than `503`.

**This is a reversal of the first shape of this feature, and the reasoning is the interesting
part.** It originally refused to start the Spring context without a key. `order-service` also owns
the checkout saga — the most hardened, most crash-tested, most k3d-verified path in this platform —
and letting a forgotten Kubernetes Secret for a bolt-on marketing form take commerce down is a blast
radius wildly out of proportion to the feature that caused it. **The reach of a failure should match
the size of the thing that failed.** Nothing about the safety property changed: no fallback key
either way, no plaintext written either way, no row accepted that cannot be encrypted either way.

A default key remains the option that was never on the table: it accepts submissions and writes rows
that *look* encrypted while being readable by anyone holding the source, and makes those same rows
permanently undecryptable the day a real key arrives — discovered, at the earliest, when someone
tries to phone a customer.

**Two things that only a real process would have caught.** `secretKeyRef` needs `optional: true` in
the deployment, or kubelet refuses to start a container whose env it cannot resolve and the pod sits
in `CreateContainerConfigError` with checkout down — the Java-side decision would have been moot.
And the `503` needed an explicit body: Spring drops the exception message unless
`server.error.include-message` is enabled globally, so the first version returned a bare
`{"status":503,"error":"Service Unavailable"}` that sent the reader to the logs of a service that
looks perfectly healthy. MockMvc's `getErrorMessage()` had hidden that; `curl` found it.

**End to end through the BFF**, with `order-service` and Postgres running locally and the storefront
talking to both: `POST /inquiries` → `303 See Other` →
`/inquiries/thanks?ref=a29ce2b8-…` → one row in `tank_inquiry`, decryptable with the key. An empty
message, a malformed email and prose in the phone field each come back `400` with the page
re-rendered and the customer's typed text still in the box. A junk `ref` query parameter is not
echoed onto the page at all.

**`order-service`: 77 tests, 34 skipped** without a DSN (up from 55/18 — the six new bean-validation
tests need no database), **77 tests, 0 skipped** with `ORDER_TEST_DSN` set. `TankInquiryTest` and
`InquiryKeyMissingTest` both follow `CheckoutSagaTest`'s existing DB-gated convention exactly. Three
of the 22 new tests are written to fail if someone changes the design without reading the ADR:
`whatIsOnDiskIsNotThePlaintext`, `thereIsNoWayToReadAnEnquiryBackOverHttp`, and
`theCommercePathIsCompletelyUnaffected`, which boots a context with no key and then exercises carts
to prove the saga side is untouched. **No existing test needed changing** — the key is not required
to start a context.

**`storefront`: `npm run build` (tsc) passes.** It gained its first body parser
(`@fastify/formbody` v7, the line that still supports Fastify 4), its first `POST` route, and its
first call to `order-service`. It has no test suite — a pre-existing gap, not a new one.

### Not measured, and unproven

**None of this has run in the k3d cluster.** The local run above used a throwaway Postgres container
and a locally-built jar with the cluster's `catalog-service` port-forwarded in for the home page.
The images have not been rebuilt, the manifests have not been applied, and nobody has submitted the
form through the ingress. That verification pass is the next thing that should happen, and it is
where this project has historically found the defects that review did not.

### What this does not solve

**Key management is better than the rest of this repository and still incomplete.**
`INQUIRY_ENCRYPTION_KEY` comes from a Secret (`order-inquiry-key`) created by hand and present in no
file here — the first secret in this repository that is not plaintext in Git, unlike
`platform-repo/dev/postgres/secret.yaml`, which still is. But there is **no rotation**: changing the
key orphans every existing row, permanently. There is **no secrets manager**: the value lives in one
shell history and in etcd, base64-encoded, which is encoding, not encryption.
[docs/runbooks/rotate-or-create-the-inquiry-key.md](docs/runbooks/rotate-or-create-the-inquiry-key.md)
is the whole procedure.

**And the failure is quiet — that is the price of the smaller blast radius.** A k3d cluster torn
down and rebuilt without the `kubectl create secret` step repeated comes up entirely green: every
pod `Running`, every probe passing, nothing in `kubectl get all` out of place, while the enquiry
form refuses every customer who uses it. The earlier crash-loop design was impossible to miss and
this one is not. The mitigation is three deliberately noisy things — one `WARN` at boot naming the
runbook, a `bootstrap.sh` warning before the `commerce` rollout, and a storefront message that says
"that is our fault, not yours" and tells the customer to email instead of retrying — and none of
them is as loud as a pod that will not start. **The trade was made knowingly: a feature that is off
is recoverable in one command, and a checkout path that is down is not.**

**The shop cannot read its own enquiries.** There is no `GET`, no list, no search — deliberately,
because this platform has no authentication anywhere and an unauthenticated read endpoint over this
table would make the encryption theatre. Today the only way to see a submission is `psql` plus the
key. **That is a gap, not a feature**: a form the shop cannot read is a form that does not work. The
honest fix is authentication first, then a `staff-portal` decrypt view, in that order.
`TankInquiryRepository.findById` exists and is exercised by tests so that path has a seam to build
on.

**A public, unauthenticated `POST` with no rate limiting.** No CAPTCHA, no per-IP limit, no
honeypot. A 16 KiB request-body limit at the BFF and a 4,000-character message cap bound what one
request can cost, not how many arrive. The right answer is `ingress-nginx`'s `limit-rps` annotation
or a WAF at the edge; a bespoke limiter written now would be an unreviewed security control.
**Anyone taking this past a local k3d demo must fix this first.**

**The `core` profile renders a form that cannot work.** `core` deploys the storefront without
`order-service`, so every submission there fails — honestly, with a 502 and the customer's text
kept, but it fails. This feature belongs to `commerce` and above.

<!-- END: custom tank enquiries -->

---

## The last 11 product slots filled by lowering the bar, on purpose — 55 of 55, none launch-eligible

The entry below left eleven products without a photograph and argued, correctly, that each one would
be worse filled than empty. That argument was about a shop that takes orders. This one does not and
never will — designed for AWS, validated with mock providers, run on k3d, never applied to an AWS
account — and the instruction here was explicit: fit the remaining eleven, dismiss the resolution and
structural constraints, make the website look complete. So the bar moved, deliberately, in one
direction only.

**What did not move: the licence.** Every candidate went through the Commons API exactly as the first
34 did — `extmetadata.LicenseShortName` read off the actual response, `Restrictions` confirmed empty,
artist from `extmetadata.Artist` rather than a filename, nothing containing "NC" or "ND", nothing
from a general web or stock-photo search. Relaxing quality is a judgement about how a demo looks;
publishing an unlicensed photograph is a different kind of problem.

### Measured

**11 of 11 closed; 55 of 55 products now carry a photograph, up from 44.** 1.9 MB added across eleven
files, 56–281 KB each, all under the 300 KB ceiling, all 4:3 (1400×1050, or 1200×900 for the two
heaviest upscales), all EXIF-stripped, progressive JPEG quality 80.
`V11__demo_complete_photography.sql` wires the keys in and states in its header why these are not
V9/V10's kind of image. Licences used: CC BY-SA 2.5/3.0/4.0 and CC BY 4.0.

What each one cost, because none of them was free:

- **Resolution — five Lanczos upscales.** `saulosi` 2.3× from 556×392 (the worst by a distance),
  `red-melon-badis` 1.92× from 701×468, `yellow-shrimp` 1.53× from 1024×685, the three food shots
  1.4× from 1000×1000, `seiryu-stone-5kg` 1.09× from 1452×962. An upscale invents no detail; it hides
  the shortfall behind interpolation. Every original dimension is recorded in `CREDITS.md`.
- **Identification — two genus-level IDs.** `bristlenose-pleco` is *Ancistrus* sp. and `otocinclus`
  is *Otocinclus* sp. Both products are sold under a species name the photograph does not carry, and
  neither fish is separable to species by eye, so this does not close with more looking.
- **Product form — four mismatches.** `frozen-bloodworm-100g` is freeze-dried, not frozen in a
  blister pack. `algae-wafers-250g` is tablets, not wafers. `seiryu-stone-5kg` is unidentified
  aquascaping rock already built into someone's layout, not Seiryu stone as a sellable object.
  `master-test-kit` is a teaching-lab test-tube rack and is not an aquarium test kit at all.
- **Trademark — one.** `canister-filter-400lph` carries a legible **FLUVAL 204** mark on a real Hagen
  product this shop does not sell, and it is the wrong flow rate besides. The entry below refused
  exactly this and its reasoning still holds — a CC licence disclaims trademark, so a verified
  licence is not clearance. This is the single row that would be a legal problem rather than a
  quality problem if this catalogue ever went live, and it is flagged that way in `CREDITS.md`, in
  `V11`'s header and in `CLAUDE.md`.
- **One synthetic background.** `canister-filter-400lph.jpg`'s source is portrait 975×2033 and the
  unit will not fit a 4:3 frame, so it was scaled to full height and composited over a blurred,
  desaturated copy of itself. The outer thirds of that image are not photographed background. It is
  the only file in `public/species/` that is not entirely photograph.

**`community-flake-100g` got better, not worse.** The candidate the entry below rejected was four
brand-dominated tubs of granulate. The broadened search turned up `File:Fischfutter-Flocken.JPG` —
actual flake, on plain white, no packaging and no brand mark anywhere in frame. The relaxation was
not needed for the reason it was granted.

**Broadening the search is what closed the three "nothing exists on Commons" cases**, and the
mechanism is worth recording: Commons full-text search is close to useless for retail objects.
"dragon stone aquarium", "ohko stone", "aquarium water testing" and "pool water test strips" returned
scanned Victorian aquarium manuals, Federal Register pages and US Army Corps of Engineers reports —
the same wall the previous pass hit. **Category listing found all three.**
`generator=categorymembers` on *Category:Aquascaping* produced the iwagumi layout,
*Category:Test tubes* the reagent rack, and *Category:Fish food* all three Buchling studio shots at
once. That last category had been read before and those three files were missed; they are 1000×1000
and would have failed the old resolution bar, which is presumably why. For objects rather than
organisms, list the category first and search second.

**Downloading and looking at every candidate still earns its keep**, and rejected three that passed
on API metadata alone: `File:Bioloog.JPG` is in *Category:Aquarium filters*, correctly licensed and
3008×2000 — and is a grimy home-built sump in a cabinet, nothing like a canister.
`File:Otocinclus ssp 21.jpg` is 4032×3024 and shows the fish belly-on from underneath.
`File:Colour gradient with solutions.jpg` is a plausible test-tube candidate whose lower half is an
empty bench top under a heavy pink cast.

The hand-drawn SVG fallback prepared for "nothing licensable exists even after broadening" was not
needed. Every one of the eleven found a real photograph once the acceptance bar moved.

### Still unproven

- ~~Nothing here has been rendered.~~ **Verified since.** `catalog-service` and `storefront` rebuilt,
  imported into the running `full-app` cluster, and redeployed; Flyway applied `V11` cleanly (log:
  `Migrating schema "public" to version "11 - demo complete photography"`). `/api/products` confirms
  all 55 products now carry a non-null `image_key`, all eleven new static assets return `200`, and
  every one renders an actual `<img>` tag on both its category card and its detail page — zero
  `<span class="shot shot-none">` placeholders remain anywhere in the catalogue. Not independently
  eyeballed in an actual browser, only via `curl` against the rendered HTML.
- `upload.wikimedia.org` began returning HTTP 429 on original files partway through, so
  `otocinclus`, `master-test-kit` and `frozen-bloodworm-100g` were built from Commons-rendered
  thumbnails (3840×2160, 1920×2560 and 960×959) rather than the originals. Same pixels, one more
  resampling step than the other eight had.
- "Nothing else on Commons" remains a statement about what was queried, now across both full-text
  search and category listing, not a proof of absence.
- No photograph in this batch has been checked by the shop owner, and four of the eleven are not
  photographs of the product being sold in any meaningful sense.

---

## The product detail page has never shown a photograph — found verifying the entry below

Verifying the two-image gap-reattempt below meant actually rebuilding `catalog-service` and
`storefront`, redeploying into the running `full-app` cluster, and loading the pages through the
ingress rather than trusting the migration text — this project's own rule. `V10` applied cleanly
(Flyway log: `Migrating schema "public" to version "10"`) and both `/api/products` and the category
page (`/c/malawi`, `/c/equipment`) rendered the two new images correctly. The product **detail**
page (`/p/:slug`) did not: `curl`'d against `demasoni`, one of the ten original shop photographs and
the most-verified image in the repository, it returned zero `<img>` tags. Every product page for
every one of the 44 photographed products has been rendering with no photograph since Phase 1 —
the card and tile templates call the shared `photo()` helper; `productPage()` in
`services/storefront/src/views.ts` never did.

### Measured

Fix is one line: `productPage()` now opens its `<article class="detail">` with
`${photo(p.imageKey, p.name, '4/3')}`, the same helper `card()` and `tile()` already use, so the
missing-key placeholder and the `onerror` fallback both come for free. Rebuilt `storefront`, imported
into k3d, rolled out, and re-curled three cases against the live cluster: `acei-yellow-tail` (has a
key, file exists) now renders `<img src="/static/species/acei-yellow-tail.jpg">`; `demasoni` (an
original photograph, unrelated to this session's changes) now renders its image too; `saulosi` (no
key) renders the `<span class="shot shot-none">` placeholder, not a broken `<img>`. No JavaScript
console or automated test caught this — `services/storefront` has no test suite (absent from
`CLAUDE.md`'s testing table), so this was only visible by requesting the actual page.

### Still unproven

- Not visually inspected in an actual browser, only via `curl` against the rendered HTML — the CSS
  (`.shot { object-fit: cover; ... }`) is shared with the already-working card/tile images, but the
  detail page's larger, standalone placement has not been eyeballed.
- No regression test exists to keep this failure mode from recurring; `services/storefront` remains
  entirely untested.

---

## Re-attempt at the 13 empty product slots: 2 closed, 11 still empty

The entry below left 13 products without a photograph and said so. This is the repeat search it
invited ("Commons' coverage changes over time, and a repeat search later might succeed where this one
didn't"). Same protocol, no exceptions: every candidate through the Commons API, licence read off
`extmetadata.LicenseShortName`, `imageinfo.width`/`height` checked before download, artist from
`extmetadata.Artist` rather than a filename. One addition — every surviving candidate was also opened
and looked at before a decision, since a correct caption is not a correct photograph. That step is
what rejected four subjects that had already passed licence and resolution.

### Measured

**2 of the 13 closed; 44 of 55 products carried a photograph after this entry, up from 42** (55 of 55
after the later entry above, under a bar this one would have refused). 0.4 MB added across
two files (`acei-yellow-tail.jpg` 1600×1200 at 120 KB, `heater-100w.jpg` 1400×1050 at 278 KB —
quality 76 rather than 82, because its dark woven-cloth background compresses badly, the same problem
`auratus.jpg` had: at this crop, 82 measured 335 KB and even 78 measured 301 KB, both over the 300 KB
ceiling). Both source files returned `cc-by-sa-3.0`, an empty `Restrictions` field and
`Credit: Own work` from the API. Species/subject, licence, artist, dimensions and output file sizes
were all verified by running the queries and the conversions and reading the results.

`V10__licensed_photography_gap_reattempt.sql` wires the two keys in. Its statement was run against
the live `catalog` database in the still-running `full-app` cluster inside a transaction and rolled
back: `UPDATE 2`, both keys resolving to the expected `species/<slug>.jpg`, `saulosi` untouched and
still `NULL`. The same session confirmed the starting state from the database rather than from these
notes — 55 products, 42 with a key, 13 without, and the 13 are exactly the slugs named below plus the
two now closed. **Verified since: Flyway applied V10 in the running `full-app` cluster** (log:
`Migrating schema "public" to version "10"`), `storefront` rebuilt and redeployed, and both cards
confirmed rendering through the live ingress — see the entry above, which also caught a real,
unrelated defect in the process (the product detail page rendering no photograph at all, for any
product).

`V9`'s header comment says "the other 13 stay NULL," which is now wrong. V9 is left unedited: Flyway
has already applied it, and a comment-only edit still changes the checksum. The correction is in
V10's own header, which names V9 and the stale line.

### What was NOT forced through

**11 products still have no image.** Four fail on resolution alone — `saulosi` (its whole Commons
category is three files, largest 1295×737 and a tank shot), `bristlenose-pleco`, `otocinclus`,
`red-melon-badis` (one file, 701×468). For the two catfish the pattern is specific and worth naming:
the correctly-identified files are small, and every adequately-sized file is `sp.`, genus only, or a
different species — and neither fish is separable to species by eye, so looking harder cannot close
it. These four would close on a single adequate upload.

Seven fail structurally. Five of them — `yellow-shrimp`, `seiryu-stone-5kg`, `master-test-kit`,
`algae-wafers-250g`, `frozen-bloodworm-100g` — because Commons has nothing of the subject, or nothing
of it in the form the product is sold in: the bloodworm candidate is correctly licensed and correctly
identified but its own caption says *live* worms, and the product is a frozen blister pack whose
packaging is the thing being bought. *Category:Water test kits* and *Category:Rocks in aquaria* are
both literally empty.

**The other two are the ones worth arguing about — `canister-filter-400lph` and
`community-flake-100g` had usable candidates and were rejected anyway.** `File:FiltroExterno.jpg` (3120×4160, CC BY-SA 4.0) and
`File:Potfilter.JPG` (2000×3008, CC BY-SA 3.0) are both unambiguously external canister filters at
well over the resolution floor; both are also unambiguously EHEIM units, the first with a full-size
"EHEIM professionel 4+" logo and the second with a lid mark that resolves cleanly at crop resolution.
The flake candidate is four retail tubs with Tropical, sera and Tetra branding legible across the
frame — and they hold granulate and pellet food, not flake. A Creative Commons licence grants
copyright permission and explicitly disclaims trademark, so a verified licence is not clearance to
put a competitor's branded hardware on a listing for a product the shop does not sell. Cost of that
call: two tiles stay grey that could have been filled today. The candidates are named in `CREDITS.md`
so the decision can be overruled deliberately instead of re-derived from scratch.

**Two caveats on what was accepted, recorded rather than hidden.** `acei-yellow-tail`'s species ID is
the uploader's own caption; Commons files the image under *Category:Unidentified Pseudotropheus*, so
no curator has confirmed it. The fish does carry the marks the variant is sold on — dark blue-violet
body, yellow dorsal margin, solid yellow caudal — but that is a visual match against the trade form,
not a determination, and the source is a soft-focus three-quarter snapshot, not the lateral profile
`README.md` asks for. `heater-100w` shows the product class and not the product: an unbranded
glass-tube heater out of the tank, with no thermostat dial and no wattage marking anywhere in frame,
and the glass carries visible mineral/limescale buildup — a heater that has been used in hard water,
not a new-in-box unit. Nothing in that photograph says "100 W" or "thermostatic," and it does not
look new.

### Still unproven

- The `acei-yellow-tail` identification rests on one uploader's caption plus a visual check against
  published reference photographs. That is the same standard as the batch below and it is still not a
  breeder's or owner's sign-off.
- Neither card has been seen in an actual browser, only via `curl` against the rendered HTML — see
  the entry above for what that verification did and did not cover.
- The eleven remaining gaps were searched by category listing as well as full-text search, which is
  broader than the first pass, but "nothing on Commons" is always a statement about what was queried.
  ~~All eleven are still empty.~~ **All eleven were filled by the later entry above**, at user
  direction and under a deliberately relaxed bar — including three of the "genuinely nothing on
  Commons" cases, which a wider category sweep did find material for. The licence reasoning in this
  entry survived; the resolution, identification, product-form and trademark reasoning was overruled
  on the grounds that this platform never reaches a commercial launch.

---

## 32 product photographs, sourced under verified open licences

The shop had 10 photographs across 55 products — one section (Malawi cichlids) was fairly covered,
everything else was an empty grey tile. `services/storefront/public/species/README.md` is explicit
about why that stayed empty rather than being filled from a generic image search: "a shop is a
commercial use with no fair-dealing argument available," and every photograph must be shop-taken,
licensed for commercial use with the licence on record, or breeder-supplied. This entry is the
"licensed" path, done for real rather than skipped.

### Method

Four parallel passes, one per product group (community fish, catfish/Malawi cichlids, invertebrates,
plants/hardscape/equipment/food), each against the Wikimedia Commons API directly
(`action=query&generator=search...&prop=imageinfo&iiprop=url|extmetadata|size`) — never a generic
image search. An image was only accepted if `extmetadata.LicenseShortName` was `cc0`, public domain,
or an explicit `cc-by`/`cc-by-sa` variant; anything containing "nc" (non-commercial) or "nd"
(no-derivatives), or with no licence metadata at all, was rejected outright. Every accepted image was
also checked against the actual product — scientific name, sex/morph where the product name specifies
one (Lake Malawi cichlids and *Neocaridina* shrimp colour morphs both make this matter:
`Blue Dream Shrimp` and `Blue Velvet Shrimp` are the same species in different colours, and using the
wrong one would be a real, visible mislabelling, not just a licensing miss).

### Measured

**32 of 45 missing products got an image; 42 of 55 products had one after this batch, up from 10**
(44 of 55 after the re-attempt above; 55 of 55 after the relaxed-bar entry above that). ~6.6 MB
total across the new files, each processed to this repository's existing spec (4:3, ≥1200×900, JPEG
quality 80, EXIF-stripped, under 300 KB). Verified rendering end to end: rebuilt `catalog-service`
(carries the new `V9__licensed_photography.sql` migration) and `storefront` (the images are baked
into its static assets at build time, same as the original 10), redeployed both to the running
`full-app` cluster, confirmed Flyway applied migration 9 cleanly, and screenshotted three category
pages (`malawi`, `inverts-shrimp`, `inverts-snails`) to see the actual rendered cards, not just check
HTTP 200s.

### What was NOT forced through

**13 products still had no image after this batch, on purpose** (11 after the re-attempt above, which
closed `acei-yellow-tail` and `heater-100w`)**:** `saulosi`, `acei-yellow-tail`, `bristlenose-pleco`,
`otocinclus`, `red-melon-badis`, `yellow-shrimp` — for each, either no correctly-identified Commons
photo exists at all, or the only ones that do are below the 1200×900 floor, or the only
adequately-sized candidates are mislabelled/unidentified at species level. And `seiryu-stone-5kg`,
`canister-filter-400lph`, `heater-100w`, `master-test-kit`, `community-flake-100g`,
`algae-wafers-250g`, `frozen-bloodworm-100g` — Commons skews toward educational/nature photography
and is genuinely sparse for generic retail product shots; several searches for these returned nothing
but unrelated scanned books and PDFs. These stay `NULL` and render as the designed placeholder.

**Two identification caveats, recorded rather than hidden:** `blue-velvet-shrimp`'s source file calls
itself "Blue Diamond," not "Blue Velvet" — a genuinely distinct photo from `blue-dream-shrimp`'s, same
general blue *Neocaridina* class, but the specific morph name is unconfirmed. `mystery-snail`'s source
is Commons-categorised under *Pomacea diffusa*, treated as a trade synonym of *P. bridgesii* rather
than a clean species match. Both are spelled out in `CREDITS.md`, not glossed over.

**One defect found and fixed before this shipped:** `malaysian-trumpet-snail`'s source is a five-view
scientific specimen plate; the first automated crop-and-resize pass cut off the shell's spire tip and
aperture base. Re-cropped by hand to the single profile view, trimmed, and letterboxed onto a 4:3
black canvas — full shell visible, tip to base, still under 300 KB.

### Still unproven

- The 10 original shop-owner photographs are unaffected and still `unverified` in `CREDITS.md` — this
  entry only touches the new 32.
- No photograph in this batch has been reviewed by the shop owner for accuracy the way a real listing
  would be before publishing; the identification work here is a careful outsider's best effort against
  public reference photos, not a breeder's or owner's sign-off.
- The 13 still-empty product slots were searched for in earnest, not left idle — but Commons' coverage
  changes over time, and a repeat search later might succeed where this one didn't. **It did, for two
  of them** — see the entry above; the remaining eleven are itemised with a reason each in
  `CREDITS.md`, and were later filled under a relaxed bar rather than by Commons' coverage improving.

---

## `staff-portal` reachable through the public ingress; `.wslconfig` written

Small follow-up to the entry below, same day.

`staff-portal` is now reachable at `https://staff.aquashop.localtest.me/` — a **separate host**,
not a `/staff` path prefix under `aquashop.localtest.me`. The reason is structural, not a style
choice: `staff-portal` deploys as `ROOT.war` (context path `""`), which is what lets its
`/healthz`/`/readyz` probes work without a prefix — and its JSPs render links via
`request.getContextPath()`, which is always empty for `ROOT`, so every link on every page is
root-relative (`/orders`, not `/staff/orders`). A path-prefixed ingress route with a rewrite would
correctly serve the *first* page and then break every link on it, since the browser would navigate
straight out of the prefix on the next click. `*.localtest.me` already resolves any subdomain to
`127.0.0.1`, so the fix cost one new `Ingress` rule and one extra hostname on the existing
`cert-manager` certificate — no `/etc/hosts` edit, no second certificate. Verified: `/`, `/healthz`,
`/readyz`, `/orders`, `/stock`, `/catalog` all `200` through the new host, storefront's own routes
unaffected, one certificate covering both hostnames.

Also written this session, at the user's request: `C:\Users\sayan\.wslconfig`
(`memory=11GB`/`processors=4`/`swap=4GB`, the exact settings `docs/getting-started-locally.md` has
always specified). Not yet applied — that needs `wsl --shutdown`, which ends whatever WSL session
runs it, left for the user to do on their own schedule rather than forced mid-session.

**The rollout-deadlock fix from the entry below was re-verified, without touching the demo.** Rather
than tear down the whole cluster, only `staff-portal`'s own Deployment, Service and ConfigMap were
deleted and reapplied fresh — reproducing the exact original condition (a brand-new object, created
with the manifest's placeholder tag, landing in a namespace where the other seven services already
hold most of the `ResourceQuota`). With `maxUnavailable: 1, maxSurge: 0` in place, the rollout
completed cleanly on the first attempt, no manual intervention: the old placeholder-tagged
ReplicaSet scaled to `0/0/0` immediately, the new one reached `1/1/1` within seconds, and both
`https://aquashop.localtest.me/` and `https://staff.aquashop.localtest.me/` kept answering `200`
throughout.

Also found and fixed in passing: `docs/context_summary.md` and `docs/architecture-pdf.html` both
still claimed Phase 6 gives `order-service` "the outbox that makes its saga crash-safe" — that gap
was already closed, without an outbox, by `SagaRecovery`'s state scan
([ADR 0018](docs/adr/0018-recover-from-state-not-from-an-outbox.md), which explicitly amends 0015
for this exact reason). ADR 0018's own Consequences section already says what an outbox is still
for: reliably publishing domain events once NATS exists, not saga crash-recovery. Fixed both, and
regenerated `architecture.pdf` from the corrected HTML.

### Still unproven

- No sustained load against any of the eight services together.
- `platform` (Argo CD) and `observability` remain fully unbuilt.
- The `.wslconfig` override is written but not applied; `/proc/meminfo` still measures ~7.4 GB.
- The `.wslconfig` override is written but not applied; `/proc/meminfo` still measures ~7.4 GB.

---

## `full-app` ran in k3d for the first time

The previous entry ended with `full-app` blocked before a single pod deployed, three times in a row,
by a memory preflight sitting right at the edge of this machine's unconfigured WSL2 ceiling. On
retry the next day, with nothing else running, the preflight passed and every one of the eight
services came up — `notification-service` and `staff-portal` alongside the original six.

### The defect this run found

`staff-portal`'s rollout hung at `0 out of 1 new replicas have been updated` until it exceeded its
600 s progress deadline. The cause was not memory pressure in the way the previous three attempts
were — it was a rollout-mechanics deadlock specific to this profile's combination of things:

- Every deployment manifest here ships a placeholder tag (`aquashop/staff-portal:PLACEHOLDER`,
  `# CI rewrites this to the git SHA`) by design — `kubectl apply -f` creates the Deployment with it,
  and `bootstrap.sh`'s own `kubectl set image` supersedes it moments later. On every other service,
  in every prior run, this has been genuinely cosmetic: the first pod briefly tries to pull a tag
  that doesn't exist, fails once, and gets replaced before anyone notices.
- `staff-portal`'s Deployment uses `maxSurge: 1, maxUnavailable: 0` (the same strategy as every other
  service here), which means a rollout keeps the old pod alive until a new one is Ready. The old pod,
  stuck forever in `ImagePullBackOff` on a tag that will never resolve, is *never* Ready — so
  Kubernetes never scales it down, and it sits there indefinitely holding its `limits.memory: 1Gi`
  reservation against the namespace `ResourceQuota`.
- With eight services now sharing a 4 Gi memory-limit quota, that stuck 1 Gi reservation left too
  little headroom for the *new* replica's own 1 Gi request — `ReplicaSetController` logged
  `FailedCreate: exceeded quota` on every retry, and the rollout could never make progress in either
  direction. Two pods needing 2 Gi combined, arriving from opposite ends of an unbreakable ordering
  constraint, is not something either the memory preflight or the per-pod resource estimate was ever
  going to catch — it only exists at the intersection of a placeholder tag, a zero-unavailable rollout
  strategy, and a quota with limited headroom, and it only shows up on the very first deploy of a
  service into an already-fullish namespace.
- **Fixed twice: by hand in the running cluster, then for real in the manifest.** Deleting the stuck
  `ImagePullBackOff` ReplicaSet freed its quota reservation and let the real rollout proceed
  immediately — that unblocked this run, but changed nothing checked into Git. Afterward,
  `platform-repo/dev/staff-portal/deployment.yaml`'s rollout strategy was changed from
  `maxUnavailable: 0, maxSurge: 1` (every other deployment's setting, and the thing that made the
  deadlock possible) to `maxUnavailable: 1, maxSurge: 0` — the old pod is torn down before the new
  one is created, rather than requiring both to exist at once, so the stuck-pod-holds-the-quota
  scenario can't arise. `staff-portal` is read-only and internal-only, so the very-briefly-fewer-than-1-replica
  window this trades for costs nothing here. **Not yet re-verified against a fresh reproduction** —
  applying it requires tearing down the now-working cluster to force a from-scratch `staff-portal`
  deploy again, and that wasn't done in favour of leaving the demo up.

### Measured

`kubectl top node` / `kubectl top pods -A`, all eight services up and settled, `metrics-server`
installed cleanly this run (the transient GitHub timeout from three attempts ago didn't recur):

| | |
|---|---|
| **Total node memory, `full-app`** | **2234 MiB (29%)** — against a ~5.2 GB estimate that had never been tested end to end |

| Pod | CPU | Memory |
|---|---|---|
| `staff-portal` (WildFly) | 5m | **456 MiB** |
| `order-service` (JVM) | 4m | 229 MiB |
| `catalog-service` (JVM) | 3m | 217 MiB |
| `storefront` (Node) | 1m | 32 MiB |
| `aquatics-advisor` (Python/FastAPI) | 5m | 43 MiB |
| `postgres` | 3m | 60 MiB |
| `inventory-service` (Go) | 1m | 5 MiB |
| `notification-service` (Go) | 1m | 5 MiB |
| `payment-service` (Rust) | 1m | 2 MiB |
| `ingress-nginx-controller` | 2m | 186 MiB |

`staff-portal`'s 456 MiB is the first real number against the manifest's 1 Gi limit — comfortable
headroom, not a tight fit, and a long way from "5.2 GB estimate" ever implying anything about this
specific pod. `notification-service`'s 5 MiB matches `inventory-service`'s own figure almost exactly,
consistent with both being small Go services doing comparable I/O-bound work.

### A live checkout confirmed the whole path, not just the pods

Cart → line (`INV-AMA-01`, Amano Shrimp × 2) → checkout with an `Idempotency-Key`, same shape as the
`commerce`-profile demonstration two entries back. Result: `201`, `CONFIRMED`, reservation
`COMMITTED`. This time, `order-service`'s log showed `HttpNotificationClient` actually firing:
`notification-service` answered `202` on `POST /v1/events` four seconds before its own log recorded
`"email delivered (stub)" event=ORDER_CONFIRMED to=demo@example.com` — the full push-then-deliver
path from [ADR 0020](docs/adr/0020-push-not-subscribe-until-phase-6.md), working exactly as designed,
observed end to end for the first time.

`staff-portal` was checked directly (via `kubectl port-forward`, not yet through the ingress):
`/healthz` and `/readyz` both `200`, and all three of its pages (`/orders`, `/stock`, `/catalog`)
rendered `200` against live backend data.

### Still unproven (as of this entry — see the entry above for what's since closed)

- Not yet exposed through the ingress — checked via `kubectl port-forward` only, matching
  `order-service`'s own pattern of staying internal-only by design.
- No sustained load against any of the eight services together.
- `platform` (Argo CD) and `observability` remain fully unbuilt.
- The rollout-deadlock defect above is worked around by hand in the cluster; a manifest fix
  (`maxUnavailable: 1, maxSurge: 0`) is written but not yet re-verified against a fresh reproduction.

---

## `notification-service` and `staff-portal` built; `full-app` still won't run

A prior version of `context_summary.md` claimed the `full-app` profile "has manifests but hasn't
been exercised." That was false — there was no code, no Dockerfile, no manifest, and no `full-app`
case in `bootstrap.sh` anywhere in the repository or its git history. This entry is what actually
building both services, and then trying to run them, found.

### What was built

`notification-service` (Go), modeled on `inventory-service`'s layout: an embedded migrator with a
Postgres advisory lock, a `notify` database/role, one `outbox` table keyed `(order_id, event_type,
target_type)` so a retried push can't double-send, a `POST /v1/events` ingest endpoint, and a
background sender goroutine with stub `LoggingEmailSender`/`LoggingWebhookSender` implementations —
"email and webhook targets — external, stubbed locally" was already the documented design, matching
`payment-service`'s own stubbed-acquirer honesty.

`staff-portal` (JSP/Jakarta EE on WildFly), plain Servlets and JSP with no Spring, deliberately
different from every other service in the repository. Read-only in v1 against order-service,
inventory-service and catalog-service's existing APIs — no stock-adjustment, species-editing, or
claims workflow, because none of catalog-service or inventory-service expose a write endpoint today,
and a DOA-claims model doesn't exist anywhere in the codebase. `architecture.md`'s "staff manage
tanks, stock, claims" actor line describes a target, not what's buildable against the current API
surface, and the README says so rather than silently under-delivering.

`order-service` got a small, additive `NotificationClient` (`http`/`noop`, default `noop` — so
`core` and `commerce` are byte-for-byte unaffected), firing on checkout `CONFIRMED` and on
`DispatchWatcher`'s scan. The mechanism is a direct fire-and-forget HTTP push, not a NATS
subscription — NATS doesn't exist until Phase 6, and `full-app` shouldn't have to wait for it
([ADR 0020](docs/adr/0020-push-not-subscribe-until-phase-6.md)). An ingest-call failure loses that
notification permanently; this is accepted because [ADR 0011](docs/adr/0011-derived-state-over-stored-state.md)
already established notification lag/loss as non-load-bearing by design — the dispatch watcher's own
javadoc names "the notification service" as exactly what it's not load-bearing *for*.

### The defect only running it found

`DispatchWatcher.scan()` was `@Transactional`. The plan sketched calling a second `@Transactional`
method from inside it to separate the DB write from the notification push — which is the exact
self-invocation bug this repository already documented once (`CLAUDE.md`: "Spring's `@Transactional`
does nothing when the method is called from inside the same class"). Fixed the same way `CheckoutSaga`
was: the DB write moved into `OrderSteps.markDispatchable`, a genuinely separate bean, and
`DispatchWatcher.scan()` (no longer `@Transactional` itself) fires notifications only after that call
returns — so a notification-service outage can never affect the gauge write it exists to react to.

Running `staff-portal`'s container standalone (not just building it) found two more, neither visible
from reading the Dockerfile:
- The build-time `embed-server` step that configures console/stdout logging left `standalone/data`
  and friends root-owned; first real boot crashed with "Directory .../standalone/data/content is not
  writable." Fixed with `chown -R jboss:jboss` on the whole `standalone/` tree.
- Deploying the WAR as `staff-portal.war` put the app under `/staff-portal/*`, silently breaking
  every `/healthz`-shaped k8s probe path this platform uses. Fixed by deploying as `ROOT.war`.

One assumption corrected by measurement: `architecture.md` called this "the slow-start WAR exercise."
A clean boot took **~2.8 s** — one data point, not a load test, but not slow either.

### Measured

- `mvn test` in `order-service`: 55 tests, 0 failures, 18 skipped (DB-gated, unchanged baseline) —
  the new `NotificationClient` wiring introduced no regression.
- `go build`/`go vet`/`go test` in `notification-service`: pass. Unit test for outbox target
  selection; integration test gated behind `NOTIFICATION_TEST_DSN`, same skip-if-unset pattern as
  `inventory-service`.
- `mvn test` in `staff-portal`: 3/3 pass.
- Every one of the three new/changed images (`order-service`, `notification-service`,
  `staff-portal`) builds clean in Docker, standalone and in the merged tree together.
- `staff-portal`'s base image, confirmed by actually pulling and inspecting it rather than assumed:
  `quay.io/wildfly/wildfly:33.0.1.Final-jdk21`, non-root UID/GID **1000/1000** (`jboss`).

### Still unproven — the headline number

**`full-app` has not run successfully in k3d.** Three attempts, none got past deploying a single
pod:

1. Cluster created, then `--metrics` (metrics-server) failed on a transient network timeout fetching
   its Helm chart from a GitHub release asset.
2. Retried without `--metrics`; failed the memory preflight (`need_mb=6000`) outright — 5946 MB
   available against a 6000 MB gate.
3. After a clean `--destroy` and retry, passed the preflight (6387 MB available) and got as far as
   creating the k3d cluster, then failed on the *same* transient Helm/GitHub timeout, this time
   fetching ingress-nginx's chart.

A bare k3d cluster with **nothing deployed yet** — no images imported, no pods scheduled — already
leaves only ~5.9–6.4 GB free out of this machine's unconfigured 7.4 GB WSL2 ceiling (see the memory
budget entry two sessions back), landing on both sides of the profile's own conservative preflight
gate across repeated attempts within the same few minutes. `full-app`'s real memory requirement is
therefore not just unmeasured, it's *unmeasurable* with the current setup — the run never got far
enough to import an image, let alone find out what notification-service or staff-portal actually
cost resident. Closing the gap means applying the `.wslconfig` override `docs/getting-started-locally.md`
has always specified (`memory=11GB`), which requires `wsl --shutdown` and ends whatever WSL session
is running at the time — not done this session, left as the user's call rather than forced through
by lowering the safety gate that exists precisely to prevent an OOM-killer debugging session.

---

## Both `core` and `commerce` ran in k3d for the first time

Every prior session verified this repository against a local Postgres, never in a cluster, because
no session before this one had a Docker daemon. This one did. `core` came up first, `commerce`
followed the same day, and a live checkout ran the full saga in-cluster — the first time any of it
has happened somewhere other than a build container.

### What broke, and what it means

Three defects surfaced, none of them caught by any amount of review, because none of them can be —
they only exist once the actual container runs:

- **Every pod** (all six `platform-repo/dev/*/deployment.yaml` files carry the same pattern) sat in
  `CreateContainerConfigError` on `core`'s first rollout. The distroless `:nonroot` base images set
  `USER nonroot` — a name, not a UID — and `runAsNonRoot: true` alone gives kubelet nothing numeric
  to verify without running the container first. Fixed by adding `runAsUser: 65532` /
  `runAsGroup: 65532` (Google's distroless nonroot UID) to the pod securityContext in all six
  deployments.
- **`inventory-service`**: `go.mod` had drifted ahead of its own Dockerfile — `go 1.25.0` declared,
  `golang:1.24-bookworm` pinned as the builder. `go mod download` refused to run. Bumped to
  `golang:1.25-bookworm`.
- **`payment-service`**: `Cargo.lock` resolved a transitive dependency (`home v0.5.12`) whose own
  manifest requires Cargo's `edition2024` feature, stabilized in Rust 1.85 — a stricter floor than
  the crate's declared `rust-version = "1.82"`, which the pinned `rust:1.82-bookworm` builder
  matched but couldn't satisfy. Bumped to `rust:1.90-bookworm`.

The toolchain defects are the more interesting pair: `mvn`/`go build`/`cargo build` run locally
against whatever toolchain happens to be installed, so neither one had ever been visible before —
only `docker build` against the pinned image actually enforces the version a Dockerfile claims.

### A live checkout, end to end, in-cluster

From a temporary `curlimages/curl` pod inside the namespace (`order-service` is intentionally not
exposed through the public ingress): create a cart, add a line (`INV-AMA-01`, Amano Shrimp × 2),
checkout with an `Idempotency-Key`. Result: `201`, order state `CONFIRMED`, reservation state
`COMMITTED`, `paymentRef` set, dispatch window `2026-09-21T14:00+05:30` — the next Monday after the
Thursday cutoff, the shipping-calendar rule working against a real clock rather than a test double.
The order-event audit trail showed exactly the documented state machine, `PENDING → STOCK_RESERVED
→ PAID → CONFIRMED`, each transition a fraction of a second apart, and `inventory-service`
correctly reflected the sale afterward (`held: 0`, `onHand` reduced by the purchased quantity).

### Measured

`kubectl top node` / `kubectl top pods -A`, both profiles up and settled:

| Profile | Total node memory |
|---|---|
| `core` | **1.32 GiB** (against a ~2.6 GB estimate) |
| `core` + `commerce` | **2052 MiB** (against a ~4.2 GB *additive* estimate for commerce — commerce actually added ~730 MiB) |

| Pod | CPU | Memory |
|---|---|---|
| `catalog-service` (JVM, 640Mi limit) | 3m | 215 MiB |
| `order-service` (JVM) | 7m | 224 MiB |
| `storefront` (Node) | 1m | 30 MiB |
| `aquatics-advisor` (Python/FastAPI) | 3m | 43 MiB |
| `inventory-service` (Go) | 1m | 3 MiB |
| `payment-service` (Rust) | 1m | 2 MiB |
| `postgres` | 6m | 59 MiB |
| `ingress-nginx-controller` | — | 184–189 MiB |
| `cert-manager` (+ webhook, cainjector) | — | ~53 MiB |
| `metrics-server` | — | ~19–21 MiB |

`catalog-service`'s 215 MiB and `order-service`'s 224 MiB are the first honest JVM numbers in this
repository — measured under their actual cgroup limits with `MaxRAMPercentage=70`, not against host
RAM. `payment-service`'s 2 MiB and `inventory-service`'s 3 MiB are lower again than their own
previous local-container figures (2 MiB and 3 MiB in-cluster vs. 6 MiB and 13.9–17.0 MiB
respectively) — both pods were effectively idle during the smoke-test window, not under sustained
load, so this is a floor, not a load-bearing number.

`commerce`'s figure does not include NATS, which `bootstrap.sh --profile commerce` does not deploy
(planned for Phase 6).

### A ceiling that was also never measured

The design has always targeted 11 GB usable inside WSL2 via a `.wslconfig` memory override
([getting-started-locally.md](docs/getting-started-locally.md#memory)). That override has never
been applied on this machine: `/proc/meminfo` measures **7.4 GB**, WSL2's unconfigured default of
roughly half of host RAM. `core` + `commerce` fit inside it with room to spare, but the
`observability` profile's ~9.2 GB estimate does not fit the unconfigured 7.4 GB ceiling at all —
only the intended 11 GB one. This was invisible while every number in the profile table was an
unmeasured estimate sitting against an unmeasured ceiling; it is visible now that two of the five
profile figures are real.

### Still unproven

- `full-app`, `platform` and `observability` profiles have never run in k3d. No manifests exist yet
  for `platform` (Argo CD) or `observability`; `full-app` has manifests but hasn't been exercised.
- No sustained load, in or out of the cluster, for anything.
- A `kill -9` mid-checkout has been demonstrated for the saga's crash recovery, but outside k3d —
  not yet reproduced against the in-cluster saga specifically.
- ~~`order-service`'s README still documents a `StubPaymentGateway`...~~ **Corrected.** The README
  described only the stub; it now documents both `PaymentGateway` implementations and the
  `PAYMENT_GATEWAY` toggle, and that every k3d deployment sets `http`.

---

## The taxonomy is settled, and a shrimp is not a fish

The category tree was built in V3 from guesswork about what the shop would sell. The owner has now
said what it sells, so V7 replaces the guesses — and this is meant to be the last structural change
to the tree before there are orders pointing at it. Re-parenting a category once customers have
bookmarked it is a redirect problem; doing it now is an `UPDATE`.

### What changed in the tree

| | Before | After |
|---|---|---|
| Cichlids | African, South American, Central American, Dwarf — all siblings | African, **American** (→ Central, South), Dwarf |
| African lakes | Malawi, Tanganyika, Victoria, *West African* | Malawi, Tanganyika, Victoria, **Other African** |
| Catfish | "Catfish & Loaches" → Corydoras, Plecos, Loaches | **Catfish** → **Small** (Corydoras, Otocinclus, Bristlenose) / **Large** (Large Plecos, Synodontis) |
| Loaches | under Catfish | own section under Freshwater |
| Badidae | did not exist | new section under Freshwater |
| Invertebrates | Live Fishes → Freshwater → "Shrimp & Snails" | **root section**, → Shrimp / Snails |

The American level is the fix for a tree in which one entry contained its own siblings. The catfish
split is the owner's ask and **a written rule rather than a judgement call**: small is an adult
under 15 cm that is happy in 150 L or less. There is a test that reads the care profiles and fails
if a catfish is filed on the wrong page — because a customer with a 60 L tank browses that page and
trusts it.

Loaches moved because a loach is Cobitidae, not Siluriformes. They shared a page because they share
a shelf, which is not the same thing.

Stock: 55 products, up from 36. Nineteen new — three Badidae, three corydoras, four large catfish,
four shrimp colours, five snails.

### Measured

Nothing new. Every service in this repository has still only ever run against a local Postgres.

### The defect this found

Putting invertebrates in the catalogue broke `aquatics-advisor`, and it took running the two
together to see it. The advisor refused **four scarlet badis and ten cherry shrimp in a 40 L planted
nano** — one of the best-known good tanks in the hobby. It sizes a stocking by summing adult length,
and the ten shrimp were 79% of the bioload it was refusing on.

V8 adds `animal_group` (FISH / SHRIMP / SNAIL) to the species profile and the advisor applies a
bioload factor per group. Ownership follows [ADR 0017](docs/adr/0017-advisor-owns-no-data.md): the
catalogue owns what kind of animal it is, `rules.yaml` owns what to do about it.
[ADR 0019](docs/adr/0019-the-catalogue-says-what-kind-of-animal-it-is.md) has the reasoning and the
cost.

The factors are not zero. A hundred shrimp in a 20 L tank is still refused — a rule that can never
say no about invertebrates is no better than the one it replaced.

**Deployment order matters and nothing enforces it.** The advisor tolerates a missing `animalGroup`
by treating the animal as a fish, so an advisor deployed before catalogue V8 gives the old, wrong
answer about shrimp rather than failing. Deploy the catalogue first.

### Two older defects, found the same way

- Three Malawi products had an `image_key` pointing at a photograph that was never delivered, so
  those pages rendered a broken image instead of the placeholder. V5 made a promise for six fish
  when three files arrived.
- Two ACTIVE sections had no products and no children — tiles on the shop front opening onto an
  empty page. They had been that way since V3 because nothing joined the tree to the products.
  Both are now `COMING_SOON`, and there is a test that fails if a third appears.

There was also a contradiction inside the test suite itself: two tests asserted different counts
from the same endpoint. Neither had ever run — `CatalogApiTest` needs Testcontainers and no session
has had Docker.

### Verified

- All eight migrations applied by Flyway from an empty database, with `ddl-auto: validate` passing.
- Every category and product endpoint exercised against the running service; every number asserted
  in `CatalogApiTest` checked against the live API by hand, because that suite still cannot run here.
- 35 advisor tests green (5 new), including the nano tank, the hundred-shrimp refusal, and an oscar
  that still eats shrimp.
- The full V7 catalogue put through the real advisor via the real adapter.

### Still unproven

`CatalogApiTest` has never been executed. It is 28 tests written against numbers verified by hand
against a running service — which is not the same thing as a green suite, and the contradiction
found in it this round is what that difference looks like.

---

## The saga survives a crash

Closes the gap every release note since Phase 3 has named: the checkout saga runs inside one
request, and a process death between taking the money and committing the holds left the money taken
and the order unfinished. The holds expired on their own so the stock came back, but **the refund
never happened**, and the only thing that found those orders was a person running a SQL query out of
a runbook.

### Not an outbox

[ADR 0015](docs/adr/0015-write-the-intent-before-the-call.md) said this would be fixed with an
outbox table, by analogy with `payment-service`. On building it, the analogy does not hold, and
[ADR 0018](docs/adr/0018-recover-from-state-not-from-an-outbox.md) amends it.

An outbox records an intention that is otherwise nowhere on disk — payment-service's problem exactly,
where a charge at the acquirer has no counterpart here until the intent row exists. In order-service
the intention is already stored in full: an order in `PAID` with a payment reference and no dispatch
window **is** the record of "money taken, work unfinished". A parallel table would duplicate the
order row and then need keeping consistent with it.

What was missing was never the record. It was something to read the record and act.

### Two ways to be stuck

| State | What happened | What recovery does |
|---|---|---|
| `PAID` | money taken, holds not committed | finish the saga — commit, or refund if the holds expired meanwhile |
| `STOCK_RESERVED` | died during authorisation, so the charge is unknown | ask payment-service: captured → finish; not taken → release and fail; **still unknown → hand to `PAYMENT_UNRESOLVED`** |

The recovery does not guess. An answer it cannot get goes to the state that already exists for that
answer.

### Demonstrated with an actual SIGKILL

Not a simulated crash. A checkout was started against an inventory service rigged to block on
commit, the order-service JVM was killed with `kill -9` while the request was in flight, and the
database was left in exactly the state the gap describes:

```
AQ-060FE3CF71  state=PAID  paymentRef=pay_4d63f4c6b45b4d388c95  dispatch=NOT SET
hold  FSH-MAL-02  state=HELD
order-service API: 000
```

Charged, unfinished, nothing running. After a restart, with nobody touching anything:

```
WARN  SagaRecovery - resuming a checkout that never finished: order=AQ-060FE3CF71 stuck for 21s
INFO  SagaRecovery - order AQ-060FE3CF71 finished, dispatch 2026-09-16T08:30:00Z

AQ-060FE3CF71  state=CONFIRMED  dispatch=2026-09-16 08:30:00+00
hold  FSH-MAL-02  state=COMMITTED
```

### Two bugs found on the way

**The stub payment gateway could never say "still unknown".** Its `resolve` looked only at whether
it had a record of the key, so the one path that exists for an unresolvable payment was untestable
through it. A provider that will not answer an authorisation will not answer a lookup either.

**A rewound order kept its holds committed.** The first version of the test simulated the crash by
resetting only the order's state, which left the reservations `COMMITTED` — so the commit step had
nothing to do, quietly succeeded, and the refund path could never be reached. A real crash leaves
the holds `HELD`.

Also worth recording: the first run of the live demonstration did nothing at all, because the jar
being run had been compiled and tested but never repackaged. The running artefact was older than the
code under test.

### Tests

55 in `order-service`, up from 48. Seven cover recovery, including that running it twice changes
nothing the second time, and that a confirmed order is left alone however old it is.

---

## Photographs, and seven fish they brought with them

Ten photographs arrived with the species named in the filenames. Only three were of fish already in
the catalogue, so the other seven became stock — and two of them finally put something in the South
American and Central American sections, which had been sitting empty and ACTIVE since the tree was
built. Thirteen cichlids now, ten of them photographed.

The filename is the wiring: a product's slug matches its photograph, the catalog stores
`species/<slug>.jpg`, and nothing needs a lookup table.

### Processing

5.6 MB down to 1.8 MB: resized to 1600 px at most, progressive JPEG at quality 82 — 76 for the
auratus, whose rock background compresses badly and was the one file still over the 300 KB budget —
and **EXIF stripped**, because camera metadata carries GPS coordinates and an owner's name that a
shop has no reason to publish.

Two are below the 1200 px minimum this repository sets for itself and are recorded as needing a
re-shoot: the Nkhomo Benga peacock at 1136 px, and the salvini at **474 px**, which is too small for
anything but a thumbnail.

### Provenance is recorded, not assumed

`public/species/CREDITS.md` has one row per image, and every row currently says **unverified**. They
are in the repository so the site can be built against real photographs instead of grey boxes; none
has a licence on record, and each has to become the shop's own, licensed, or breeder-supplied before
the shop takes an order.

### What the new stock did to the advisor

An Oscar reaches 35 cm. Put one in with neon tetras and the advisor now refuses it twice over —
once on temperament and once on the size ratio:

```
Oscar reaches 35 cm and Neon Tetra only 3.5 cm. If it fits in the mouth, it is food.
This is not aggression, it is feeding behaviour.
```

That rule has existed since Phase 5 and had never had a real predator to catch.

---

## Photography: a key, not a URL

`image_url` arrived empty with the category tree and is now `image_key` before anything was written
into it. The difference matters: a URL hard-codes where the bytes live, so the day the shop moves its
photographs behind a CDN, every row has to be rewritten. A key does not — the storefront composes
`IMAGE_BASE_URL + key`, and `/static` becoming a CloudFront distribution is a ConfigMap change with
no migration at all. `catalog-service` owns *which* photograph belongs to a product; it has no
business owning *where it is served from*.

The convention is `species/<product slug>.jpg` and `sections/<category slug>.jpg` — predictable
enough that whoever photographs a new fish knows what to call the file without asking. Dropping a
JPEG into `services/storefront/public/species/` is the whole deployment.

### Two ways to have no picture, one placeholder

Most of the catalogue is not photographed, and a key can also point at a file that has not been
uploaded yet. Both render the same quiet placeholder at the right aspect ratio: a null server-side,
a missing file caught in the browser — because only the browser can know whether a CDN has the file,
and checking server-side would mean a request per image on every render.

A page of broken-image icons reads as a broken site. A page of placeholders reads as an incomplete
catalogue, which is the truth.

Images are `loading="lazy"` with an explicit `aspect-ratio`, so a page of forty fish neither fetches
forty images nor reflows as each one lands.

### Not done

**There are no photographs in the repository.** Reference shots were supplied for this design work
but they are web images — one carries another retailer's watermark — and a commercial shop has no
fair-dealing argument available. Every photograph shipped here has to be the shop's own, licensed
with the licence recorded, or supplied by the breeder with permission. The rule is written in
`public/species/README.md` next to where the files go.

---

## Catalogue becomes a tree

The shop front was six flat categories because six was all the shop sold. A real fish shop is not
flat: a customer after a Demasoni is looking for **Live Fishes › Freshwater › Cichlids › African ›
Lake Malawi**, and every one of those levels is a page somebody browses.

### What changed

`category` gains `parent_id`, `status`, `teaser` and `image_url`; `product` gains `image_url`. Three
new endpoints where there was one:

| | |
|---|---|
| `GET /api/categories` | the **top of the shop** — roots only, which is what a nav bar wants. Returning all twenty-nine would make the caller filter, and then the caller has to understand the tree to draw a menu |
| `GET /api/categories/{slug}` | one page in one call: where you are, the breadcrumb, the sections inside, the products at this level |
| `GET /api/categories/{slug}/products?deep=true` | everything in the subtree |

`status` is `ACTIVE` / `COMING_SOON` / `HIDDEN`, and the API publishes a derived `browsable` rather
than making every client keep its own list of statuses that mean yes. Saltwater ships as
`COMING_SOON`: greyed out and labelled on the shop front, because a customer who wants marine fish
should learn we are working on it rather than conclude we do not sell fish.

The counts on a tile are subtree counts. "Cichlids" holds no products of its own and six fish below
it, and a tile reading 0 would be true and useless.

### Five levels is five correct guesses

The deepest path is five clicks from the front door to a fish. Every level that has sections
therefore also offers *browse all* — the `deep=true` query, surfaced in the storefront as
`/c/cichlids?all=1`. A tree that can only be walked one level at a time is a filing system, not a
shop.

### Stock, and what it did to the advisor

Lake Malawi is stocked with six mbuna carrying real care data — Saulosi, Demasoni, Yellow Lab, Red
Zebra, Acei, Auratus. Mbuna want pH 7.8–8.6; a neon tetra wants 5.5–7.5. Those ranges do not meet at
any point, so `aquatics-advisor` refuses the tank **on the data alone**, with no rule written about
either fish:

```
Demasoni and Neon Tetra have no pH in common: Demasoni needs 7.8-8.6, Neon Tetra
needs 5.5-7.5. There is no setting that suits both.
```

### The bug that found

The same run produced a second finding that was not merely wrong but backwards:

```
12 × Demasoni in one tank: this species is aggressive towards its own kind.
```

For mbuna, twelve **is** the husbandry — a crowd spreads the aggression so no single fish is driven
to death, and the species' own profile says `min_group_size = 12`. The Phase 5 same-species rule
fired on temperament alone and would have refused the sale the shop most wants to get right.

It now applies only where `min_group_size == 1`: a species whose profile says "keep twelve" is
telling us the group is the mitigation. Real data in the catalogue is what exposed it; the rule had
looked correct against invented fish.

### Also

`GET /api/products` — the unfiltered list — is now covered by a test, after the Phase 5 session found
it returning 500.

### Not done

The catalogue has no images yet: `image_url` is a column with nothing in it, and the storefront draws
name-and-price cards. A prototype of the finished navigation, with drawn plates standing in for
photographs, is published separately.

---

## Phase 5 — `aquatics-advisor`

Whether a tank will work, and why not. Python / FastAPI, no database, and a rules file meant to be
edited by somebody who keeps fish.

### The arrangement

`rules/rules.yaml` holds every threshold with a plain-English justification beside it;
`advisor/rules.py` decides *what* to check and never *how much is too much*
([ADR 0016](docs/adr/0016-rules-are-data-not-code.md)). The justifications are not comments — the API
quotes them back to the customer, and `GET /v1/rules` publishes the file, because a shop that cannot
show its own rule is asking to be trusted rather than read.

The test suite loads the **shipped** YAML rather than a fixture. Widening the pH tolerance until
guppies and cardinal tetras pass turns a test red and makes whoever did it say so out loud.

**No database** ([ADR 0017](docs/adr/0017-advisor-owns-no-data.md)). Species profiles belong to
`catalog-service`; a copy here would be a second source of truth that drifts the first time somebody
corrects a pH range. Cost: the advisor cannot answer anything when the catalog is down — readiness
fails, liveness deliberately does not.

### Three verdicts, not two

`ok` · `caution` · `refused`. **No overlap at all is a refusal** — there is no number the tank can be
set to. **A narrow overlap is a caution** — achievable, with no margin left. Those are different
problems and a binary answer would collapse them.

### The bug worth reporting

A size-only predation rule refuses a kuhli loach with neon tetras: 10 cm against 3.5 cm, nearly three
times. A kuhli is an eel-shaped bottom dweller with a mouth built for hunting in gravel and no
interest whatever in a fish in midwater.

What predicts predation is **mouth gape**, and the catalog does not record it. Adult length is wrong
in both directions — the other error is an angelfish, which every source calls peaceful and which is
the classic reason a tank of neon tetras becomes a tank of one angelfish. Limiting the rule to
aggressive and semi-aggressive species avoids the first and accepts the second; the gap is named in
`rules.yaml` rather than papered over, and closing it means adding a field to somebody else's service.

`test_a_kuhli_loach_is_not_treated_as_a_predator` exists because of this.

### A fourth Phase 1 defect, found by a new consumer

`GET /api/products` with no query returned **500**. Every query in `ProductRepository` join-fetches
the category except the inherited `findAll()`, which the controller used for the unfiltered list —
and with `open-in-view: false` there is no session left when the DTO asks for the category name.
`LazyInitializationException`.

I saw this error in an earlier session and attributed it to a mistake in my own shell one-liner. It
took a second consumer calling the endpoint for real to show what it was.

### Verified live, against the real catalog

```
10 neon tetras + 6 panda cories in 120 L          -> ok
    hold the tank at 20-25 °C, pH 6-7.4, 2-10 dGH; needs about 78 L when grown

6 guppies + 10 cardinal tetras in 200 L           -> refused
    "Guppy and Cardinal Tetra have no pH in common: Guppy needs 7-8.2, Cardinal Tetra
     needs 4.6-6.8. There is no setting that suits both. pH is a log scale, so 6.5 and
     7.5 are ten times apart, not one apart."

a bristlenose pleco into 60 L of neon tetras      -> refused
    "Bristlenose Pleco needs at least 120 L of tank and this one is 60 L. That is a
     floor for the species, not a stocking calculation."

a male betta into a community tank                -> refused (temperament)
three neon tetras                                 -> refused (a shoal that is not a shoal)
a heater, or an unknown SKU                       -> 404
```

That is the phase's acceptance criterion: **a tank that refuses a fish it cannot keep, and says why
in terms an aquarist would use.**

### Measured

| | |
|---|---|
| `aquatics-advisor` resident memory | 59 MiB — between the Go service (14 MiB) and the JVMs (~360 MiB), which is where a CPython web service belongs |
| Tests | 29, no database and no network |

### Still unproven

- **Never run in k3d**, like everything else here.
- **No test covers the HTTP layer or the catalog client.** Both were exercised by hand against a live
  `catalog-service`; neither has an automated test. Clearest gap of this phase.
- The image is `python:3.11-slim`, not distroless — so it has a shell and a package manager in it,
  the largest attack surface in the platform. Vendoring uvicorn's native wheels into
  `distroless/python3` is possible and is a follow-up.

---

## Phase 4 — `payment-service`, and an unknown that stays unknown

Authorisation, capture, refund and a ledger, in Rust. And the change to `order-service` that the
whole phase is for: a checkout that survives a payment provider which never answers.

### The failure it is built around

Not a decline. **An acquirer that takes the money and does not answer.** Both obvious responses to
that are wrong: calling it a failure releases the stock while the customer's money is gone, and
calling it a success promises an order that may never have been paid for
([ADR 0014](docs/adr/0014-unknown-is-not-failure.md)).

So the unknown is modelled as a state in both services. `payment-service` leaves the payment
`pending` and answers **504** — not 500, which invites a caller to treat it as failure and move on.
`order-service` has `PAYMENT_UNRESOLVED`, whose only exits are `PAID` and `PAYMENT_FAILED`; there is
deliberately no route to `CANCELLED`. **The holds are not released on the way in**, because
releasing is a decision that the payment failed. They expire on their own, which returns the stock
without anybody having decided anything.

### The bug worth reporting

`payment-service` was written to prevent exactly this class of error and contained one anyway.

The first `resolve_pending` treated "the acquirer has no charge for this reference" as proof that no
charge would ever be made, and voided the payment. Demonstrated against the running service —
acquirer delay 6 s, client timeout 1.5 s:

```
t+0.0s  authorise  -> 504, payment left pending
t+1.0s  resolve    -> acquirer has no charge -> payment written off as `failed`
t+6.0s  the acquirer takes the money
t+8.0s  ledger:  seq 1 authorise 50000 | seq 2 void  "no charge for this reference"
```

The customer charged, the ledger saying the payment never happened. An authorisation that has not
appeared is not an authorisation that will not appear. A `NoSuchCharge` may now only void a payment
older than `ACQUIRER_VOID_AFTER_SECONDS`. The same scenario after the fix:

```
t+1.0s  resolve -> 504 still_unresolved   (too early to call)
t+7.0s  resolve -> 200 captured
        ledger:  seq 1 authorise 50000 | seq 2 capture 50000 balance 50000
```

The authoritative fix is an explicit cancel call to the acquirer, which makes "no charge" a fact
rather than an observation. The age window is what a stub acquirer allows, and it is a weaker
guarantee that is named as one in the code.

### Verified live, three services together

`order-service` → `payment-service` (acquirer hanging 6 s, client timeout 1.5 s) → `inventory-service`,
all against a real Postgres. Nobody touched anything after the checkout request:

```
order state:  PAYMENT_UNRESOLVED     stock: 70 -> 62 available, on hand still 100
                                     (the holds are held; nothing was decided)

  -                  -> PENDING            order created from cart c5affb27...
  PENDING            -> STOCK_RESERVED     1 hold(s), ttl 900s
  STOCK_RESERVED     -> PAYMENT_UNRESOLVED acquirer_timeout: the acquirer did not answer
  PAYMENT_UNRESOLVED -> PAID               payment 952f6069-...
  PAID               -> CONFIRMED          livestock dispatch window 2026-09-15T14:00+05:30

order state:  CONFIRMED               stock: on hand 100 -> 92 (committed)
payment ledger:  seq 1 authorise 72000 | seq 2 capture 72000 balance 72000
```

That is the phase's acceptance criterion: **a checkout that survives a payment provider that never
answers.**

Also verified by hand: replay returns 200 rather than charging twice; a key reused for a different
amount is 409; partial refunds accumulate and the last one closes the payment; a retried refund with
the same key pays out once; an over-refund is 409; and the reconciler resolves a pending payment
with nobody asking.

### Measured

Local Postgres on the build container, **not k3d**.

| | |
|---|---|
| `payment-service` resident memory | **6 MiB** — against 361 MiB for `order-service` doing comparable work |
| `payment-service` release binary | 4.2 MiB |
| Tests | 24 in `payment-service` (money, ledger machine, acquirer); `order-service` up from 32 to 48 |

That memory difference is the argument for Rust here, stated as a measurement rather than a belief.

### What is stubbed, and what that costs

The service is real; the card network behind it is not. The stub models the case that matters — it
records the charge after the delay **whether or not the caller is still waiting** — and models
nothing else: no partial captures, no chargebacks, no 3-D Secure, no settlement files. Its memory is
in-process, so a restart makes previously recorded charges look like "no such charge", which is
worth knowing when reading a demo.

### Still unproven

- **Never run in k3d.** The commerce profile is now two JVMs, a Go service, a Rust service and
  Postgres on an 11 GB budget.
- ~~`payment-service` has no database tests.~~ **Closed** — 18 gated tests added against a real
  Postgres, covering the CHECK constraints, the append-only trigger and the two-resolver race. The
  crate became a lib plus a thin binary to make them possible, since a binary crate cannot be
  imported from `tests/`. Clippy then flagged `Money::sub` as shadowing `std::ops::Sub` on the
  newly-public API; it is `checked_sub` now, which says what it does and matches `i64::checked_sub`.
- The saga still is not crash-safe between taking money and committing holds. Phase 6.

---

## Phase 3 — `order-service`

Cart, the order state machine, the checkout saga with compensation, and livestock dispatch windows.
Java 21 / Spring Boot.

### The saga

```
  1. reserve    one hold per SKU in inventory-service    compensate: release
  2. authorise  take the money                           compensate: refund
  3. commit     turn every hold into a sale              compensate: refund
  4. confirm    fix the dispatch window                  --
```

**The ordering is the design.** Stock is held before money is taken, so a declined card costs a
released hold rather than a refund and an apology ([ADR 0012](docs/adr/0012-hold-stock-before-taking-money.md)).
There is no transition from `PAID` to `PAYMENT_FAILED`: once money is taken, the only way out is a
refund that says so by name.

### The bug worth reporting

The first implementation reserved every line inside one `@Transactional` method.
`aPartlyReservedOrderReleasesTheHoldsItAlreadyTook` failed against it: when the third line was
refused, the rollback erased the rows recording the first two holds — which by then **existed in
inventory-service** — so the compensation found nothing to release and real stock sat held until its
TTL expired.

A database transaction does not cover work that has already happened in another service. The record
of an external effect has to be committed as soon as it happens
([ADR 0013](docs/adr/0013-record-external-effects-outside-the-transaction.md)). The window is now
narrower rather than closed; an outbox closes it, and that is Phase 6.

Found by a test that asserted a compensation happened, not by review. `@Transactional` on a method
that reserves stock reads as careful rather than as a mistake.

### A platform defect found on the way

The `ResourceQuota` counted `limits.cpu`, which makes an explicit CPU limit **mandatory** on every
container; the `LimitRange` then supplied a default of `500m`. So every JVM service was being
CFS-throttled — exactly what [ADR 0006](docs/adr/0006-memory-limits-but-no-cpu-limits.md) exists to
prevent — by way of the namespace rather than the deployment, where nobody would look. The symptom
would have been latency spikes on an idle-looking node.

### Verified live, both services running together

A real `order-service` against a real `inventory-service` and a real Postgres:

```
happy path     6 neon tetra + 4 panda cory -> CONFIRMED, dispatchAt 2026-09-14T08:30Z
               stock: 70 -> 64 and 27 -> 23 available, on hand down by the same
               (committed: the fish have left the tank)

declined card  10 neon tetra + 5 panda cory -> PAYMENT_FAILED
               paymentRef null, both reservations RELEASED
               stock: 64 and 23, unchanged -- returned immediately, not in 15 minutes
```

The order's event trail shows the compensation, which is visible nowhere else:

```
-               -> PENDING          order created from cart 57e680e2...
PENDING         -> STOCK_RESERVED   2 hold(s), ttl 900s
STOCK_RESERVED  -> STOCK_RESERVED   released hold 3d904285... (payment declined)
STOCK_RESERVED  -> STOCK_RESERVED   released hold e25990b3... (payment declined)
STOCK_RESERVED  -> PAYMENT_FAILED   card declined (stub gateway configured to decline)
```

That is the phase's acceptance criterion: **an order that survives a payment failure without
stranding stock.**

### Measured

Local Postgres on the build container, **not k3d**.

| | |
|---|---|
| Whole failed checkout (2 reservations, 2 releases, 5 persisted transitions) | 107 ms |
| Checkout requests, mean | 69 ms (7 requests, including first-call JIT warm-up; max 193 ms) |
| `order-service` resident memory | 361 MiB, **with no cgroup limit** — the JVM sized its heap from host RAM |
| `inventory-service` alongside it | 14 MiB |
| Tests | 32: 18 domain, 6 HTTP client, 8 saga against a real Postgres |

### Dispatch windows

Livestock leaves Monday, Tuesday or Wednesday only, before a 14:00 cut-off in the shop's local time;
a bag posted on Thursday sits in a depot over the weekend. So an order placed Thursday afternoon is
confirmed, paid for, and waiting for Monday — a state no event will end, only the clock.

`dispatchable` is derived (`now() >= dispatch_at`), never stored, and there is no `AWAITING_DISPATCH`
state. The dispatch watcher marks the moment for the notification service and is not load-bearing —
the same rule as the reaper ([ADR 0011](docs/adr/0011-derived-state-over-stored-state.md)).

### Still unproven

- **Never run in k3d.** Two JVMs, Postgres and a Go service together is what the commerce profile now
  asks of an 11 GB budget, and that has not been tried.
- **The saga is not crash-safe.** If the process dies between taking the money and committing the
  holds, the holds expire by themselves — so the stock returns — but the refund never happens. Only
  the event trail would show it. Phase 6, with an outbox and NATS.
- `payment-service` does not exist; the stub has no ledger, no idempotency of its own, and no outcome
  between approved and declined. Nothing here shows the saga surviving a payment provider *timing
  out*, which is the failure a real one is mostly designed around.

---

## Phase 1 verification — the services were run for the first time

Phase 1 had been written, reviewed and committed, and never executed. Running it found two defects
that would have crash-looped `catalog-service` on its first boot in the cluster. Both were found by
`ddl-auto: validate`, which is the setting's entire purpose.

### Defect 1 — `currency CHAR(3)` against a `String` field

Hibernate: *wrong column type encountered in column [currency]; found [bpchar], but expecting
[varchar(3)]*. The column is now `VARCHAR(3)`. `CHAR` is blank-padded in Postgres, which makes
comparison and trimming a source of surprise, and buys nothing over a length-limited `VARCHAR`.

### Defect 2 — `NUMERIC(4,1)` water parameters against `double` fields

Hibernate: *found [numeric], but expecting [float(53)]*. The first attempt at a fix — adding
`precision`/`scale` to the `double` fields — was refused outright: *"scale has no meaning for SQL
floating point types"*. That error is the mapping telling the truth. An exact column needs an exact
field, so the seven measurements on `SpeciesProfile` are now `BigDecimal`, converted to plain
numbers in the DTO so the published JSON is unchanged.

It matters beyond the boot failure: `aquatics-advisor` computes interval overlap across every
inhabitant of a tank, and a 0.1 step that is not exactly 0.1 turns "6.8 is within 6.8–7.5" into a
coin toss at the boundary.

### Defect 3 — `inventory-service` seeded SKUs that do not exist

The Phase 2 tank seed used invented SKUs (`FSH-NEON-TETRA`) and a comment claiming they matched
`catalog-service`. They did not. They are now the catalog's own (`FSH-NEO-01`), verified against its
seed data. The SKU string is the entire contract between the two services — no shared schema, no
shared database, no foreign key — so a drift would have shown the customer a product that could not
be reserved, with nothing in either database to say why.

### Measured

Against local Postgres 16, on the build container, **not in k3d**.

| | |
|---|---|
| `catalog-service` time to readiness | 5.8 s (startup probe allows 150 s) |
| `catalog-service` resident memory | 338 MiB — but with **no cgroup limit**, so the JVM sized its heap from 16 GB of host RAM. This is not what it would use under the 640Mi limit, and is not evidence the limit is right. |
| `storefront` resident memory | 76 MiB |
| Flyway | 2 migrations applied to an empty database, clean |
| Catalog API | categories, category listing, product detail with care profile, and search all answer correctly |
| Storefront | home, category and product pages render server-side against the live catalog |

### Verified by hand: the liveness/readiness split

With `catalog-service` stopped:

```
/healthz  (liveness)  200   <- the pod is healthy; Kubernetes must not restart it
/readyz   (readiness) 503   <- the pod leaves the Service endpoints
/         (page)      502
```

That is the behaviour the design claimed and had never demonstrated: a catalog outage degrades the
page, and does not turn a partial outage into a restart loop across every storefront replica.

### Still unproven

Neither service has run in k3d. Probes, resource limits, the ingress and the TLS path are written
and reviewed, not exercised.

---

## Phase 2 — `inventory-service`

Tank-scoped, TTL-bounded, idempotent stock reservations. Go, Postgres, distroless.

### What it does

Holds stock in physical tanks for orders that have not been paid for yet. A hold subtracts from
what may be sold and does not remove fish from the glass; it is committed into a sale, released
early, or it simply expires.

### The idea the service is built around

A promise about stock is time-bounded, and **no background job has to be healthy for that to be
true.** Availability is computed as

```
quantity_on_hand − Σ holds WHERE state = 'held' AND expires_at > now()
```

so an expired hold stops holding stock at the instant it expires. The reaper only makes the `state`
column honest and keeps the active-holds gauge current. Stopped, slow, or running in all three
replicas at once, it cannot double-sell or strand stock
([ADR 0008](docs/adr/0008-availability-is-computed-from-the-deadline.md)).

### The bug worth reporting

The first version of `Reserve` locked the tank rows and read their availability in one
`SELECT ... FOR UPDATE`. It oversold, and the concurrency test caught it: twenty goroutines racing
for eight fish, two at a time, and seven got through instead of four.

Under READ COMMITTED a statement's snapshot is taken when the statement begins — **before** it
blocks on the row lock. The waiting transaction acquires the lock correctly and then reads
availability from a snapshot taken before the transaction ahead of it inserted its lines. The lock
was right; the number it protected was stale. The fix is to lock in one statement and read in a
second, whose fresh snapshot includes the committed work
([ADR 0010](docs/adr/0010-lock-then-read-in-two-statements.md)).

This is the kind of defect that does not appear in a demo, does not appear in a single-threaded
test, and appears in production as an angry customer.

### Measured

Against a local Postgres 16 on a build container — **not in k3d, and not under sustained load.**
Order of magnitude, not cluster figures.

| | |
|---|---|
| Resident memory, idle | 13.9 MiB |
| Resident memory, after 200 reservations | 17.0 MiB |
| `POST /v1/reservations`, mean | 2.5 ms |
| `POST /v1/reservations`, distribution | 39 of 40 under 5 ms; all under 10 ms |
| 300 concurrent reservations against 95 units of stock | 95 succeeded, 205 refused, 0 oversold |
| Tests | 10 unit, 14 integration, green under `-race -count=3` |

Verified end to end by hand, against a real Postgres: a hold placed with a 6 s TTL, stock at zero
while it was live, and stock back at six with the reservation reading `expired` seven seconds
later — with the commit attempt refused with `409 reservation_expired`.

### Notable implementation details

- `Idempotency-Key` is **required**, and bound to a SHA-256 digest of the canonical request. Replay
  returns 200 with the original; a reused key with a different body is a 409; a *refused*
  reservation rolls back its key so a smaller retry with the same key works
  ([ADR 0009](docs/adr/0009-mandatory-idempotency-key.md)).
- Allocation is best-fit then largest-first: if one tank can cover the order, use the smallest such
  tank, because livestock from one tank ships as one bag. **Cost: fragmentation.**
- Quarantined tanks appear in the stock endpoint with `available: 0` and are never allocated from.
  Hiding them would make the API and the shop floor disagree.
- Schema migrations run at startup behind a Postgres advisory lock, so several starting pods cannot
  run `CREATE TABLE` concurrently — without it, a rolling update crash-loops one pod on "relation
  already exists", which reads as a broken image.
- The container has **no writable mount at all**. A static Go binary does not need `/tmp` the way
  the JVM does.
- Liveness does not touch Postgres; readiness does. A database outage must not make Kubernetes
  restart every healthy pod.

### Still unproven

- **The service has never run in k3d.** It has run against a local Postgres only. Probes, the
  resource limits, the startup-probe window and the ConfigMap wiring are written and reviewed, not
  exercised.
- No load test. The latency figures are single-threaded.
- Compensation is not built: nothing yet calls `release` when a payment fails. That is Phase 3,
  when `order-service` and the saga arrive.

---

## Phase 1 — `catalog-service`, `storefront`, the cluster

Java 21 / Spring Boot catalog with Flyway-owned schema and twelve seeded species with real care
parameters; a Fastify BFF rendering HTML on the server; Postgres, ingress-nginx, cert-manager,
namespace quota and limit range on a single-node k3d cluster.

### Measured

**Nothing.** Every memory figure in `docs/architecture.md` — the whole profile table — is an
estimate, and `./scripts/bootstrap.sh` has not been run on a machine that has Docker. Replacing
those figures with `kubectl top pods -A` output is the first open item in
[docs/context_summary.md](docs/context_summary.md).

### Known gaps

- Secrets are plaintext in Git. The largest gap in the repository; Phase 5 replaces it.
- Single-node cluster: PodDisruptionBudgets, anti-affinity and node drains cannot be exercised.
- The AWS layer has never been applied.
