# Runbooks

One page per thing that goes wrong, written to be followed at 02:00 by someone who did not write
the service. Each names the symptom first, because the symptom is what the person has.

| Runbook | Symptom that brings you here |
|---|---|
| [stock-looks-wrong.md](stock-looks-wrong.md) | The shop floor and the API disagree about how many fish there are |
| [pod-oomkilled.md](pod-oomkilled.md) | A pod is restarting; `kubectl describe` says `OOMKilled` or exit code 137 |
| [order-stuck-or-wrong.md](order-stuck-or-wrong.md) | An order is in an unexpected state, has not shipped, or a checkout is suspected of losing stock |
| [add-a-service-database.md](add-a-service-database.md) | A new service crash-loops on "database does not exist" against a Postgres that already has data |
| [argocd-blocks-an-emergency-fix.md](argocd-blocks-an-emergency-fix.md) | Your `kubectl edit` was reverted within seconds |
| [rotate-or-create-the-inquiry-key.md](rotate-or-create-the-inquiry-key.md) | The custom-tank enquiry form answers 503 on a missing `INQUIRY_ENCRYPTION_KEY`, or a stored enquiry needs reading |

**These runbooks have been written, not rehearsed.** Five of the six describe a failure that has
been reproduced locally — `rotate-or-create-the-inquiry-key.md`'s 503 was reproduced deliberately,
twice (no key, and a too-short placeholder key), against a real running `order-service` before the
page was written, together with the proof that carts and checkout keep working in the same process;
its *rotation* section has not been rehearsed, and the `curl` at the bottom has been run against a
local instance but not through the cluster ingress — the declined-payment trail in `order-stuck-or-wrong.md` is copied from a
real run; the Argo CD one describes behaviour of a component that is not installed until Phase 4. Say so rather than implying a practised incident history.
