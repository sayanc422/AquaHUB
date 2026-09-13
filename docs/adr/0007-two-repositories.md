# 7. Two repositories: application code and desired state

**Status:** Accepted · **Phase:** 4

## Context

CI builds an image and the cluster must end up running it. Either CI writes the new tag into the
repository it was triggered by, or it writes into a second repository.

## Decision

`aquashop` holds application code. `aquashop-platform` holds cluster desired state. CI opens a pull
request against the platform repository to bump an image tag; Argo CD syncs from it.

A CI bot committing the tag bump into the application repository would retrigger CI on its own
commit. Separating them also makes the GitOps commit log a literal deployment history, and makes a
rollback `git revert` of the tag-bump commit rather than a command typed against a cluster.

## Consequences

Nobody runs `kubectl apply`. "What is running in uat" is answered by reading a file.

**Cost:** a change spanning both repositories is two pull requests, and the GitOps self-heal that
makes this safe also reverts an emergency `kubectl edit` within seconds. That is the point, and it
is also how an incident locks you out of a manual fix — which is why the runbooks name the
sync-window disable procedure before they need it.
