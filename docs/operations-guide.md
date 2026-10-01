# Operating AquaShop locally, without Claude

How to start, check, update, back up and repair the running platform on this machine, from a
WSL terminal, with nothing but `docker`, `k3d`, `kubectl` and `git`. Installing everything from a
bare Windows machine is a separate document: [installation-manual.md](installation-manual.md).

Every command here was run on this machine on **30 September 2026** against the live `full-app`
cluster, except where a section says otherwise. Where things physically live (ports, containers,
volumes, paths) is drawn in [diagrams/physical.svg](diagrams/physical.svg). Look at that first if
you are not sure what "the node container" means below.

---

## 0. Facts to keep in your head

| Thing | Value on this machine |
|---|---|
| Repository | `~/Config-Scripts/Repo/AquaHUB`, branch `claude/clever-shannon-ivtkw6` (there is no `main`) |
| Shop | <https://aquashop.localtest.me/> (self-signed certificate, so the browser warning is expected) |
| Staff portal | <https://staff.aquashop.localtest.me/> |
| Catalog API | <https://aquashop.localtest.me/api/categories> |
| Cluster | k3d cluster `aquashop`, one node, kubectl context `k3d-aquashop` |
| Docker containers | `k3d-aquashop-server-0` (the whole cluster, host ports 80/443), `k3d-aquashop-serverlb` (Kubernetes API on host port 37127) |
| Namespace | `aquashop-dev` (the app), plus `ingress-nginx`, `cert-manager`, `kube-system` |
| Memory | WSL2 has 11 GiB. `full-app` uses ~2.0 GiB (2053 MiB measured) |
| Database | One Postgres pod, `postgres-0`, with databases `catalog`, `orders`, `inventory`, `payments`, `notify`. It is 95 MB on disk, **inside the node container**, see section 7 |
| Hand-made secret | `order-inquiry-key`. It is not in Git and not re-created by any script |

Services, their source folder, and their Kubernetes names. For each one, the Deployment and
container names are the same:

| Deployment | Source folder | Port | Language | Probes |
|---|---|---|---|---|
| `storefront` | `services/storefront` | 3000 | TypeScript/Fastify | `/healthz`, `/readyz` |
| `catalog-service` | `services/catalog-service` | 8080 | Java/Spring | `/actuator/health/{liveness,readiness}` |
| `order-service` | `services/order-service` | 8082 | Java/Spring | `/actuator/health/{liveness,readiness}` |
| `inventory-service` | `services/inventory-service` | 8081 | Go | `/healthz`, `/readyz` |
| `payment-service` | `services/payment-service` | 8083 | Rust | `/healthz`, `/readyz` |
| `aquatics-advisor` | `services/aquatics-advisor` | 8084 | Python | `/healthz`, `/readyz` |
| `notification-service` | `services/notification-service` | 8085 | Go | `/healthz`, `/readyz` |
| `staff-portal` | `services/staff-portal` | 8080 | JSP/WildFly | `/healthz`, `/readyz` |

---

## 1. Starting it after a reboot

**Normally there is nothing to do.** `/etc/wsl.conf` has `systemd=true` and `docker.service` is
enabled, so Docker starts with WSL. Both k3d containers have `restart: unless-stopped`, so the
cluster starts with Docker. Open an Ubuntu terminal, wait about a minute for the JVMs to boot, and
check:

```bash
cd ~/Config-Scripts/Repo/AquaHUB
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'   # both k3d containers "Up"
kubectl get nodes                                                   # k3d-aquashop-server-0 Ready
kubectl -n aquashop-dev get pods                                    # 9 pods, all 1/1 Running
curl -sk -o /dev/null -w '%{http_code}\n' https://aquashop.localtest.me/healthz   # 200
```

If the cluster was stopped deliberately (`k3d cluster stop`), start it:

```bash
k3d cluster start aquashop
kubectl -n aquashop-dev get pods -w     # Ctrl-C once everything is 1/1 Running
```

### Stopping it to free memory

```bash
k3d cluster stop aquashop     # stops both containers; ALL data is kept
k3d cluster start aquashop    # brings it back exactly as it was
```

From PowerShell, `wsl --shutdown` stops the whole Linux VM. That also keeps everything; the next
terminal you open boots it again. It is also how a `.wslconfig` change takes effect.

---

## 2. A 60-second health check

Run this block whenever something feels off. It goes outside in: Docker, cluster, pods, then
the real URLs.

```bash
docker info >/dev/null && echo "docker: ok"
k3d cluster list
kubectl get nodes
kubectl get pods -A | grep -v -E 'Running|Completed'     # anything printed besides the header is a problem
kubectl -n aquashop-dev get pods -o wide
kubectl top node && kubectl top pods -A --sort-by=memory | head -12
for u in / /healthz /readyz /api/categories; do
  printf '%s  %s\n' "$(curl -sk -o /dev/null -w '%{http_code}' -H 'Accept-Encoding: br' https://aquashop.localtest.me$u)" "$u"
done
curl -sk -o /dev/null -w '%{http_code}  staff portal\n' https://staff.aquashop.localtest.me/
```

On a healthy machine: every pod is `1/1 Running`, every URL is `200`, and the node is using about
2 GiB.

The `-H 'Accept-Encoding: br'` matters. A plain `curl` skips the compressed path, and this
project once had a bug that only showed up there (a blank page in the browser, a full page in
curl). See `CLAUDE.md`.

---

## 3. Updating the application after a `git pull`

```bash
cd ~/Config-Scripts/Repo/AquaHUB
git status                          # commit or stash local edits first
git pull origin claude/clever-shannon-ivtkw6
git log --oneline -5                # see what arrived
git diff --stat HEAD@{1} HEAD       # which folders changed, so you know what to rebuild
```

Then pick **one** of the two routes below.

### 3a. The simple route: re-run the bootstrap (rebuilds everything)

```bash
./scripts/bootstrap.sh --profile full-app --metrics
```

This is safe on the existing cluster. It prints `cluster aquashop exists, reusing it`, upgrades
ingress-nginx and cert-manager in place, rebuilds all eight images, imports them, re-applies the
manifests and waits for each rollout. **It does not touch the database or the enquiry key.** The
full rebuild has not been timed; the Rust (payment) and WildFly (staff-portal) builds are the slow
ones.

It refuses to start unless more than 6000 MB is free (`need >6000 MB free for the full-app
profile`). With the cluster up, about 8.6 GB is free on this machine, so it passes. If it refuses,
see section 5.

### 3b. The fast route: rebuild only what changed

Example for the storefront. For another service, swap in its folder and Deployment name from the
table in section 0:

```bash
SVC=storefront                      # Deployment name
DIR=services/storefront             # its source folder

docker build -t aquashop/$SVC:dev $DIR          # 1. build the image on the host
k3d image import -c aquashop aquashop/$SVC:dev  # 2. copy it into the node's containerd
kubectl -n aquashop-dev rollout restart deployment/$SVC    # 3. new pod, new image
kubectl -n aquashop-dev rollout status  deployment/$SVC --timeout=300s
kubectl -n aquashop-dev get pods -l app=$SVC    # old pod gone, new one 1/1
```

Why this works: every Deployment runs `aquashop/<svc>:dev` with `imagePullPolicy: IfNotPresent`.
Step 2 moves the `:dev` tag inside the node to the new image, and step 3 starts a pod that picks
it up. Skip step 3 and nothing changes, because the old pod keeps running the old image.

**Restart one JVM at a time.** The namespace's quota has 4 GiB of memory limits and 3200 MiB is
already used, leaving 896 MiB free. A rolling restart briefly runs old and new pods side by side.
One JVM (640 MiB limit) fits in that gap; two at once do not. The second one then sits `Pending`
with `exceeded quota` in its events until the first finishes.

**Wait for the old pod to go before you test.** `rollout status` can return while the old pod is
still answering. Requests that land on it get the old version, which looks like "my change did
nothing". Check `kubectl get pods` first. The storefront also caches the product list for
60 seconds.

### 3c. Special cases

| What changed | Extra step |
|---|---|
| A catalogue migration (`services/catalog-service/src/main/resources/db/migration/V*.sql`) | Nothing extra. Flyway runs when `catalog-service` starts. Confirm: `kubectl -n aquashop-dev exec postgres-0 -- psql -U postgres -d catalog -Atc "select version from flyway_schema_history order by installed_rank desc limit 1"` (it printed `29` on 1 Oct). **Never edit a migration that has already been applied.** Add a new `V<n+1>__*.sql` instead. |
| Photos in `services/storefront/public/` | Make a product photo exactly 4:3 first, or the page crops it: `./scripts/reframe-photo.sh in.jpg services/storefront/public/species/<slug>.jpg 0.05 0.95` (the two numbers are where the fish starts and ends, as fractions of the width). Then rebuild **storefront** (the photos and their WebP variants are baked into the image), and catalog-service too if a migration sets the `image_key`. |
| Advisor rules (`services/aquatics-advisor/rules.yaml`) | Bump `version` and `updated` in the file, and the `aquashop.io/rules-version` annotation in `platform-repo/dev/advisor/deployment.yaml`. Then rebuild the advisor. The checker page's footer shows which version is live. |
| A Kubernetes manifest under `platform-repo/dev/<svc>/` | See the trap below. |

**The manifest trap.** Every manifest in Git says `image: aquashop/<svc>:PLACEHOLDER`, because CI
is meant to write the real tag there. Re-applying one by hand therefore switches that pod to an
image that doesn't exist, and it ends up in `ImagePullBackOff`. Always follow an apply with
`set image`:

```bash
kubectl apply -f platform-repo/dev/order/
kubectl -n aquashop-dev set image deployment/order-service order-service=aquashop/order-service:dev

# core services are applied through kustomize:
kubectl apply -k platform-repo/dev
kubectl -n aquashop-dev set image deployment/catalog-service catalog-service=aquashop/catalog-service:dev
kubectl -n aquashop-dev set image deployment/storefront storefront=aquashop/storefront:dev
```

`bootstrap.sh` already does this, which is one more reason to prefer route 3a when in doubt.

### 3d. Check the update actually shipped

```bash
kubectl -n aquashop-dev get pods                       # all 1/1, fresh AGE on what you rebuilt
kubectl -n aquashop-dev logs deploy/<svc> --tail=30    # no stack traces
curl -sk -H 'Accept-Encoding: br' -o /dev/null -w '%{http_code} %{size_download}B\n' https://aquashop.localtest.me/
```

Then look at it in a browser. For a photo, compare file sizes. This returned `191091B` for the
V26 crowntail, the same size as the file in Git:

```bash
curl -sk -o /dev/null -w '%{http_code} %{size_download}B\n' https://aquashop.localtest.me/static/species/betta-male-crowntail.jpg
ls -l services/storefront/public/species/betta-male-crowntail.jpg
```

---

## 4. Troubleshooting: where to look, in order

Work outside in, and stop at the first layer that is wrong. The cause is almost always at that
layer or the one just outside it.

```
1 Docker      docker info
2 Cluster     k3d cluster list ; docker ps
3 Node        kubectl get nodes ; kubectl top node
4 Pods        kubectl -n aquashop-dev get pods
5 Why         kubectl -n aquashop-dev describe pod <pod>      (read "Events" at the bottom)
              kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -30
6 Logs        kubectl -n aquashop-dev logs <pod>              (add --previous after a crash)
7 Edge        kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=50
              kubectl -n aquashop-dev get endpoints
```

### 4.1 By symptom

| Symptom | Likely cause | What to do |
|---|---|---|
| `Cannot connect to the Docker daemon` | Docker not running, or your shell isn't in the `docker` group | `sudo systemctl start docker`; `systemctl status docker`; `groups` should list `docker` (if not: `sudo usermod -aG docker $USER`, then open a new terminal) |
| `The connection to the server 0.0.0.0:37127 was refused` | Cluster is stopped | `k3d cluster list` shows `0/1` servers → `k3d cluster start aquashop` |
| `kubectl` talks to the wrong cluster, or has no context | kubeconfig lost or switched | `kubectl config get-contexts`; `k3d kubeconfig merge aquashop --kubeconfig-switch-context` |
| Browser: "This site can't be reached" | Something else holds port 80/443, or the ingress pod is down | WSL: `sudo ss -ltnp \| grep -E ':(80\|443)\b'`. Windows (PowerShell): `netstat -ano \| findstr ":443"` then `tasklist /FI "PID eq <pid>"`. Cluster: `kubectl -n ingress-nginx get pods` |
| Browser: certificate warning | Expected. The CA is self-signed and created by cert-manager inside the cluster | Proceed. `kubectl get certificate -A` should show `READY True` |
| `502 Bad Gateway` / `503` from nginx | The backend pod is not Ready, so the Service has no endpoints | `kubectl -n aquashop-dev get endpoints storefront catalog-service`; empty → look at that pod |
| Page is blank white in the browser, but `curl` shows HTML | Compressed response with an empty body (see `CLAUDE.md`, the Fastify `return reply` rule) | `curl -sk -H 'Accept-Encoding: br' -o /dev/null -w '%{size_download}\n' https://aquashop.localtest.me/` → `0` confirms it; check the storefront handler you changed |
| Pod `ImagePullBackOff` / `ErrImagePull`, image `...:PLACEHOLDER` | A manifest was applied without `set image` | Section 3c, "the manifest trap" |
| Pod `ImagePullBackOff`, image `...:dev` | The image was never imported into the node | `docker exec k3d-aquashop-server-0 crictl images \| grep aquashop`; if missing, `k3d image import -c aquashop aquashop/<svc>:dev` |
| Pod `CrashLoopBackOff` | The process exits. Migrations run at startup, so a migration failure looks exactly like this | `kubectl -n aquashop-dev logs <pod> --previous`. Look for Flyway / `migrate` / `connection refused` / `password authentication failed` |
| Logs say `database "x" does not exist` / `role "x" does not exist` | The Postgres init script only runs on an empty data directory | [runbooks/add-a-service-database.md](runbooks/add-a-service-database.md) |
| Pod `CreateContainerConfigError` | A Secret/ConfigMap it references is missing, or a securityContext problem | `kubectl -n aquashop-dev describe pod <pod>`; the event names the missing object. (Distroless images need `runAsUser: 65532`, which all manifests already have) |
| Pod `Pending` | Quota full, or not enough memory on the node | `describe pod` → `exceeded quota` or `Insufficient memory`; `kubectl -n aquashop-dev describe resourcequota`. During a rollout, wait. If an old ReplicaSet's pod is stuck (e.g. in `ImagePullBackOff`) and holding quota: `kubectl -n aquashop-dev get rs`, then `kubectl -n aquashop-dev delete rs <old-rs>` |
| `OOMKilled` in `describe pod` (Last State) | The memory limit is too low for what it's doing | [runbooks/pod-oomkilled.md](runbooks/pod-oomkilled.md). Check `kubectl top pods -A` |
| Pod `Running` but `0/1` Ready for minutes | Readiness probe failing, often a dependency (the storefront's readiness needs the catalog) | `describe pod` → `Readiness probe failed`; then check the dependency's pod |
| Tank enquiry form says it isn't taking enquiries (503) | `order-inquiry-key` Secret missing (typical right after a rebuild) | [runbooks/rotate-or-create-the-inquiry-key.md](runbooks/rotate-or-create-the-inquiry-key.md), or restore your saved key (section 7) |
| Order stuck or stock looks wrong | Saga or reservation state | [runbooks/order-stuck-or-wrong.md](runbooks/order-stuck-or-wrong.md), [runbooks/stock-looks-wrong.md](runbooks/stock-looks-wrong.md) |
| New photo shows the old one, or a 404 | Image not rebuilt/imported, the old pod is still answering, or the 60 s cache | Section 3b and 3d; compare sizes with `curl -w '%{size_download}'` |
| `bootstrap.sh`: `need >6000 MB free` | Not enough free memory in WSL | `free -m`; `docker stats --no-stream`; close heavy Windows apps, or `k3d cluster stop aquashop` first. Check `grep MemTotal /proc/meminfo` shows ~11 GB (if ~7.4 GB, `.wslconfig` isn't applied) |
| `docker build` dies, exit code 137, or WSL freezes | Out of memory during a Maven/Cargo build | Build one image at a time; stop the cluster while building; confirm `swap=4GB` in `.wslconfig` |
| `no space left on device` | Docker images and build cache | `docker system df`; `docker builder prune`; `docker image prune`. **Do not run `docker volume prune` or `docker system prune --volumes`**: that deletes the Maven/npm caches, and with the cluster stopped it would delete the database too |
| Everything is broken and you want a clean slate | — | Section 8. **Back up first (section 7).** |

### 4.2 Kubernetes commands worth knowing

```bash
# what is running, and where
kubectl get pods -A -o wide
kubectl -n aquashop-dev get deploy,rs,pods,svc,endpoints,ingress
kubectl -n aquashop-dev get pods -w                       # live updates; Ctrl-C to stop

# why a pod is unhappy
kubectl -n aquashop-dev describe pod <pod>
kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -30
kubectl -n aquashop-dev get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState}'; echo

# logs
kubectl -n aquashop-dev logs deploy/order-service --tail=100
kubectl -n aquashop-dev logs deploy/order-service -f              # follow
kubectl -n aquashop-dev logs <pod> --previous                      # the run before the crash
kubectl -n aquashop-dev logs deploy/catalog-service | grep -i -E 'flyway|error|exception'

# restart, roll back, scale
kubectl -n aquashop-dev rollout restart deployment/<svc>
kubectl -n aquashop-dev rollout status  deployment/<svc>
kubectl -n aquashop-dev rollout history deployment/<svc>
kubectl -n aquashop-dev rollout undo    deployment/<svc>          # back to the previous ReplicaSet
kubectl -n aquashop-dev scale deployment/<svc> --replicas=0       # stop one service
kubectl -n aquashop-dev scale deployment/<svc> --replicas=1

# memory and quota
kubectl top node
kubectl top pods -A --sort-by=memory
kubectl -n aquashop-dev describe resourcequota
kubectl -n aquashop-dev describe limitrange

# talk to a service directly, skipping the ingress
kubectl -n aquashop-dev port-forward svc/catalog-service 18080:8080   # then, in another terminal:
curl -s localhost:18080/actuator/health

# the database
kubectl -n aquashop-dev exec -it postgres-0 -- psql -U postgres          # \l lists databases, \q quits
kubectl -n aquashop-dev exec -it postgres-0 -- psql -U postgres -d catalog -c 'select count(*) from product'

# certificates and ingress
kubectl get certificate,clusterissuer -A
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=50
```

**The service images have no shell.** They are distroless, so `kubectl exec -it <pod> -- sh` fails
on everything except Postgres. To poke at the network from inside the namespace, start a throwaway
curl pod (it pulls `curlimages/curl` from Docker Hub, and is deleted on exit):

```bash
kubectl -n aquashop-dev run curl --rm -it --restart=Never --image=curlimages/curl -- sh
# inside it:
curl -s http://order-service:8082/actuator/health/readiness
curl -s http://inventory-service:8081/readyz
```

### 4.3 Docker commands worth knowing

The cluster is ordinary Docker containers, so Docker can look at it from outside even when
`kubectl` can't.

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker stats --no-stream                                    # memory of the node container = whole cluster
docker logs --tail 100 k3d-aquashop-server-0                # k3s itself: API server, kubelet, containerd
docker restart k3d-aquashop-server-0                        # a hard restart of the whole cluster (keeps data)
docker inspect k3d-aquashop-server-0 --format '{{range .Mounts}}{{.Destination}} <- {{.Name}}{{"\n"}}{{end}}'

# inside the node: the containers Kubernetes is actually running
docker exec k3d-aquashop-server-0 crictl ps
docker exec k3d-aquashop-server-0 crictl images | grep aquashop
docker exec k3d-aquashop-server-0 crictl logs <container-id>
docker exec k3d-aquashop-server-0 du -sh /var/lib/rancher/k3s/storage/*   # Postgres on disk

# images and disk
docker images | grep aquashop
docker system df
docker builder prune                                         # safe: build cache only

# run one service image on its own, outside Kubernetes (e.g. to see why it won't start)
docker run --rm -p 8084:8084 aquashop/aquatics-advisor:dev   # advisor needs CATALOG_BASE_URL to answer
```

---

## 5. Memory

The cluster's own usage is small (~2 GiB). Memory problems on this machine come from **builds**
and from Windows.

```bash
free -m
grep -E 'MemTotal|MemAvailable|SwapTotal' /proc/meminfo
kubectl top node
docker stats --no-stream
```

- WSL2's limit comes from `C:\Users\sayan\.wslconfig` (`memory=11GB`, `processors=4`, `swap=4GB`).
  After editing it, run `wsl --shutdown` in PowerShell and open a new terminal. If `MemTotal`
  reads about 7.4 GB, the file isn't being applied.
- Never build images while the (future) observability profile is up. That rule is enforced in
  `bootstrap.sh`.
- To give a heavy build the most room: `k3d cluster stop aquashop`, run the `docker build`, then
  `k3d cluster start aquashop` (the import needs a running cluster), then `k3d image import` and
  `rollout restart` as in section 3b.

---

## 6. Running the tests

The commands are in `CLAUDE.md` → Testing. There is no local Maven, JDK or cargo, so the Java
suites run in the `maven:3.9-eclipse-temurin-21` container. `CLAUDE.md` has the exact
`docker run` line, including the `api.version=1.44` workaround for Testcontainers on Docker 29.

---

## 7. Backups: do this before anything destructive

**Where the data lives.** Postgres writes to a local-path PersistentVolume at
`/var/lib/rancher/k3s/storage/pvc-…_aquashop-dev_data-postgres-0`. That path is inside the node
container, on an anonymous Docker volume mounted at `/var/lib/rancher/k3s`. The same volume holds
the k3s datastore, and with it every Secret, including `order-inquiry-key`.

**What loses it.** `k3d cluster delete aquashop`, which is also what `./scripts/bootstrap.sh
--destroy` runs. It removes the node container **and** its anonymous volumes. This was checked on
30 Sep 2026 by creating a throwaway cluster, writing a file into that volume, deleting the
cluster, and watching the volume disappear. `k3d cluster stop`, `docker restart`, `wsl --shutdown`
and a Windows reboot all keep it.

### Back up (tested 30 Sep 2026: 376 KB dump, all five service databases)

```bash
mkdir -p ~/aquashop-backups
kubectl -n aquashop-dev exec postgres-0 -- pg_dumpall -U postgres --clean --if-exists \
  > ~/aquashop-backups/aquashop-$(date +%F).sql

# the enquiry encryption key: without it, every stored enquiry is unreadable forever
kubectl -n aquashop-dev get secret order-inquiry-key \
  -o jsonpath='{.data.INQUIRY_ENCRYPTION_KEY}' | base64 -d > ~/aquashop-backups/inquiry-key
chmod 600 ~/aquashop-backups/inquiry-key
wc -c ~/aquashop-backups/inquiry-key      # 64 on this machine
```

Keep both outside the repository. The key must never be committed.

### Restore into a freshly bootstrapped cluster (not yet rehearsed on this machine)

Written from how `pg_dumpall --clean` and `psql` behave. It has not been run end to end here, so
check each step's output as you go.

```bash
# 1. the key first, so order-service can start with enquiries enabled
kubectl create secret generic order-inquiry-key --namespace aquashop-dev \
  --from-file=INQUIRY_ENCRYPTION_KEY=$HOME/aquashop-backups/inquiry-key

# 2. stop everything that holds database connections
kubectl -n aquashop-dev scale deployment --all --replicas=0

# 3. load the dump. --clean drops and recreates each database. Expect one harmless error:
#    "current user cannot be dropped" for the postgres role
kubectl -n aquashop-dev exec -i postgres-0 -- psql -U postgres -d postgres \
  < ~/aquashop-backups/aquashop-YYYY-MM-DD.sql

# 4. bring the services back. Flyway sees the restored history and applies only newer migrations
kubectl -n aquashop-dev scale deployment --all --replicas=1
kubectl -n aquashop-dev get pods -w
```

---

## 8. Full reset (last resort)

Only after section 7:

```bash
./scripts/bootstrap.sh --destroy                         # deletes the cluster AND the database
./scripts/bootstrap.sh --profile full-app --metrics      # builds everything from scratch
# then either restore (section 7) or create a new enquiry key:
kubectl create secret generic order-inquiry-key --namespace aquashop-dev \
  --from-literal=INQUIRY_ENCRYPTION_KEY="$(openssl rand -base64 48)"
kubectl -n aquashop-dev rollout restart deployment/order-service
```

`bootstrap.sh` warns if the key is missing, but carries on. The shop then looks healthy while the
enquiry form answers 503, so don't skip the last two lines.

---

## 9. Regenerating the documentation

```bash
./scripts/render-docs.sh      # docs/diagrams/*.svg from generate.py, then docs/architecture.pdf
```

It runs `python3 docs/diagrams/generate.py`, then renders `docs/architecture-pdf.html` to
`docs/architecture.pdf` using Chromium in the local `mcr.microsoft.com/playwright:v1.48.0-jammy`
image, because this machine has no native browser. Commit the SVGs and the PDF together with
whatever they describe.

---

## 10. Saving your work

```bash
git status
git add -A && git commit -m "What changed and why"
git push origin claude/clever-shannon-ivtkw6
```

Pull before you start and push before you stop. A Claude session on the web and your local
checkout can't see each other's uncommitted work.
