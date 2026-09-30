# Installation manual: from a bare Windows machine to a running AquaShop

This takes a Windows 11 PC with nothing installed to the full platform (all eight services) running
in k3d inside WSL2. Once it is running, [operations-guide.md](operations-guide.md) covers starting,
updating, troubleshooting and backing it up. [diagrams/physical.svg](diagrams/physical.svg) shows
what ends up where.

**The reference machine** is the one this repository runs on. These versions were read off it on
30 September 2026. Newer versions will probably work, but only these have been run:

| Component | Version on the reference machine |
|---|---|
| Windows 11, 16 GB RAM | WSL 2.7.12.0, kernel 6.18.33.2 |
| Ubuntu (WSL) | 24.04.4 LTS, `systemd=true` |
| Docker Engine (inside WSL, **not** Docker Desktop) | 29.8.1 |
| k3d | 5.9.0 (cluster node image pinned to `rancher/k3s:v1.30.4-k3s1` by `scripts/k3d-cluster.yaml`) |
| kubectl | 1.37.0 client against a 1.30 server |
| Helm | 3.22.0 |
| git / python3 / openssl | 2.43 / 3.12 / 3.0 |

kubectl 1.37 against a 1.30 server is outside Kubernetes' supported skew of one minor version
either way. Every command in these guides works with it on this machine anyway. To stay inside the
supported range, install kubectl 1.30 (step 5 shows how).

---

## Step 1. Check the hardware

- 16 GB RAM. The design gives WSL 11 GB and leaves the rest for Windows.
- Virtualisation enabled in the BIOS/UEFI. In Task Manager → Performance → CPU, "Virtualization"
  should say *Enabled*.
- About 20 GB of free disk for images, build caches and the node. The reference machine's WSL disk
  has 44 GB used in total, including everything else on it.

## Step 2. Install WSL2 and Ubuntu (PowerShell, as Administrator)

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot when asked, then open **Ubuntu** from the Start menu and create your Linux user. Check it
from PowerShell:

```powershell
wsl --version
wsl -l -v          # Ubuntu-24.04 should show VERSION 2
```

## Step 3. Give WSL enough memory (Windows side)

Create `C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
memory=11GB
processors=4
swap=4GB
```

Then, in PowerShell:

```powershell
wsl --shutdown
```

Open Ubuntu again and check:

```bash
grep MemTotal /proc/meminfo     # ~11 GB (11217516 kB on the reference machine); ~7.4 GB means the file isn't applied
nproc                           # 4
```

## Step 4. Turn on systemd in Ubuntu

With systemd on, Docker, and with it the cluster, starts by itself every time WSL starts. Recent
Ubuntu images already have it; check first:

```bash
cat /etc/wsl.conf
```

If it doesn't contain `systemd=true`:

```bash
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

Then run `wsl --shutdown` in PowerShell and reopen Ubuntu. `ps -p 1 -o comm=` should print
`systemd`.

## Step 5. Install the tools (inside Ubuntu)

**Docker Engine**, installed in WSL itself. Docker Desktop would add a second VM with its own
memory budget, which makes memory problems much harder to diagnose.

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker
exit                                  # close the terminal and open a new one, so the group applies
```

```bash
docker info >/dev/null && echo "docker ok"
systemctl is-enabled docker           # enabled
```

**k3d, kubectl, Helm:**

```bash
# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl, pinned to the cluster's minor version (1.30) to stay inside the supported skew
curl -fsSLo kubectl https://dl.k8s.io/release/v1.30.4/bin/linux/amd64/kubectl
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

k3d version; kubectl version --client; helm version --short
```

**git, GitHub CLI, python3, openssl.** Ubuntu 24.04 ships python3, git and openssl. Add `gh` for
pushing:

```bash
sudo apt update && sudo apt install -y git gh python3 openssl curl
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
gh auth login                         # choose GitHub.com → HTTPS → log in with a browser
```

**Optional: the documentation renderer.** It's only needed for `./scripts/render-docs.sh` and
browser screenshots. It is a large download (2.8 GB):

```bash
docker pull mcr.microsoft.com/playwright:v1.48.0-jammy
```

## Step 6. Get the code, onto the Linux filesystem

```bash
mkdir -p ~/Config-Scripts/Repo && cd ~/Config-Scripts/Repo
git clone https://github.com/sayanc422/AquaHUB.git
cd AquaHUB
git branch --show-current              # claude/clever-shannon-ivtkw6 (the only branch; there is no main)
```

Do **not** clone under `/mnt/c/...`. Reading Windows files from WSL is slow for Docker, Maven and
Cargo, and it makes some tools silently miss files.

## Step 7. Bring the platform up

```bash
./scripts/bootstrap.sh --profile full-app --metrics
```

What this does, in order, with the `==>` line it prints for each step:

1. **Preflight:** checks that `docker`, `k3d`, `kubectl` and `helm` exist, that Docker answers,
   and that more than 6000 MB of memory is free.
2. **Cluster:** `k3d cluster create` from `scripts/k3d-cluster.yaml`. That's one node, host ports
   80 and 443, and Traefik, servicelb and the bundled metrics-server turned off.
3. **metrics-server** through Helm, because of `--metrics`. Without it, `kubectl top` doesn't work.
4. **ingress-nginx** and **cert-manager** through Helm, and the self-signed CA issuer.
5. **Builds all eight images** (`aquashop/<service>:dev`) and imports them into the node. This is
   the long step: the Rust and WildFly builds dominate, and a first build downloads every
   dependency. It hasn't been timed.
6. **Applies the manifests** in `platform-repo/dev/` and waits for Postgres, then each service.
   Flyway and the Go/Rust migrators create the schemas as the services start.
7. **Verify:** lists the pods, checks the catalog API through the ingress, and prints
   `kubectl top`.

Expect one warning near step 6: `Secret order-inquiry-key is missing`. That is by design.

## Step 8. Create the enquiry encryption key (once per cluster)

The custom-tank enquiry form stores contact details encrypted with a key that is deliberately in
no file and no script ([ADR 0021](adr/0021-encrypt-enquiry-contact-details-in-postgres.md)). Create
it, save a copy, and restart the one service that reads it:

```bash
mkdir -p ~/aquashop-backups
openssl rand -base64 48 | tr -d '\n' > ~/aquashop-backups/inquiry-key
chmod 600 ~/aquashop-backups/inquiry-key
kubectl create secret generic order-inquiry-key --namespace aquashop-dev \
  --from-file=INQUIRY_ENCRYPTION_KEY=$HOME/aquashop-backups/inquiry-key
kubectl -n aquashop-dev rollout restart deployment/order-service
kubectl -n aquashop-dev rollout status  deployment/order-service --timeout=300s
```

If you lose this key, every enquiry stored with it is unreadable for good. Keep the copy outside
the repository.

## Step 9. Check it works

```bash
kubectl -n aquashop-dev get pods          # 9 pods, all 1/1 Running
kubectl top node                          # ~2 GiB (2053 MiB on the reference machine)
curl -sk -o /dev/null -w '%{http_code}\n' https://aquashop.localtest.me/healthz        # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://staff.aquashop.localtest.me/        # 200
```

Then, in a browser **on Windows**, open:

- <https://aquashop.localtest.me/>: the shop
- <https://staff.aquashop.localtest.me/>: the read-only staff portal
- <https://aquashop.localtest.me/api/categories>: the catalog API as JSON

The browser will warn about the certificate. That's expected, because cert-manager signs it with
a CA it created inside the cluster. `localtest.me` is a public DNS name that points to `127.0.0.1`,
and WSL forwards Windows' localhost ports 80/443 into Linux, so no hosts-file edit is needed.

Run the 60-second health check in [operations-guide.md §2](operations-guide.md#2-a-60-second-health-check)
for a fuller picture.

## Step 10. If a step failed

| Where it stopped | Look at |
|---|---|
| `missing required tool: …` | Step 5 for that tool |
| `docker engine is not reachable` | `sudo systemctl start docker`; a new terminal after `usermod` |
| `need >6000 MB free` | Step 3 (`MemTotal` should be ~11 GB); close heavy Windows apps |
| k3d create fails with `port is already allocated` | Something on Windows or WSL already holds 80/443: [operations-guide.md §4.1](operations-guide.md#41-by-symptom) |
| A `docker build` fails | Read the first error, not the last. Exit 137 means out of memory: build again with less running |
| `rollout status` times out | `kubectl -n aquashop-dev get pods`, then [operations-guide.md §4](operations-guide.md#4-troubleshooting-where-to-look-in-order) |
| `ingress reachable but the API is not answering` | `kubectl -n aquashop-dev logs deploy/catalog-service` (usually Flyway or Postgres) |

`bootstrap.sh` is safe to re-run: it reuses the cluster and picks up where things stand.

---

## Smaller setups

| Command | Brings up | Measured |
|---|---|---|
| `./scripts/bootstrap.sh` | `core`: Postgres, catalog, storefront | 1.32 GiB |
| `./scripts/bootstrap.sh --profile commerce` | + order, inventory, payment, advisor | ~2.05 GiB |
| `./scripts/bootstrap.sh --profile full-app` | + notification, staff-portal | 2053 MiB (30 Sep 2026) |

In `core`, the storefront has no `order-service` to send enquiries to, so the enquiry form fails
there (honestly, with the customer's text kept) and the tank checker has no advisor.

## Uninstalling

```bash
# back up first if the data matters: operations-guide.md §7
./scripts/bootstrap.sh --destroy       # removes the cluster, its database and its secrets
docker image rm $(docker images 'aquashop/*' -q)
docker volume rm aquashop-m2 aquashop-npm aquashop-maven-repo maven-repo-cache 2>/dev/null
```

To remove WSL entirely: `wsl --unregister Ubuntu-24.04` in PowerShell. This deletes the whole
Linux disk, including the repository clone.
