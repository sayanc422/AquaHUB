# Getting AquaShop running locally

Everything in this repository has been verified by running the services directly against a local
Postgres, and — as of 16 September 2026 — the `core` and `commerce` profiles have both run in k3d
via `scripts/bootstrap.sh`, including a live checkout saga in-cluster. `full-app`, `platform` and
`observability` have not; see [context_summary.md](context_summary.md) for what remains open.

This page is the short list of what to install and what to run.

---

## 1. Install (WSL2, Ubuntu 22.04 or 24.04)

**Yes — install Docker Engine.** It is the blocker. Install it *inside WSL2*, not Docker Desktop.

Docker Desktop works, but it runs the daemon in its own `docker-desktop` VM and gives you a second
memory budget to reason about on top of `.wslconfig`. On an 11 GB machine where the whole design is
shaped by memory profiles, that second budget is the thing that will confuse an OOMKill
investigation at 02:00. Engine-in-WSL2 means one VM, one `MemAvailable`, one number.

```bash
# Docker Engine
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"      # then: exit the shell and open a new one
sudo service docker start            # WSL2 has no systemd by default

# k3d, kubectl, helm
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm.list
sudo apt update && sudo apt install -y kubectl helm
```

Check it works before anything else:

```bash
docker info >/dev/null && echo "docker ok"
k3d version; kubectl version --client; helm version --short
```

### Memory

Put this in `C:\Users\<you>\.wslconfig` (Windows side), then `wsl --shutdown` from PowerShell:

```ini
[wsl2]
memory=11GB
processors=4
swap=4GB
```

`bootstrap.sh` refuses to start below 4 GB free (5 GB for `commerce`) rather than letting the OOM
killer make the decision for you. Swap is there so a Maven or Cargo build that briefly overshoots
gets slow instead of killed.

### Disk

Budget ~20 GB. The Rust build alone is several GB of Cargo cache, and six images plus the k3s node
image add up.

---

## 2. Who runs Docker, and who can see it

Worth being explicit, because it changes how we work together.

**A Claude Code session on the web cannot reach your machine.** It runs in an isolated, ephemeral
container in Anthropic's cloud. It clones this repository from GitHub and that is the entire
connection — there is no network path from it to your laptop, your WSL instance, or the Docker
daemon inside it. Installing Docker Engine locally does not make it visible to a web session, and
nothing you can configure will.

**Do not expose the Docker socket over TCP to work around this.** Binding `dockerd` to
`tcp://0.0.0.0:2375`, or forwarding it through a tunnel, hands anyone who reaches that port
root-equivalent control of the host — the daemon runs as root and will happily mount your
filesystem into a container. It is one of the most reliably exploited misconfigurations there is.
There is no version of that idea worth doing for this project.

So there are two honest ways to work:

### Run Claude Code locally (recommended)

**A Windows install and a WSL install are two separate installations.** Installing Claude Code on
Windows does not give you a `claude` inside your WSL distribution, and a Windows-side `claude`
cannot run the Docker Engine you installed inside WSL. The docs are explicit: for WSL you install
and launch `claude` *inside the WSL terminal*, not from PowerShell or CMD.

So install it in WSL as well — having both is fine, they don't conflict:

```bash
# inside the WSL terminal, not PowerShell
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

Same login, same subscription. WSL 2 also supports
[sandboxing](https://code.claude.com/docs/en/sandboxing), which native Windows does not.

**Clone the repository onto the Linux filesystem, not `/mnt/c/`.** This matters more than it looks:

```bash
cd ~ && git clone https://github.com/sayanc422/AquaHUB.git   # ~/AquaHUB — good
# NOT /mnt/c/Users/you/AquaHUB — cross-filesystem, and slow
```

Reading Windows files from WSL crosses a filesystem boundary, and the penalty is bad enough that
Claude Code's own troubleshooting page lists it: search returns *fewer results than it should*,
silently, while `claude doctor` still reports Search as OK. On a repository this size that means
Claude quietly failing to find files. Docker, Maven and Cargo are all much slower across `/mnt/c`
too.

If you already cloned on the Windows side, clone again inside WSL and work there.

That WSL session has your Docker daemon, your k3d cluster, your `kubectl` context and your files.
It can run `./scripts/bootstrap.sh`, watch it fail, read the pod logs and fix it — the loop this
repository has never been through.

### What does and does not sync

| | Syncs | How |
|---|---|---|
| Code, migrations, docs | Yes | Git. It is the only channel. |
| Conversation history | No | Per-machine, in `~/.claude.json` |
| Settings, permissions, allowed tools | No | Per-machine, in `~/.claude/`. Windows and WSL each have their own |
| `CLAUDE.md` in the repo | Yes | It is a tracked file, so it is the way to carry standing instructions between sessions |

The working rule: **pull before you start, push when you stop, and only one session at a time on a
given branch.** A web session and a local session both committing to the same branch will conflict,
and neither can see the other's uncommitted work.

```bash
git pull origin claude/clever-shannon-ivtkw6     # before starting, always
# ... work ...
git push -u origin claude/clever-shannon-ivtkw6  # before switching to the other session
```

Note there is no `main` on this repository yet. `claude/clever-shannon-ivtkw6` is the only branch
and is the remote default, so a plain `git clone` checks it out.

### Or the copy-paste loop

Run the commands yourself and paste the output into a web session. Slower, and the debugging is
worse because the session is guessing at state it cannot inspect, but it works and needs nothing
installed beyond Docker.

For the first `bootstrap.sh` run, local is worth it. After that, either is fine.

---

## 3. Run it

```bash
./scripts/bootstrap.sh                      # core:     Postgres, catalog-service, storefront
./scripts/bootstrap.sh --profile commerce   # adds inventory, order, payment, advisor
./scripts/bootstrap.sh --destroy            # delete the cluster
```

Then open <https://aquashop.localtest.me/>. The certificate is signed by a self-signed CA that
cert-manager creates in-cluster, so the browser warning is expected and correct. `localtest.me`
resolves to `127.0.0.1` publicly, so there is no `/etc/hosts` edit.

Start with `core`. It is six pods and the shortest path to a fish in a browser. Only move to
`commerce` once `core` is green, because `commerce` builds a Rust service and a second JVM, and
you do not want to debug a cold Cargo build and an ingress problem at the same time.

Expect the first `commerce` run to take a while. The Rust build is the slowest thing in the
repository by a wide margin.

---

## 4. Observability — not yet, and not needed

**You do not need to install anything for observability, and there is nothing to install.**

The `observability` profile in `docs/context_summary.md` (kube-prometheus-stack, OTel collector,
Tempo, prometheus-adapter) is a *planned* profile. There are no manifests behind it. The same is
true of `platform` (Argo CD) and `full-app`. Those rows are budgets for work not yet done, not
descriptions of something you could run today. The shop works without them.

That is also deliberate ordering, not just unfinished work. The observability profile budgets
~9.2 GB, which leaves ~1.8 GB of headroom on an 11 GB machine — and ~1.8 GB does not survive a
Maven or Cargo build. `bootstrap.sh` enforces the rule: never build images while the observability
profile is up. So observability lands *after* the build loop is settled, not before.

What you get today instead: structured JSON logs from every service (`kubectl logs`), Spring
Actuator health and metrics endpoints on the Java services, and `/healthz` on the rest.

---

## 5. The one measurement worth sending back

Every memory figure in this repository except one is an estimate. `kubectl top` is how they become
measurements — but `scripts/k3d-cluster.yaml` disables k3s's bundled metrics-server, because ~50 MB
buys nothing on a cluster nobody autoscales.

So it is an opt-in:

```bash
./scripts/bootstrap.sh --profile commerce --metrics
kubectl top pods -A
kubectl top nodes
```

Send that output back. It replaces the estimates table in `docs/context_summary.md` with real
numbers and closes the oldest open item in the project.

If you would rather not spend the 50 MB, `docker stats` on the k3d node container gives the total
without the per-pod breakdown.

---

## 6. What to send back when it breaks

It probably will — this script has never run. The useful things:

- The full `bootstrap.sh` output, including the `==>` lines, so the failing step is identifiable.
- `kubectl -n aquashop-dev get pods -o wide` and `kubectl -n aquashop-dev describe pod <name>` for
  anything not `Running`.
- `kubectl -n aquashop-dev logs deploy/<service>` for a `CrashLoopBackOff`. Flyway and the Go and
  Rust migrators all run during startup, inside the startup probe window, so a migration failure
  looks like a crash loop rather than an error.
- `kubectl -n aquashop-dev get events --sort-by=.lastTimestamp | tail -30` for anything the quota
  or the LimitRange rejected.

Known likely failures, in rough order of probability:

| Symptom | Cause | Where it is written down |
|---|---|---|
| Pod `OOMKilled` | The limit is an estimate, not a measurement | `docs/runbooks/pod-oomkilled.md` |
| `inventory-service` or `order-service` cannot connect to Postgres | Their roles and databases are created by the Postgres init script, which only runs on an **empty** data directory. A PVC created by an earlier `core` run predates them | `docs/runbooks/add-a-service-database.md` |
| `https://aquashop.localtest.me/` refuses the connection | Ports 80/443 are mapped straight onto the WSL2 host. Something else already has them | — |
| Cargo build killed | A build during a run with little headroom | Raise `swap` in `.wslconfig` |

---

## 7. Inputs that have nothing to do with Docker

These are blocked on you, not on a cluster:

1. **The cichlid taxonomy split.** You asked for American / North American / South American /
   African under Cichlids. North and South American are subsets of American, so as written the tree
   has a category that contains its own siblings. Tell me which you want: *American* as a parent of
   *North* and *South*, or three flat siblings with *American* renamed (*Central American* is the
   usual third). The migration to fix it is small now and awkward once there are orders against
   those categories.

2. **Photograph licensing.** Every row in `services/storefront/public/species/CREDITS.md` currently
   says `unverified`. Before this is commercially usable each needs to become own / licensed /
   breeder-supplied. I cannot determine that; you can.

3. **Two re-shoots.** `nkhomo-benga-peacock.jpg` (1136 px) and `salvini.jpg` (474 px) are below the
   1200 px minimum the storefront's tiles assume. The second one is visibly soft at tile size.

4. **Species identification** on the handful of photos where the filename was ambiguous — I made a
   call and recorded it; an aquarist should confirm it before it is on a product page.

---

## Summary

| Question | Answer |
|---|---|
| Install Docker Engine? | Yes. Engine in WSL2, not Docker Desktop. It is the only hard blocker. |
| Can a web session use that Docker? | No, and nothing makes it possible. Run Claude Code locally, or paste output back. |
| Anything else to install? | `k3d`, `kubectl`, `helm`. ~11 GB RAM, ~20 GB disk. |
| Anything for observability? | No. It is not built, and the shop runs without it. |
| First command | `./scripts/bootstrap.sh` |
| Most valuable thing to send back | `kubectl top pods -A` after `--profile commerce --metrics` |
