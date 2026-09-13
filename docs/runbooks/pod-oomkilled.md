# A pod is OOMKilled

**Symptom:** a pod restarts repeatedly. `kubectl describe pod` shows `Last State: Terminated,
Reason: OOMKilled`, or an exit code of **137** (128 + SIGKILL).

137 is the kernel, not the application. The process did not choose to exit; it was killed for
exceeding its cgroup memory limit.

## Which limit was hit

```bash
kubectl -n aquashop-dev describe pod <pod> | grep -A3 'Limits\|Last State'
kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -20
```

Two different failures look identical here:

1. **The container exceeded its own limit.** The pod is killed, nothing else is affected.
2. **The node ran out of memory.** The kernel OOM killer picks a victim by score, which may be an
   unrelated pod. A pod that was killed and had plenty of headroom is a symptom of the node, not of
   itself — check `kubectl top nodes` and whether an image build was running.

The second is the reason `bootstrap.sh` refuses to build images while the observability profile is
up. ~1.8 GB of headroom does not survive a Maven or Cargo build.

## If it is a JVM service

The first thing to check is whether the JVM sized its heap from the cgroup or from the host:

```bash
kubectl -n aquashop-dev exec deploy/catalog-service -- env | grep JAVA_TOOL_OPTIONS
```

It must contain `-XX:MaxRAMPercentage=70`. Without it the JVM reads the *host's* memory, sizes a
heap far above the container limit, and is OOM-killed the moment it fills — a container limit is
not a signal the JVM sees unless it is told to look.

Note that the heap is not the whole picture: metaspace, code cache, thread stacks and direct
buffers live outside it. 70% of the limit, not 100%, is what leaves room for them.

## If it is `inventory-service`

Measured at 13.9 MiB idle and 17.0 MiB after 200 reservations, against a 96Mi limit. An OOMKill
here is not a tuning problem — it is a leak or an unbounded response, and the change that
introduced it is the thing to look at. Request bodies are capped at 8 KiB and reservation quantity
at 500 precisely so that a single request cannot be the cause.

## Do not simply raise the limit

The namespace `ResourceQuota` (3Gi of requests, 4Gi of limits) is the ceiling for the environment.
Raising one pod's limit takes the headroom from its neighbours, and the next OOMKill lands
somewhere less obvious. Establish what the memory is *for* first.

```bash
kubectl -n aquashop-dev describe resourcequota aquashop-dev-quota
```
