# Agent learnings — external memory scaffolding

This file is not a changelog and not a second `RELEASE-NOTES.md`. It exists so that an agent with
no memory of a previous session can start one step smarter than the last one did: it holds
mistakes that were actually made, the pattern behind each one, and the better approach found —
often by checking outside knowledge, not just re-reading this codebase — before or after making
it. `CLAUDE.md` holds settled facts about this repository. `docs/context_summary.md` holds current
state. This file holds judgment: the kind of thing you only know because something went wrong
once.

## How to use this file

**Before starting non-trivial work:** read this file, `CLAUDE.md`, and `docs/context_summary.md`,
in that order. If the task resembles something below, don't repeat the mistake. If the task
involves a technology or decision this file has no entry for and the choice is expensive to
reverse, check current best practice (a real search, not assumed prior knowledge — a security or
infra recommendation from training data can be stale) before writing code, and record what you
found under "Researched before starting," even if you end up not needing it this session.

**When you make a mistake, or catch one from a previous session while verifying something:** add
an entry under "Mistakes and lessons." Keep it short — what happened, the pattern to watch for,
where the real fix lives (a file, a commit, an ADR) so this file doesn't have to re-explain code
that already explains itself. This file is not the place for the full story; it's the index that
tells you which story is worth reading.

**Keep this file small on purpose.** An entry that has become a structural guarantee — enforced by
a test, a schema constraint, or already stated as a rule in `CLAUDE.md`'s "Rules that are not
obvious" — should be *removed* from here, not kept forever: once it can't recur silently, it's no
longer a judgment call, and a growing file that never prunes defeats the reason this exists
(spending fewer tokens re-deriving context, not more re-reading a file that only grows). Fold
related entries together instead of stacking near-duplicates. This file existing at all is the
experiment; keeping it lean is the point of running it.

---

## Mistakes and lessons, newest first

### 2026-09-26 — Filing by genus put a 10 cm fish on the Large page

**What happened:** V17 filed *Synodontis nigriventris* under `catfish-synodontis` because of its
genus; that section hangs under `catfish-large`, and this is the one small Synodontis. Nobody saw it
until `CatalogApiTest.everyFishOnTheSmallCatfishPageFitsASmallTank` ran. Fixed forward in `V21`.
**Pattern:** a catalogue tree mixes two axes (taxonomy and tank size). When adding fish, file by the
axis the parent section encodes, and run `CatalogApiTest` after any catalogue migration — its
count assertions are stale, but its data-rule assertions are not.

### 2026-09-26 — A caption or retailer listing is a claim about the fish, not proof; check by eye

**What happened:** `asian-arowana-super-red.jpg` passed V15's bar because its Commons caption said
"Honglongyu" (red dragon fish) — but the fish photographed olive-yellow, and the shop owner caught
it. The same week, liveaquaria.com's copy (used as a fact source for V20's descriptions) put the
zebra loach in Indonesia and the dwarf chain loach in India (each is the other way round), and filed
the Boeseman's rainbow under *Telmatherina*. Their care numbers were looser than ours too: a 189 L
minimum tank for a 30 cm bala shark.
**Pattern:** text attached to an image or a listing is someone's claim. For a morph, compare what
the photo shows with a key feature (red tail golden = gold lower rows + dark back; crossback = gold
over the back) — the MonsterFishKeepers "Arowana species/varieties" thread is a usable visual key.
For facts, cross-check a retailer against the literature before putting them on a product page.
**Where it lives:** `species/CREDITS.md` (Pexels section), `V20__species_descriptions.sql` header.

### 2026-09-26 — Hashing static files right after `rollout restart` can hit the old pod

**What happened:** after redeploying the storefront, all five new photos md5'd to the same hash
— looked like a 404 page. They were fine: the requests landed on the terminating old ReplicaSet.
Re-checked by byte size a minute later and every file matched.
**Pattern:** `rollout status` returning does not mean the old pod has stopped answering. Verify
after old pods are gone (`kubectl get pods`), and compare sizes/hashes, not "did it return 200".

### 2026-09-26 — SQL text generated from Python: dollar-quote it

**What happened:** V17's generator held prose in single-quoted Python literals and wrote
`'Kerala''s'` meaning an escaped SQL quote — Python reads that as two adjacent literals and joins
them into `Keralas`. Every apostrophe in V17 was lost; V19 corrected it forward.
**Pattern:** never hand-escape SQL quotes inside another language's string literals. V20 wraps
every value in `$d$...$d$`, which needs no escaping at all, and asserts the delimiter is absent.

### 2026-09-24 — CSS Grid's column count is fixed for the whole grid, not recalculated per row

**What happened:** `.grid`/`.tiles` used `repeat(auto-fit, minmax(260px, 1fr))`. `auto-fit` does
fix the case where *every* row has fewer items than would fill it — it collapses the unused tracks
and lets `1fr` redistribute the freed width. It does **not** fix a *ragged last row* in a
multi-row grid: six product cards splitting 4-then-2 left the second row's two cards stranded at
their base width with a visible gap beside them, because the grid computed "4 columns fit" once for
the whole layout and reserved those four columns on every row, whether or not that row had four
items in it.

**Lesson:** for a card/tile layout where the item count is data-driven and won't reliably divide
evenly into full rows, use flexbox (`display:flex;flex-wrap:wrap` with `flex:1 1 <basis>` on the
items) instead of CSS Grid. A flex row distributes its own leftover width among only the items
actually in it, full or ragged alike — Grid's column-track model has no equivalent per-row
behavior. Uncapped `flex-grow` has its own failure mode (a single item alone on a wide screen's
last row grows to the full row width), so pair it with a sensible `max-width` on the item.

**Where the fix lives:** `services/storefront/public/styles.css`, `.grid`/`.card` and
`.tiles`/`.tile`.

### 2026-09-24 — `position: sticky` interacts badly with non-standard screenshot capture, producing bugs that aren't real

**What happened:** verifying a redesign with a headless Chromium, two different capture techniques
each produced what looked like a real layout bug: `page.screenshot({ fullPage: true })` made a
sticky header appear to overlap the hero heading below it; resizing the viewport to the full
document height (a workaround tried next) produced faint duplicate nav text hovering above the
footer. Neither was reproducible in the live DOM (`getBoundingClientRect()` showed zero overlap) or
in an ordinary viewport-sized screenshot taken after a normal scroll.

**Lesson:** `position: sticky` elements are exactly the kind of thing that breaks under a
screenshot tool's own capture tricks — `fullPage` stitching and artificially-tall viewports both
resize or reflow the page in ways a real user's browser never does, and sticky positioning is
computed relative to the viewport, so those tricks can produce compositing artifacts that don't
exist for anyone actually scrolling the page. When a capture shows something that looks like a
layout bug on a page with sticky elements, check the live computed layout
(`getBoundingClientRect()`, or just a normal scroll-and-screenshot at the real viewport size)
before trusting the capture and reporting a bug that isn't there.

### 2026-09-23 — A background agent's own migration comments described work that was never saved to disk

**What happened:** An Opus subagent sourcing photos for 40 category tiles and 14 new species got
rate-limited mid-task. It had already written two Flyway migrations with detailed, specific,
real-sounding provenance ("Honglongyu" / "Qua boi" trade names for arowana morphs, exact rejected
Commons candidates and why) — but zero of the 54 image files it described actually existed on
disk. The migrations would have set `image_key` to files that didn't exist, exactly the defect
this project's own history (V5 → V7) already named: "a key is a promise that the file exists."

**Lesson:** After resuming from *any* interruption (a rate limit, a crash, a context compaction),
verify referenced files actually exist before trusting what a migration, a commit message, or an
agent's own comment claims about them — even when the prose is detailed and confident. Detailed
prose is not evidence of completed work; a file listing is. `find <dir> -newer <known-good-file>`
across the whole repo is a fast way to see what a session actually touched versus what it wrote
about touching.

**Where the fix lives:** handled by re-dispatching the sourcing work rather than applying the
migrations as written; see the `V14`/`V15` catalog-service migrations once merged.

### 2026-09-23 — A missing `optional: true` on `secretKeyRef` takes the whole pod down, not just the feature that needs it

**What happened:** Wiring a new encryption-key env var via `secretKeyRef` without `optional: true`
means kubelet refuses to start the container at all when the Secret doesn't exist yet — the pod
sits in `CreateContainerConfigError` forever. For `order-service`, that would have taken the
checkout saga down for the sake of a bolt-on enquiry form, a blast radius wildly out of proportion
to the feature.

**Lesson:** Any new `secretKeyRef`/`configMapKeyRef` env var on a service that already does
something load-bearing needs an explicit decision about what happens when the referenced object
doesn't exist yet — and the default (unset ⇒ pod won't start) is very rarely the right answer for
an optional feature riding inside a critical service. Same category as `CLAUDE.md`'s existing
`runAsUser: 65532` lesson: a thing that "should just work" needs the specific flag that makes the
failure mode match the size of what actually failed.

**Where the fix lives:** `platform-repo/dev/order/deployment.yaml`, `docs/adr/0021-*.md`
("Decision" section, the fail-fast paragraph).

### 2026-09-23 — Spring drops a custom exception's message from an HTTP response unless told to globally

**What happened:** A `503` response body for a missing-encryption-key error tested fine against
`MockMvc` (which reads the exception object directly) but came back as a bare
`{"status":503,"error":"Service Unavailable"}` over real HTTP — Spring omits the exception message
from the wire response unless `server.error.include-message` is enabled globally, which would also
leak every other handler's messages just to fix this one endpoint.

**Lesson:** A test against `MockMvc` or an in-process call is not the same claim as a test against
a real HTTP response body. Always curl the actual running process for anything where the response
*body*, not just the status code, matters to a caller.

**Where the fix lives:** `InquiryDtos.InquiryUnavailable` — an explicit response DTO instead of
relying on Spring's default error shape.

### 2026-09-23 — A naive `grep` for a CSS class produces false positives when the same string appears in unrelated JS

**What happened:** Checking for leftover placeholder images with `grep -c "shot-none"` on rendered
HTML counted every successful `<img>` tag too, because its `onerror` handler contains the literal
JS string `this.classList.add('shot-none')` — present on every image regardless of whether it
loads. The real signal is the placeholder `<span class="shot shot-none">`, not the substring.

**Lesson:** When grepping rendered output for a "did this actually happen" check, grep for the
most specific unambiguous marker of the state you're checking, not a class name or string that
could also appear in surrounding markup, scripts, or attributes for an unrelated reason. A quick
sanity pass ("does this count make sense?") would have caught it before reporting it.

### 16–17 September 2026 — Review is not verification; only running catches build-time toolchain drift

**What happened:** Three separate defects — `runAsNonRoot: true` without an explicit UID,
`inventory-service`'s Dockerfile pinned a Go version older than `go.mod` declared, and
`payment-service`'s Dockerfile pinned a Rust version older than what `Cargo.lock`'s resolved
dependencies actually needed — had all been reviewed and looked correct. None surfaced until the
images were actually built and run in k3d for the first time.

**Lesson:** A pinned toolchain version in a Dockerfile is a claim that goes stale silently; nothing
about `go build`/`cargo build`/`mvn` on a dev machine (using whatever local toolchain happens to be
installed) will catch drift against what's pinned in the image. Only building the actual image
does. This generalizes past Dockerfiles: any config that duplicates a fact declared elsewhere
(a version, a count, a schema) can drift, and review reads the duplicate as if it were the source
of truth.

**Where the fix lives:** `CLAUDE.md`, "How this project works" → "Verify by running, not by
reading."

### 16 September 2026 — `READ COMMITTED`'s snapshot is taken before a statement blocks on a lock, not after

**What happened:** `inventory-service`'s first `Reserve` implementation locked tank rows and read
availability in one `SELECT ... FOR UPDATE`. Twenty goroutines racing for eight units of stock, two
at a time, let seven through instead of four. The lock itself was correct; the number it protected
was read from a snapshot taken *before* the transaction blocked on the lock, so it missed
commits made by whoever was ahead of it in the queue.

**Lesson:** Under `READ COMMITTED`, a statement's snapshot is fixed when the statement begins, not
when it acquires whatever lock it's waiting on. Locking and reading the value the lock is meant to
protect have to be two separate statements, so the read's snapshot is taken *after* the lock is
held. This class of bug does not show up in a demo or a single-threaded test — it needs a real
concurrency test to catch, and one is worth writing before trusting any "lock then check" logic
under this isolation level.

**Where the fix lives:** `docs/adr/0010-lock-then-read-in-two-statements.md`.

### 15 September 2026 — `open-in-view: false` without a join-fetch on every DTO-feeding query produces a 500 that looks unrelated to the change that caused it

**What happened:** `GET /api/products` returned 500 because the inherited `findAll()` doesn't
join-fetch `category`, and Hibernate can't lazy-load outside the (deliberately disabled) view's
transaction. It had already been seen once in an earlier session and misattributed to a shell
one-liner; a second real caller hitting the same endpoint is what actually exposed it.

**Lesson:** `open-in-view: false` makes every repository method that feeds a DTO a place a
lazy-loading exception can hide, and the inherited `findAll()`/`findById()` methods are the trap —
they look like they should work. When adding a new consumer of an existing query, check that it
join-fetches everything the DTO actually reads; don't assume an existing method is safe just
because nothing has failed yet.

**Where the fix lives:** `CLAUDE.md`, "Rules that are not obvious."

---

## Researched before starting

Entries here record what was checked against current outside knowledge (not just this repo, and
not just training-data recall) before a decision, and what was found — so the next session doesn't
re-research the same question from zero.

### 2026-09-23 — Production-grade key management for a symmetric encryption key on AWS

**Question:** `docs/adr/0021-*.md` needed an honest "what would the real answer look like" section
for the `tank_inquiry` encryption key, without actually building it (no AWS account exists to
build it against).

**Finding:** The standard managed pattern is envelope encryption via **AWS KMS**, with the
encrypted data key stored in **AWS Secrets Manager** and fetched at startup through an IAM role
(IRSA on EKS) — no long-lived plaintext key ever sits in a Kubernetes Secret. KMS gives centralized
rotation, per-call audit logging via CloudTrail, and IAM-scoped access to the *decrypt* operation
independent of who can read the encrypted rows themselves — which is the specific gap a bare
`kubectl create secret` can't close (holding the key and holding read access to the table are the
same fact today; under KMS they separate). Secrets Manager's own rotation-Lambda mechanism only
solves half the problem for an encryption key specifically: rotating the key without re-encrypting
existing ciphertext just makes old rows unreadable, so a rotation Lambda for this use case has to
do both.

**Applied where:** `docs/adr/0021-encrypt-enquiry-contact-details-in-postgres.md`, "Future:
production key management (planned, not built)."
