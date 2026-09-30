# AquaShop — Running, updating and troubleshooting it yourself

*Current to 30 September 2026 (`V26`). For a WSL2 terminal on your own machine, with no Claude
session. Installing from scratch is [installation-manual.md](installation-manual.md). This page
assumes `bootstrap.sh` has already run once and `~/AquaHUB` is your clone.*

**How far this was checked.** The commands come from `scripts/bootstrap.sh`, the manifests in
`platform-repo/dev/`, the runbooks, and fixes recorded in `RELEASE-NOTES.md` and
`agent_learningz.md`. The failure table lists failures this project **actually had**, each with its
real fix. `scripts/redeploy.sh` is new (30 Sep 2026). Its logic was run against stub
`docker`/`k3d`/`kubectl` commands, but not yet against a real cluster, because the session that
wrote it had no Docker daemon. Run `./scripts/redeploy.sh storefront` first and check it before you
rely on it for a bigger change.

Everything below uses the namespace `aquashop-dev`. Save typing with:

```bash
alias k='kubectl -n aquashop-dev'
```

---

## Part 1 — Everyday use

### Starting it after a reboot or `wsl --shutdown`

```bash
cd ~/AquaHUB
sudo service docker start            # only if WSL has no systemd (see the installation manual)
docker info --format '{{.ServerVersion}}'
k3d cluster list                     # "aquashop  1/1" = running, "0/1" = stopped
k3d cluster start aquashop           # if stopped
kubectl config use-context k3d-aquashop
kubectl -n aquashop-dev get pods     # wait until everything is Running and 1/1
```

The k3d node container normally restarts with Docker by itself. The JVM services take 1–2
minutes to become ready after a start, and staff-portal (WildFly) takes longest.

### Stopping it to get the memory back

```bash
k3d cluster stop aquashop            # keeps all data; start it again later
```

### Where things are

| What | Where |
|---|---|
| Shop | <https://aquashop.localtest.me/> |
| Tank checker | <https://aquashop.localtest.me/compatibility> |
| Catalogue API (demo only) | <https://aquashop.localtest.me/api/categories> |
| Staff portal | <https://staff.aquashop.localtest.me/> |
| Service ports inside the cluster | storefront 3000, catalog 8080, inventory 8081, order 8082, payment 8083, advisor 8084, notification 8085, staff-portal 8080, postgres 5432 |

---

## Part 2 — Updating the application, step by step

The cycle is always the same: **get the change → see what it touches → rebuild only those services →
roll them out → verify → roll back if it is wrong.**

### Step 1. Get the change

If someone (or a Claude web session) pushed work:

```bash
cd ~/AquaHUB
git status                           # must be clean; commit or stash your own edits first
git log -1 --oneline                 # note this commit: it is what is running now
OLD=$(git rev-parse HEAD)
git pull origin claude/clever-shannon-ivtkw6
```

If you are making the change yourself, edit the files and go straight to step 2. Commit when it
works (step 7).

### Step 2. See which services the change touches

```bash
git diff --stat "$OLD" HEAD -- services platform-repo scripts
git diff --name-only "$OLD" HEAD -- services | cut -d/ -f2 | sort -u    # the services to rebuild
```

Use this table to decide what to do:

| Changed path | What to do |
|---|---|
| `services/<name>/…` (code, `Dockerfile`, `public/` photos) | rebuild and roll out `<name>` (step 3) |
| `services/catalog-service/src/main/resources/db/migration/V*.sql` | rebuild `catalog-service`. Flyway applies the new migration when the new pod starts. Also rebuild `storefront` if the same change added photos under `services/storefront/public/` |
| `services/aquatics-advisor/rules/rules.yaml` | rebuild `aquatics-advisor`. The rules are baked into the image; it is not a ConfigMap |
| `platform-repo/dev/<name>/deployment.yaml` | apply the manifest, **then** roll out that service's image again (step 4) |
| `platform-repo/dev/postgres/init-configmap.yaml` | does nothing to an existing database; see [runbooks/add-a-service-database.md](runbooks/add-a-service-database.md) |
| `scripts/bootstrap.sh`, `scripts/k3d-cluster.yaml` | read the diff; a cluster-level change may need `--destroy` and a fresh bootstrap (Part 6) |
| docs only | nothing to deploy |

### Step 3. Rebuild and roll out: the one-command way

```bash
./scripts/redeploy.sh catalog-service storefront     # the services from step 2
./scripts/redeploy.sh --list                         # what every Deployment is running now
```

For each service it runs `docker build`, then `k3d image import` (there is no registry), then
`kubectl set image`, then `kubectl rollout status`. It builds **all** of them before touching the
cluster, so a compile error leaves the running shop as it was. Each build gets a tag made from the
git commit, for example `aquashop/storefront:git-5782809`. An uncommitted change gets
`…-dirty-<timestamp>` instead. That is what makes `--list` show which build is live, and what makes
rollback possible (step 6).

### Step 3, by hand (what the script does, if you want to see each step)

```bash
S=storefront                                   # the deployment, container and services/ folder all share this name
TAG=git-$(git rev-parse --short HEAD)
docker build -t aquashop/$S:$TAG services/$S
k3d image import -c aquashop aquashop/$S:$TAG
kubectl -n aquashop-dev set image deployment/$S $S=aquashop/$S:$TAG
kubectl -n aquashop-dev rollout status deployment/$S --timeout=300s
```

> **Trap: rebuilding under the same tag does nothing.** `bootstrap.sh` uses `:dev`. If you rebuild
> `aquashop/storefront:dev`, import it, and run `set image …:dev`, the Deployment's spec has not
> changed. Kubernetes starts no rollout, so **the old code keeps running** and nothing reports an
> error. With a fixed tag you must also run
> `kubectl -n aquashop-dev rollout restart deployment/storefront`. A new tag per build avoids this.

### Step 4. If a manifest changed

```bash
kubectl apply -f platform-repo/dev/order/            # the folder that changed
./scripts/redeploy.sh order-service                  # REQUIRED afterwards, see below
```

> **Trap: applying a manifest resets its image to `:PLACEHOLDER`.** Every `deployment.yaml` says
> `image: aquashop/<name>:PLACEHOLDER`, and `kubectl apply -k platform-repo/dev` sets
> `newTag: PLACEHOLDER` for catalog and storefront. The placeholder is there for CI to rewrite. No
> such image exists, so new pods go to `ErrImagePull`/`ImagePullBackOff`. `maxUnavailable: 0` keeps
> the old pod serving meanwhile, so the shop looks fine and the change is not live. Always follow
> an apply with `redeploy.sh` (or `kubectl set image`) for the same services.
>
> `staff-portal` is the exception. Its strategy is `maxUnavailable: 1, maxSurge: 0`, so it stops
> the old pod first and the staff portal **is down** until a real image is set.

The same applies to `order-service`'s notification settings. `bootstrap.sh --profile full-app`
adds `NOTIFICATION_CLIENT=http` and `NOTIFICATION_BASE_URL` with `kubectl set env`; they are not
in the manifest. A normal `kubectl apply` keeps them. If you ever `kubectl replace` or delete and
recreate the Deployment, set them again:

```bash
kubectl -n aquashop-dev set env deployment/order-service \
  NOTIFICATION_CLIENT=http NOTIFICATION_BASE_URL=http://notification-service:8085
```

### Step 5. Verify, from the outside in

```bash
kubectl -n aquashop-dev get pods                     # wait until the OLD pods are gone, not just the new ones Ready
curl -ks -o /dev/null -w '%{http_code}\n' https://aquashop.localtest.me/                         # 200
curl -ks -H 'Accept-Encoding: br' -o /dev/null -w '%{size_download}\n' https://aquashop.localtest.me/   # > 0
kubectl -n aquashop-dev logs deploy/catalog-service | grep -i "schema"   # after a migration: names the new version
```

Then look at the changed pages **in a browser**. Three lessons this project paid for:

- `rollout status` returning does not mean the old pod has stopped answering. Check the
  pod list first.
- The storefront caches the catalogue for 60 seconds. After a catalogue change, wait a minute or
  poll (`until curl -ks URL | grep -q "new text"; do sleep 5; done`).
- Photos are cached for a day (`max-age=86400`). A photo replaced under the same file name needs a
  hard refresh (Ctrl+F5) or a private window.

### Step 6. Roll back if it is wrong

```bash
kubectl -n aquashop-dev rollout undo deployment/storefront      # back to the previous build
kubectl -n aquashop-dev rollout history deployment/storefront
```

This works for code, photos and rules. **It does not undo a database migration.** The rolled-back
catalog-service runs against the newer database. Flyway's default is to ignore migrations it does
not know about. Hibernate's `ddl-auto: validate` then decides whether the old code accepts the
schema. That is fine for data-only migrations like `V26`. After a migration that drops or renames a
column the old build may fail to start, and **this has not been tested here**. To reverse a
migration, write a new `V27__…` that corrects it, the way V19 corrected V17.

### Step 7. Keep your own changes

```bash
git add -A && git commit -m "What changed and why"
git push origin claude/clever-shannon-ivtkw6
```

Pull before you start and push when you stop. A Claude web session and your local work cannot see
each other's uncommitted changes, so work in one place at a time.

Two rules to follow when you make changes yourself:

- **Never edit a migration that has run** (`V1`–`V26` all have). Flyway checksums them, and
  catalog-service will crash-loop with a *checksum mismatch*. Add a new, higher-numbered file.
- **A new photo file and its `image_key` ship together.** Put the file in
  `services/storefront/public/species/<slug>.jpg`, add a migration that sets the key, record the
  licence in `species/CREDITS.md`, and rebuild **both** storefront and catalog-service.
  `CatalogApiTest` pins the exact list of products without a photo, so update it in the same change.

---

## Part 3 — When it will not come up: a method

Work **from the bottom layer up**. Each layer below depends on the one under it. The first layer
that fails is your problem; everything above it is only a symptom.

```
 7  Browser        page blank / wrong / cert error
 6  Ingress        https://aquashop.localtest.me answers?
 5  Service        pod Ready? logs clean?
 4  Pod            Running? Pending? CrashLoopBackOff? ImagePullBackOff?
 3  Kubernetes     kubectl reaches the API? node Ready?
 2  k3d / Docker   docker running? k3d node container up?
 1  WSL2           memory, disk, time
```

Run these in order and stop at the first one that looks wrong:

```bash
# 1  WSL2
free -m                                         # "available" under ~1500 MB means trouble
df -h ~ /var/lib/docker                         # a full disk breaks builds and Postgres

# 2  Docker and k3d
docker info --format '{{.ServerVersion}}' || sudo service docker start
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'   # k3d-aquashop-server-0 must be Up, with 80 and 443
k3d cluster list

# 3  Kubernetes
kubectl config current-context                  # k3d-aquashop
kubectl get nodes                               # Ready
kubectl get pods -A | grep -v Running           # anything not Running, in any namespace

# 4  Pods in the shop
kubectl -n aquashop-dev get pods -o wide
kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -30

# 5  The failing service
kubectl -n aquashop-dev describe pod <pod>      # read "State", "Last State", "Events" at the bottom
kubectl -n aquashop-dev logs <pod>              # current container
kubectl -n aquashop-dev logs <pod> --previous   # the one that crashed; usually the useful one

# 6  Ingress
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=50
curl -kv https://aquashop.localtest.me/healthz 2>&1 | tail -5

# 7  Browser: compare with curl using the browser's headers
curl -ks -H 'Accept-Encoding: br' -o /dev/null -w '%{http_code} %{size_download}\n' https://aquashop.localtest.me/
```

### Reading a pod's status

| STATUS | Means | First thing to run |
|---|---|---|
| `Pending` | not scheduled: quota, memory, or a volume | `describe pod`; look at Events for `FailedScheduling` or `exceeded quota` |
| `ContainerCreating` for minutes | the volume or secret is not ready, or the image is still unpacking | `describe pod` |
| `ErrImagePull` / `ImagePullBackOff` | the image is not in the k3d node | `kubectl get deploy <name> -o jsonpath='{..image}'`: is it `:PLACEHOLDER`, or a tag you never imported? |
| `CreateContainerConfigError` | a Secret/ConfigMap it needs is missing, or the securityContext cannot be checked | `describe pod`: the message names it |
| `CrashLoopBackOff` | it starts and dies | `logs --previous` |
| `OOMKilled` (Last State) or exit code 137 | over its memory limit | [runbooks/pod-oomkilled.md](runbooks/pod-oomkilled.md) |
| `Running` but `0/1` | readiness probe failing | `describe pod` (probe messages) and `logs` |

---

## Part 4 — Failures this project has actually had, and their fixes

| Symptom | Cause | Fix |
|---|---|---|
| `docker: Cannot connect to the Docker daemon` | WSL has no systemd, so Docker did not start | `sudo service docker start`, or enable systemd (installation manual §1) |
| bootstrap: `need >6000 MB free for the full-app profile` | WSL memory. It measured ~7.4 GB before `.wslconfig` was applied | Close apps; check `.wslconfig` says `memory=11GB`; `wsl --shutdown` |
| Browser: connection refused on `aquashop.localtest.me` | ports 80/443 taken by something else (IIS, Skype, another cluster), or the k3d node is stopped | `sudo ss -ltnp \| grep -E ':(80\|443)\b'` in WSL; `netstat -ano \| findstr :443` in PowerShell; `k3d cluster start aquashop` |
| `localtest.me` does not resolve | offline, or a DNS server that blocks names resolving to 127.0.0.1 | `getent hosts aquashop.localtest.me`; if empty, add `127.0.0.1 aquashop.localtest.me staff.aquashop.localtest.me` to `C:\Windows\System32\drivers\etc\hosts` and `/etc/hosts` |
| Browser: "Your connection is not private" | expected: the CA is self-signed and in-cluster | Proceed. If it is a hard error, check `kubectl get certificate -A` shows `True` |
| Every pod `CreateContainerConfigError`: *container has runAsNonRoot and image has non-numeric user* | distroless `USER nonroot` is a name kubelet cannot check | Every Deployment must keep `runAsUser: 65532`. Do not remove it |
| order-service `CreateContainerConfigError` naming `order-inquiry-key` | someone removed `optional: true` from the key's `secretKeyRef` | Put `optional: true` back; see ADR 0021 |
| Enquiry form says it is not taking enquiries (503) | the `order-inquiry-key` Secret is missing, e.g. after `--destroy` | [runbooks/rotate-or-create-the-inquiry-key.md](runbooks/rotate-or-create-the-inquiry-key.md), then `rollout restart deployment/order-service` |
| New pods `ImagePullBackOff` on `:PLACEHOLDER` | a manifest was applied without setting the image afterwards | `./scripts/redeploy.sh <service>` (Part 2, step 4) |
| `ErrImageNeverPull` / `ImagePullBackOff` on a real tag | built but never imported into k3d | `k3d image import -c aquashop aquashop/<name>:<tag>` |
| Change deployed, old behaviour still showing | same tag re-imported, so no rollout happened | `kubectl -n aquashop-dev rollout restart deployment/<name>`, or use `redeploy.sh` |
| catalog-service `CrashLoopBackOff`, log says `Validate failed: Migration checksum mismatch` | an already-applied migration file was edited | Revert the edit (`git checkout -- <file>`) and add a new migration instead. On a throwaway dev DB only: `--destroy` and bootstrap again |
| catalog-service crash, `Schema-validation: missing column` | entity and schema disagree; `ddl-auto: validate` caught it | a migration is missing or the entity is wrong: fix the code, never switch to `update` |
| A new service crash-loops: `database "…" does not exist` | the Postgres init script only runs on an **empty** volume | [runbooks/add-a-service-database.md](runbooks/add-a-service-database.md) |
| staff-portal stuck: one pod `ImagePullBackOff`, the real one `Pending` with `exceeded quota` | the rollout deadlock of 17 Sep 2026: a stuck pod held the quota the new pod needed | Fixed in the manifest (`maxUnavailable: 1, maxSurge: 0`). If it recurs: `kubectl -n aquashop-dev get rs -l app=staff-portal`, then delete the ReplicaSet that has the bad image |
| Any pod `Pending`, event `exceeded quota: aquashop-dev-quota` | requests over the namespace's 3 GiB / 4 GiB limits | `kubectl -n aquashop-dev describe quota`; look for leftover pods from old ReplicaSets |
| Pod restarting, `OOMKilled` | its memory limit is too small for the load | [runbooks/pod-oomkilled.md](runbooks/pod-oomkilled.md) |
| Build fails in `inventory-service`: `go.mod requires go >= 1.25` | Dockerfile toolchain older than `go.mod` | Dockerfile must stay on `golang:1.25-bookworm` or newer |
| Build fails in `payment-service`: `feature edition2024 is required` | a locked dependency needs a newer Cargo | Dockerfile must stay on `rust:1.90-bookworm` or newer |
| Build killed, `exit code 137` or `signal: killed` | out of memory while building | build one service at a time; raise `swap` in `.wslconfig`; stop the cluster during big builds (`k3d cluster stop aquashop`) |
| Build fails: `no space left on device` | Docker images and build cache | Part 5, "Disk" |
| Shop page blank white in the browser, fine in `curl` | a Fastify handler without `return reply.send(…)` sends a zero-byte Brotli body | `curl -H 'Accept-Encoding: br'` shows `size_download` 0; add the `return` |
| Home page 502/503 from nginx | storefront not Ready, or catalog-service down (storefront's readiness checks catalog) | `kubectl -n aquashop-dev get pods`; `logs deploy/catalog-service` |
| Tank checker shows an error, rest of the shop fine | aquatics-advisor down. The checker has a 4 s timeout and is not in readiness, so only it fails | `logs deploy/aquatics-advisor` |
| A photo shows the placeholder | its `image_key` is NULL on purpose (27 products at `V26`, listed in `species/CREDITS.md`), or the file is missing from the image | `curl -ksI https://aquashop.localtest.me/species/<slug>.jpg`: 404 means the file is missing |
| Old photo after replacing it | browser cache (`max-age=86400`), or you checked before the old pod stopped | Ctrl+F5; wait until the old pods are gone |

---

## Part 5 — Command reference

### kubectl

```bash
# Look
kubectl -n aquashop-dev get pods -o wide
kubectl -n aquashop-dev get deploy,sts,svc,ingress
kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -30
kubectl -n aquashop-dev describe pod <pod>
kubectl -n aquashop-dev get deploy -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
kubectl -n aquashop-dev describe quota
kubectl top pods -n aquashop-dev                # needs bootstrap --metrics
kubectl top nodes

# Logs
kubectl -n aquashop-dev logs deploy/order-service --tail=100
kubectl -n aquashop-dev logs deploy/order-service -f            # follow
kubectl -n aquashop-dev logs <pod> --previous                   # the crashed container
kubectl -n aquashop-dev logs -l app=storefront --tail=50        # every pod of a service

# Restart, scale, roll back
kubectl -n aquashop-dev rollout restart deployment/<name>
kubectl -n aquashop-dev rollout status  deployment/<name>
kubectl -n aquashop-dev rollout undo    deployment/<name>
kubectl -n aquashop-dev scale deployment/staff-portal --replicas=0   # free ~400 MiB; set back to 1 later
kubectl -n aquashop-dev delete pod <pod>        # its Deployment creates a new one

# Reach a service directly, bypassing the ingress (then use http://localhost:<port>)
kubectl -n aquashop-dev port-forward svc/catalog-service 8080:8080
kubectl -n aquashop-dev port-forward svc/aquatics-advisor 8084:8084     # e.g. curl localhost:8084/v1/rules
kubectl -n aquashop-dev port-forward svc/order-service 8082:8082

# Call one service from inside the cluster. aquatics-advisor is the one image with an
# interpreter in it (python:3.11-slim); every other service image is distroless.
kubectl -n aquashop-dev exec deploy/aquatics-advisor -- python -c \
  "import urllib.request as u; print(u.urlopen('http://catalog-service:8080/actuator/health').read().decode())"
```

### Postgres

```bash
kubectl -n aquashop-dev exec -it postgres-0 -- psql -U postgres                 # superuser
kubectl -n aquashop-dev exec -it postgres-0 -- psql -U postgres -d catalog
```

Useful queries inside `psql`:

```sql
\l                                                         -- catalog, inventory, orders, payments, notify
SELECT version, description, success FROM flyway_schema_history
 ORDER BY installed_rank DESC LIMIT 5;                     -- in catalog: top row is 26
SELECT count(*) FROM product;                              -- the catalogue
SELECT slug FROM product WHERE image_key IS NULL;          -- products on the placeholder
```

Back up before anything risky:

```bash
kubectl -n aquashop-dev exec postgres-0 -- pg_dumpall -U postgres > ~/aquashop-$(date +%F).sql
```

### Docker

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'   # the k3d node is k3d-aquashop-server-0
docker stats --no-stream                                         # memory of the whole k3d node
docker logs k3d-aquashop-server-0 --tail=100                     # k3s itself (for node-level problems)
docker images 'aquashop/*'                                       # your builds and their tags
docker system df                                                 # disk used by images, cache, volumes

# Build one service with the full log, e.g. when a build step fails
docker build --progress=plain -t aquashop/payment-service:debug services/payment-service
docker build --no-cache --progress=plain -t aquashop/storefront:debug services/storefront   # ignore the cache

# Inspect an image without running it
docker image inspect aquashop/storefront:<tag> --format '{{.Config.User}} {{.Config.ExposedPorts}}'
docker history aquashop/storefront:<tag>

# Is a file (e.g. a new photo) really inside the image?
docker create --name peek aquashop/storefront:<tag> >/dev/null
docker cp peek:/app/public/species/betta-male-crowntail.jpg /tmp/ && ls -l /tmp/betta-male-crowntail.jpg
docker rm peek
```

Six of the eight service images are distroless: they have **no shell**, so `docker exec … sh` and
`kubectl exec … sh` fail on them, and that is expected. The exceptions are aquatics-advisor (Python
slim) and staff-portal (WildFly). Use `docker cp` as above, the advisor pod's Python (Part 5,
kubectl), or `port-forward`. The `/app/public` path above is the storefront's layout;
check the service's `Dockerfile` for the path in another image.

### Inside the k3d node: what Kubernetes actually has

`k3d image import` puts images into the node's containerd, not into Docker. To see them:

```bash
docker exec k3d-aquashop-server-0 crictl images | grep aquashop    # is my tag imported?
docker exec k3d-aquashop-server-0 crictl ps                         # running containers
docker exec k3d-aquashop-server-0 crictl rmi --prune                # delete images nothing uses (frees node disk)
```

### Memory

```bash
free -m                                     # WSL total and available
kubectl top pods -n aquashop-dev --sort-by=memory
docker stats --no-stream k3d-aquashop-server-0
```

Measured at rest (28 Sep 2026): staff-portal ~383 MiB, catalog ~272 MiB, order ~220 MiB,
postgres ~61 MiB, advisor ~43 MiB, storefront ~33 MiB, the Go and Rust services under 5 MiB each.
If you are short, `scale deployment/staff-portal --replicas=0` frees the most.

### Disk

```bash
docker system df
docker image prune -a --filter "until=168h"      # images older than a week that nothing uses
docker builder prune --keep-storage 5GB          # build cache, keeping 5 GB so rebuilds stay fast
docker exec k3d-aquashop-server-0 crictl rmi --prune
```

Every `redeploy.sh` build adds a tagged image, so prune now and then.

---

## Part 6 — Starting over

When the cluster is too tangled to be worth fixing. **This deletes every order, enquiry and stock
record in the dev database.**

```bash
kubectl -n aquashop-dev exec postgres-0 -- pg_dumpall -U postgres > ~/aquashop-before-reset.sql   # optional backup
./scripts/bootstrap.sh --destroy
./scripts/bootstrap.sh --metrics                                  # core first
kubectl create secret generic order-inquiry-key --namespace aquashop-dev \
  --from-literal=INQUIRY_ENCRYPTION_KEY="$(cat ~/aquashop-inquiry-key.txt)"   # your saved key
./scripts/bootstrap.sh --profile full-app --metrics
```

Catalogue data is **not** lost in practice: every product, profile and photo key is in the
migrations, and Flyway replays `V1`–`V26` on the empty database.

---

## Part 7 — Asking for help

If you bring a problem back to a Claude session or to anyone else, collect this first. It turns
guessing into reading:

```bash
{
  git -C ~/AquaHUB log -1 --oneline
  free -m; df -h ~
  kubectl -n aquashop-dev get pods -o wide
  kubectl -n aquashop-dev get deploy -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
  kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -40
  for p in $(kubectl -n aquashop-dev get pods --no-headers | awk '$3!="Running"{print $1}'); do
    echo "=== $p"; kubectl -n aquashop-dev describe pod "$p" | tail -25
    kubectl -n aquashop-dev logs "$p" --previous --tail=60 2>/dev/null || kubectl -n aquashop-dev logs "$p" --tail=60
  done
} > ~/aquashop-debug.txt 2>&1
```

Include the full `bootstrap.sh` or `redeploy.sh` output too, with its `==>` lines, so the failing
step can be seen.
