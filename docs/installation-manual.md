# AquaShop — Installation manual

*Current to 30 September 2026 (catalogue migration `V26`). From a Windows 11 laptop with nothing
installed to all eight services running in k3d, with a URL for each step's result.*

**How this was checked.** Every command here is taken from `scripts/bootstrap.sh`,
`scripts/k3d-cluster.yaml`, the manifests in `platform-repo/dev/`, or runs recorded in
`RELEASE-NOTES.md` (16–30 September 2026). This manual was written in a cloud session that had no
Docker daemon, so **it has not been followed end to end from a blank machine in one go**. The
profiles themselves have run many times. If a step here disagrees with `bootstrap.sh`, the script
is right; fix this page.

For keeping it running and updating it afterwards, read
[operations-guide.md](operations-guide.md). For the design, read [architecture.md](architecture.md)
or [architecture.pdf](architecture.pdf).

---

## 0. What you are installing

| Layer | What | Why this and not the obvious alternative |
|---|---|---|
| Windows 11 | the host, 16 GB RAM | — |
| WSL2, Ubuntu 22.04/24.04 | the Linux VM everything runs in | one VM, one memory budget |
| Docker Engine (inside WSL) | builds images and runs the k3d node container | Docker Desktop adds a second VM and a second memory budget to reason about |
| k3d → k3s v1.30.4 | a one-node Kubernetes cluster, in one Docker container | Traefik, servicelb and metrics-server switched off (`scripts/k3d-cluster.yaml`) |
| Helm | installs ingress-nginx and cert-manager | — |
| ingress-nginx | the only way in, on ports 80/443 of `127.0.0.1` | the AWS design is ALB → ingress-nginx |
| cert-manager | a self-signed CA and a TLS certificate | so HTTPS works locally; the browser warning is expected |
| Postgres 16 | one pod, five databases, one login role each | saves ~1.1 GB over one Postgres per service |
| 8 services | storefront, catalog, order, inventory, payment, advisor, notification, staff-portal | see [architecture.md](architecture.md) |

Three **profiles** decide how much runs:

| Profile | Runs | Measured memory (whole k3d node) |
|---|---|---|
| `core` | Postgres, catalog-service, storefront | 1.32 GiB (16 Sep 2026) |
| `commerce` | `core` + inventory, order, payment, advisor | ~2.05 GiB (16 Sep 2026) |
| `full-app` | `commerce` + notification-service, staff-portal | 2234 MiB (17 Sep); ~2.0 GiB settled (28 Sep 2026) |

`platform` (Argo CD) and `observability` (Prometheus, Tempo, OTel) are named in the design but have
**no manifests**. There is nothing to install for them.

---

## 1. Hardware and Windows

- 16 GB RAM (the design gives WSL 11 GB), 4 cores, **~25 GB free disk** on the drive WSL lives on.
  The Rust build alone uses several GB of Cargo cache.
- Windows 11 with WSL2. In an **administrator** PowerShell:

```powershell
wsl --install -d Ubuntu-24.04
wsl --set-default-version 2
```

Reboot if asked, open "Ubuntu" from the Start menu, and create your Linux user.

### Give WSL 11 GB

Create `C:\Users\<you>\.wslconfig` in Notepad:

```ini
[wsl2]
memory=11GB
processors=4
swap=4GB
```

Then, in PowerShell: `wsl --shutdown`, and open Ubuntu again. Check inside WSL:

```bash
free -g        # "total" on the Mem line should read 10 or 11
```

Without this file WSL measured ~7.4 GB on this machine, and `full-app` failed its memory check
twice. Swap is there so a Maven or Cargo build that briefly overshoots becomes slow instead of
being killed.

### Optional but recommended: systemd in WSL

With systemd, Docker starts by itself every time WSL starts. Without it you must run
`sudo service docker start` after every `wsl --shutdown` or Windows reboot.

```bash
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

Then `wsl --shutdown` in PowerShell and reopen Ubuntu.

---

## 2. Tools inside WSL

Run all of this **in the Ubuntu terminal, not PowerShell**.

```bash
sudo apt update && sudo apt install -y git curl ca-certificates gnupg openssl jq

# Docker Engine (not Docker Desktop)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
# close the terminal and open a new one, so the docker group applies
sudo service docker start          # skip if you enabled systemd above

# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl (1.30, to match the cluster) and helm
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm.list
sudo apt update && sudo apt install -y kubectl helm
```

Check every tool before going on. Each line must print something, not an error:

```bash
docker info --format '{{.ServerVersion}}'   # a version number, not "Cannot connect"
k3d version
kubectl version --client
helm version --short
```

You do **not** need Java, Go, Rust, Node or Python on the machine. Every service is compiled inside
its own Dockerfile with a pinned toolchain (Java 21, Go 1.25, Rust 1.90, Node, Python 3.11). Install
them only if you want to run the unit tests outside Docker (section 8).

---

## 3. Get the code

Clone into the **Linux** filesystem (`~`), never under `/mnt/c/`. Crossing into the Windows drive
makes Docker, Maven and Cargo much slower.

```bash
cd ~
git clone https://github.com/sayanc422/AquaHUB.git
cd AquaHUB
git branch --show-current     # claude/clever-shannon-ivtkw6: the default branch; there is no main
```

---

## 4. First run: the `core` profile

Start small. `core` is three workloads and the shortest path to a fish in a browser.

```bash
./scripts/bootstrap.sh --metrics
```

What it does, in order, and roughly how long each step takes on this machine:

1. **Preflight**: tools present, Docker reachable, more than 4000 MB of free memory.
2. **Cluster**: `k3d cluster create` from `scripts/k3d-cluster.yaml` (or reuses an existing one).
3. **metrics-server** (only with `--metrics`, so `kubectl top` works; ~50 MB).
4. **ingress-nginx** and **cert-manager** with Helm, then the CA issuer.
5. **Build** `catalog-service` (Maven inside Docker, several minutes the first time) and
   `storefront`, then `k3d image import` them. There is no registry.
6. **Apply** `platform-repo/dev` with `kubectl apply -k`, then point the two Deployments at `:dev`.
7. **Wait** for Postgres, then catalog-service (Flyway runs all migrations up to `V26` during
   startup; up to 300 s), then storefront.
8. **Verify**: `GET https://aquashop.localtest.me/api/categories` must answer.

When it ends with `open https://aquashop.localtest.me/`, open that in a Windows browser. Accept the
certificate warning: the certificate comes from a CA the cluster made itself, so the warning is
correct. `localtest.me` resolves to `127.0.0.1` on public DNS, so you need no hosts-file edit.

---

## 5. Create the enquiry encryption key (before `commerce`)

The custom-tank enquiry form stores contact details encrypted by Postgres
([ADR 0021](adr/0021-encrypt-enquiry-contact-details-in-postgres.md)). Its key is the one secret
that is **not** in Git, so nothing creates it for you. Create it now, while only `core` runs, so
the order-service rollout does not need a restart later:

```bash
kubectl create secret generic order-inquiry-key --namespace aquashop-dev \
  --from-literal=INQUIRY_ENCRYPTION_KEY="$(openssl rand -base64 48)"

# Keep a copy OUTSIDE the cluster. There is no recovery: lose it and stored enquiries are unreadable.
kubectl -n aquashop-dev get secret order-inquiry-key \
  -o jsonpath='{.data.INQUIRY_ENCRYPTION_KEY}' | base64 -d > ~/aquashop-inquiry-key.txt
chmod 600 ~/aquashop-inquiry-key.txt
```

Without it, everything still starts. Only `POST /inquiries` answers 503, and the storefront says
the form is not taking enquiries. The full procedure, including rotation, is
[runbooks/rotate-or-create-the-inquiry-key.md](runbooks/rotate-or-create-the-inquiry-key.md).

---

## 6. The whole shop: `full-app`

```bash
./scripts/bootstrap.sh --profile full-app --metrics
```

It reuses the cluster and adds inventory, order, payment, advisor, notification and staff-portal.
It needs **more than 6000 MB free** before it starts (`free -m`, "available" column), because
building eight images and rolling out eight Deployments peaks well above the ~2 GiB the shop uses
at rest. Close browsers and IDEs if the check fails.

The first run is slow: `payment-service` is a cold Rust build (minutes) and `staff-portal` is a
Maven build plus a WildFly base image. Later runs reuse Docker's layer cache.

To stop at `commerce` instead, use `--profile commerce`.

---

## 7. Check the installation

```bash
kubectl -n aquashop-dev get pods
```

All pods `Running` and `1/1` READY. With `full-app`, that is nine: `postgres-0` and one pod each
for the eight services. Then:

| Check | Command or URL | Expected |
|---|---|---|
| Shop front | <https://aquashop.localtest.me/> | the home page with photographs |
| A product page | <https://aquashop.localtest.me/p/betta-male-crowntail> | a red male crowntail (added by `V26`) |
| Tank checker | <https://aquashop.localtest.me/compatibility> | a form; a verdict whose footer names the advisor rules version (5) |
| Catalogue API | `curl -ks https://aquashop.localtest.me/api/categories \| jq length` | a number, not an error |
| Staff portal | <https://staff.aquashop.localtest.me/> | the read-only back office |
| Migrations | `kubectl -n aquashop-dev logs deploy/catalog-service \| grep -i "schema"` | Flyway names version 26 ("Migrating schema … to version 26", or "Current version of schema \"public\": 26") |
| Enquiry key | `kubectl -n aquashop-dev logs deploy/order-service \| grep -c 'enquiries are DISABLED'` | `0` |
| Memory | `kubectl top pods -n aquashop-dev` | about 2 GiB in total |
| Compression | `curl -ks -H 'Accept-Encoding: br' -o /dev/null -w '%{size_download}\n' https://aquashop.localtest.me/` | well above 0; a 0 means a blank white page in the browser |

The last check matters because plain `curl` sends no `Accept-Encoding` and so can show a perfect
page that a browser receives as zero bytes. Browsers always ask for compression.

---

## 8. Optional: run the unit tests

Only needed if you change code. Each needs its own toolchain, or run it in Docker as shown for the
catalogue (which needs Docker because it starts a real Postgres with Testcontainers):

```bash
cd services/aquatics-advisor     && python3 -m pytest          # 38 tests
cd services/inventory-service    && go test ./...
cd services/notification-service && go test ./...
cd services/payment-service      && cargo test                 # DB tests need PAYMENTS_TEST_DSN
cd services/order-service        && mvn test                   # DB tests need ORDER_TEST_DSN
cd services/staff-portal         && mvn test
```

The catalogue's `CatalogApiTest` (39 tests at `V26`), with no local Maven:

```bash
cd ~/AquaHUB/services/catalog-service
echo "api.version=1.44" > /tmp/docker-java.properties
docker run --rm -v "$PWD":/build -w /build -v aquashop-m2:/root/.m2 \
  -v /tmp/docker-java.properties:/root/.docker-java.properties \
  -v /var/run/docker.sock:/var/run/docker.sock -e TESTCONTAINERS_HOST_OVERRIDE=172.17.0.1 \
  maven:3.9-eclipse-temurin-21 mvn -B -q test
sudo chown -R "$USER" target      # target/ comes out owned by root
```

---

## 9. Stopping, starting and uninstalling

| Want to | Command | Keeps the data? |
|---|---|---|
| Pause everything (free the memory) | `k3d cluster stop aquashop` | yes |
| Resume | `k3d cluster start aquashop` | yes |
| Close WSL entirely | `wsl --shutdown` in PowerShell; after reopening, `sudo service docker start` (without systemd) and `k3d cluster start aquashop` | yes |
| Delete the cluster | `./scripts/bootstrap.sh --destroy` | **no**: databases, orders and the enquiry key go with it |
| Remove images and build cache | `docker image prune -a` and `docker builder prune` | n/a |

After `--destroy` and a fresh `bootstrap.sh`, you must create the enquiry key again (section 5),
from your saved copy if you want old enquiries to stay readable. None will survive a destroy anyway,
because the database goes with the cluster.

---

## 10. What is not installed, on purpose

- **Nothing on AWS.** The Terraform is validated with mock providers and has never been applied.
- **No Argo CD, no Prometheus/Grafana, no NATS.** Budgeted profiles, no manifests.
- **No real payments or email.** payment-service's acquirer is a stub; notification-service logs
  a stub email instead of sending one.
- **No shopping cart on the shop front.** order-service's cart and checkout API works, but the
  storefront does not call it yet; every call to action goes to the enquiry form.
- **Secrets in Git.** `platform-repo/dev/postgres/secret.yaml` holds the dev database passwords in
  plaintext. Never reuse them anywhere real.
