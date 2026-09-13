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

**These runbooks have been written, not rehearsed.** Four of the five describe a failure that has
been reproduced locally — the declined-payment trail in `order-stuck-or-wrong.md` is copied from a
real run; the Argo CD one describes behaviour of a component that is not installed until Phase 4. Say so rather than implying a practised incident history.
