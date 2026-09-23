# 21. Custom tank enquiries live in order-service, with contact details encrypted by Postgres

**Status:** Accepted · **Phase:** commerce profile (v2 storefront)

## Context

The shop wants a prominent section on the front page where a visitor describes the tank and
stocking they want, and leaves an email address and a phone number so the shop can follow up.
Three things have to be decided: where the data lives, how it is protected, and who can read it
back.

The third is the awkward one. This repository has **no authentication anywhere** — not on the
storefront, not on any service API, not on `staff-portal`, which is read-only precisely because
there is nobody to authorise a write. An enquiry is the first customer PII this platform stores
that is not attached to a commercial transaction the customer already knows about, and it is
stored by a form that anyone on the internet can submit to.

[ADR 0003](0003-one-postgres-database-per-service.md) already settled that each service gets its
own database and login role; [ADR 0006](0006-memory-limits-but-no-cpu-limits.md) and the memory
profiles in [context_summary.md](../context_summary.md) established that a service in this project
costs real, budgeted memory; [payment-service](../../services/payment-service) established the
house habit of pushing an invariant that must not be lost into Postgres itself — its ledger is
append-only because of a trigger, not because of a code review.

`CLAUDE.md` also records, as known gap 2, that every secret in this repository is plaintext in Git
and that External Secrets + SOPS is *planned, not built*.

## Decision

**One new capability inside `order-service`, not a ninth service.** `order-service` already owns
"a customer told us what they want and left an email address" — that is exactly what
`CustomerOrder.email` is. It already has a Postgres database, a Flyway sequence, a login role, a
Dockerfile, a distroless image, a deployment, a quota share and probes. The new work is one
write-mostly table and one `POST` handler.

**A new table, `tank_inquiry`, touching nothing else.** `V3__tank_inquiry.sql` adds it. It has no
foreign key to `customer_order`, no state column, no reservation, no saga step, no event row. An
enquiry is not a checkout and must not be able to become one by accident.

**The database encrypts, not the application.** `CREATE EXTENSION pgcrypto`, then
`pgp_sym_encrypt(…, key, 'cipher-algo=aes256, compress-algo=0')` on insert and `pgp_sym_decrypt`
on the one read path that exists. The columns are `BYTEA`. The plaintext is never written to a
row, never reaches the WAL, never appears in a base backup, and is never what `SELECT *` returns.
Compression is off deliberately: PGP would otherwise shrink a repetitive message before encrypting
it and leak something about the content in the ciphertext length, for a saving worth nothing on a
4,000-character cap.

`tank_inquiry` is the only table in this service that is **not** a JPA entity, and that is part of
the decision. A mapped entity with an `AttributeConverter` would keep the decrypted email in
Hibernate's first-level cache, in its dirty-check snapshot, and in whatever a future `findAll()`
returned. `TankInquiryRepository` uses plain SQL so the plaintext lives for the length of one
`INSERT`.

**The free-text message is encrypted too**, not just the email and phone. It is the field most
likely to carry identifying detail the form never asked for — "deliver to 14 Park Street, ask for
Priya" — and a column left in the clear because nobody expected PII in it is exactly how PII ends
up in the clear. One plaintext column survives: `message_chars`, the length. It exists so an
operator who is *not* entitled to read enquiries can still answer "are they arriving, and are they
empty?".

**The key comes from a Kubernetes Secret that is not in Git.** `INQUIRY_ENCRYPTION_KEY` is wired
into `platform-repo/dev/order/deployment.yaml` with the same `secretKeyRef` mechanism that
already supplies `DB_PASSWORD` — and deliberately from a *different* Secret, because
`postgres-credentials` is checked in as plaintext and this must not be. The Secret is created by
hand:

```bash
kubectl create secret generic order-inquiry-key \
  --namespace aquashop-dev \
  --from-literal=INQUIRY_ENCRYPTION_KEY="$(openssl rand -base64 48)"
```

`docs/runbooks/rotate-or-create-the-inquiry-key.md` is the procedure.

**A missing key disables this one endpoint and nothing else.** There is no fallback key — a
baked-in default is the genuinely dangerous option, because it accepts submissions and writes rows
that *look* encrypted while being readable by anyone holding the source, and then makes those same
rows permanently undecryptable the day the real key arrives, with nobody finding out until someone
tries to phone a customer. So the write is refused. But it is refused **at the endpoint, not at
startup**: `order-service` boots normally, logs one `WARN`, serves carts, checkout, orders and the
saga exactly as before, and answers `POST /v1/inquiries` with `503` and a body naming the runbook.

The first shape of this ADR refused to start the Spring context, and that was wrong. `order-service`
is also the home of the checkout saga — the most hardened, most crash-tested, most k3d-verified path
in this platform — and letting a forgotten Kubernetes Secret for a bolt-on marketing form take
commerce down is a blast radius wildly out of proportion to the feature that caused it. **The reach
of a failure should match the size of the thing that failed.** Nothing about the safety property
changes between the two shapes: no fallback key either way, no plaintext written either way, no row
accepted that cannot be encrypted either way. Only the collateral damage differs.

Two things make this real rather than aspirational, and both are easy to get wrong:

- `secretKeyRef` in `platform-repo/dev/order/deployment.yaml` carries **`optional: true`**. Without
  it kubelet refuses to start a container whose env it cannot resolve, the pod sits in
  `CreateContainerConfigError`, and the Java-side decision is moot.
- The `503` carries an **explicit body** (`reason`, `runbook`, `affects`) rather than Spring's
  default error shape, which omits the exception message unless `server.error.include-message` is
  turned on globally — and turning that on would leak every other handler's exception messages to
  fix one endpoint. A `503` that says only "Service Unavailable" sends whoever is debugging it to
  the logs of a service that looks perfectly healthy.

A key shorter than 16 characters is treated the same way: refused, not accepted as a passphrase.
Verified on a real running process — missing key and a 7-character placeholder both boot, both serve
carts and orders, both answer `503` on the enquiry endpoint with the runbook named in the body.

**Write-only, in this pass.** `POST /v1/inquiries` returns `201` with an id and nothing else — no
email, no phone, no message echoed into a response body, a BFF's memory or a proxy log. There is
no `GET /v1/inquiries/{id}`, no list, no search, and no `Location` header, because a `Location`
pointing at a 404 is a promise the service does not keep. The storefront posts a plain HTML form
([ADR 0005](0005-server-rendered-bff-not-an-spa.md)), validates shallowly, and redirects to a
confirmation page so a refresh cannot submit twice.

## Consequences

The storefront gains its first `POST` route and its first body parser (`@fastify/formbody`), and
its first call to `order-service` (`ORDER_BASE_URL`). Storefront readiness deliberately still
checks only the catalog: a shop that cannot reach `order-service` still sells everything it has,
and failing readiness to protect one form would take the site down.

`core` profile deploys the storefront without `order-service`, so the form is visible there and
every submission fails — honestly (502, the customer's text kept) but it fails. This feature
belongs to `commerce` and above.

**Cost: blast-radius isolation, given up knowingly.** ADR 0003 made this exact trade for databases
and named it. A separate `enquiry-service` would mean a checkout saga bug, a JVM OOM or a bad
deploy of `order-service` could not take enquiries down with it, and the enquiry key would sit in
a process that has no business knowing anything about payments. That is a real property and it is
being sold for one Dockerfile, one image, one deployment, one quota share, one login role and one
more JVM in a 4 Gi namespace on an 11 GB machine. The memory-profile discipline in this project is
load-bearing and a ninth service for one write-mostly table does not earn its ~230 MiB.

**Cost: the key travels to Postgres as a bind parameter on every insert.** This is inherent to
doing symmetric crypto *inside* the database. Anyone who can read the Postgres server log with
`log_statement = 'all'` and parameter logging enabled, or who can attach to the server process,
sees the key. Application-level crypto would keep the key in the JVM — at the price of the
plaintext being what Hibernate, the WAL and every future migration see. Neither option is
strictly safer; this one was chosen because the threat it addresses (someone reading the table)
is the one that actually exists here, and the one it does not address (someone who can already
read the database server's logs or memory) has already lost.

**Cost: the key management is better than the rest of this repository and still incomplete.** It
is a real improvement — this is the first secret in the project that is not plaintext in Git. It
is not a solution. There is **no rotation**: changing the key makes every existing row
permanently undecryptable, because nothing re-encrypts them and `pgp_sym_decrypt` fails loudly on
a wrong key rather than returning rubbish (verified). There is **no secrets manager**: the value
exists in one `kubectl create secret` invocation in one person's shell history and in etcd,
base64-encoded, which is encoding and not encryption.

**Cost: the feature can be silently off.** This is the price of the smaller blast radius, and it is
a real price, not a free lunch. A cluster rebuilt without the manual `kubectl create secret` step
comes up entirely green — every pod `Running`, every probe passing, `kubectl get all` showing
nothing wrong — while the enquiry form quietly refuses every customer who uses it. The earlier
crash-loop design could not do that: it was impossible to miss. Three things are the mitigation, and
they are deliberately noisy: `TankInquiryRepository` logs one `WARN` at boot naming the runbook;
`bootstrap.sh` checks for the Secret and warns before applying the `commerce` profile; and the
storefront renders a 503 as "this form is not taking enquiries at the moment — that is our fault,
not yours", telling the customer to email the shop instead of retrying something that cannot work.
None of those is as loud as a pod that will not start. **The trade was made knowingly: a feature
that is off is recoverable in one command, and a checkout path that is down is not.**

**Cost: the shop cannot read its own enquiries.** Today the only way to see a submission is a
`psql` session held by someone who also holds the key. That is a genuine gap, not a security
feature dressed up as one — a form the shop cannot read is a form that does not work. It is left
open rather than closed under time pressure because the honest fix is a `staff-portal` read path,
and `staff-portal` has no authentication, which would make an "encrypted" table readable by
anyone who can reach the staff subdomain. The follow-up is authentication first, then a decrypt
view in `staff-portal`, in that order. `TankInquiryRepository.findById` exists and is exercised
by tests precisely so that path has a seam to build on.

**Cost: a public, unauthenticated `POST` with no rate limiting.** It is a spam target and nothing
in this pass changes that. No CAPTCHA, no per-IP limit, no honeypot field, no proof of work. The
bounds that do exist are a 16 KiB request body limit at the BFF, a 4,000-character message cap and
field-shape validation on both sides — enough to stop one request being expensive, not enough to
stop many cheap ones. A bespoke limiter written now would be an unreviewed security control; the
right answer is ingress-nginx's `limit-rps` annotation or a real WAF at the edge, and it is
deliberately not being invented here. **Anyone deploying this beyond a local k3d demo must fix
this first.**

**Cost: no equality, no deduplication, no lookup by address.** `pgp_sym_encrypt` is
non-deterministic by design — a fresh session key and IV per call — so two enquiries from the
same customer produce different bytes, and there is no index and no unique constraint on these
columns. "Has this person written before?" is not answerable without decrypting the whole table.
That is the price of the property that makes the ciphertext worth storing, and a deterministic
scheme that allowed the lookup would also let anyone with read access group enquiries by customer
without the key.

## Future: production key management (planned, not built)

Everything above is honest about what a `kubectl create secret` gives you: better than plaintext
in Git, and still one static value sitting base64-encoded in etcd with no rotation, no audit trail
and no revocation. Same category of gap as `CLAUDE.md`'s known gap 2 (External Secrets + SOPS,
"planned, not built") — this ADR does not close that gap, it just doesn't make it worse for one
new key.

The production-shaped answer, on the AWS target this platform is designed for and has never
applied to:

- **AWS KMS holds the real key.** `order-service` never sees a long-lived symmetric secret at
  all. At startup it calls KMS (via an IAM role bound to its pod through IRSA — no credentials in
  config, none in the image) to decrypt a small ciphertext blob into the passphrase Postgres uses
  for `pgp_sym_encrypt`/`pgp_sym_decrypt`. This is envelope encryption: KMS protects the key that
  protects the data, rather than the data's key being the thing stored and handed around.
- **AWS Secrets Manager holds the encrypted blob**, not the raw key — KMS decrypts it, Secrets
  Manager just stores and versions it. Secrets Manager's rotation-Lambda mechanism is what turns
  "no rotation" from a permanent property of this design into a scheduled one, *if* a rotation
  also re-encrypts every existing `tank_inquiry` row with the new key — rotation without
  re-encryption is exactly the "every old row is now unreadable" failure this ADR already accepts
  today, so a rotation Lambda here is not optional plumbing, it is half the feature.
- **CloudTrail gets an entry for every decrypt.** The gap this ADR cannot close today — "the shop
  cannot read its own enquiries, and there is no log of who did" — KMS closes for free: every use
  of the key is an auditable API call, tied to an IAM principal, whether that's `order-service`'s
  own role or a future `staff-portal` decrypt path.
- **IAM scopes who can ask KMS to decrypt at all**, independent of who can read the Postgres rows.
  Today, holding the key *is* holding the read access — the two are the same fact. Under KMS they
  separate: a `psql` session with full table access still can't decrypt anything without an IAM
  principal KMS trusts, which is a real second factor this design doesn't have.

None of this is built, and it shouldn't be built speculatively — there is no AWS account behind
this platform to test it against, `LocalStack` cannot emulate KMS's actual guarantees (see the
Terraform-validation decision in `context_summary.md`), and a KMS integration nobody can run is
worse than an honestly-documented gap. This section exists so the shape of the real fix is on
record rather than rediscovered, the same way `CLAUDE.md` already does for secrets generally.
