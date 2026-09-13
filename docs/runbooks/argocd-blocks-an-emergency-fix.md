# Argo CD reverted my emergency fix

**Status: not rehearsed.** Argo CD is installed at Phase 4. This runbook is written from the
component's documented behaviour, not from an incident.

**Symptom:** you edited a live resource — scaled a deployment, changed an env var, patched an image
— and within seconds it went back to what it was.

## What happened

That is self-heal working. Argo CD compares the cluster against the desired state in
`aquashop-platform` and reverts anything that drifts. The cluster is not the source of truth; the
repository is ([ADR 0007](../adr/0007-two-repositories.md)).

## The right fix, when there is time

A pull request against `aquashop-platform`. A rollback is `git revert` of the tag-bump commit, which
takes about as long as typing the `kubectl` command you were about to type, and leaves a record.

## When there genuinely is not time

Disable self-heal for the one application, make the change, then put it back:

```bash
# 1. stop the reconciliation for this app only
argocd app set aquashop-dev --sync-policy none

# 2. make the change
kubectl -n aquashop-dev scale deployment/catalog-service --replicas=3

# 3. open the pull request that makes it the desired state, THEN re-enable
argocd app set aquashop-dev --sync-policy automated --self-heal --auto-prune
```

Step 3 is the step that gets skipped, and skipping it is worse than the original incident: the app
stays unmanaged, the next deployment does not happen, and nobody notices until a release is
mysteriously missing. If you cannot open the pull request immediately, set a reminder before you
touch step 1.

Never disable self-heal at the Argo CD project or instance level to fix one deployment. That turns
one unmanaged application into all of them.

## Verify you put it back

```bash
argocd app get aquashop-dev | grep -E 'Sync Policy|Health Status|Sync Status'
```

`Sync Policy: Automated` with `Synced` and `Healthy` is the state to leave behind.
