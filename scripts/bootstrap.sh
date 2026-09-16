#!/usr/bin/env bash
# AquaShop local bootstrap. From nothing to a fish in a browser.
#
#   ./scripts/bootstrap.sh                      bring up the `core` profile
#   ./scripts/bootstrap.sh --profile commerce   core + inventory-service
#   ./scripts/bootstrap.sh --profile full-app   commerce + notification-service + staff-portal
#   ./scripts/bootstrap.sh --metrics            also install metrics-server
#   ./scripts/bootstrap.sh --destroy            delete the cluster
#
# Profiles exist because 11 GB does not hold the whole platform at once. They
# are not a workaround bolted on at the end: they are why NATS replaced Kafka,
# why one Postgres instance hosts a database per service, and why only one
# environment is ever materialised. That 11 GB is the *target*, reached only
# by the `.wslconfig` memory override in docs/getting-started-locally.md; an
# unconfigured WSL2 default measures ~7.4 GB instead (see docs/architecture.md
# §8) -- full-app is the profile most likely to feel that gap first.
#
# Everything here runs against k3d. Nothing in this script touches AWS.
set -Eeuo pipefail

CLUSTER=aquashop
PROFILE=core
METRICS=no
NS=aquashop-dev
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST=aquashop.localtest.me

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

preflight() {
  for t in docker k3d kubectl helm; do need "$t"; done
  docker info >/dev/null 2>&1 || die "docker engine is not reachable from this shell"

  local avail_mb total_mb
  avail_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  log "available memory: ${avail_mb} MB (WSL2 total: ${total_mb} MB)"
  # The core profile needs ~2.6 GB. Below 4 GB free, the OOM killer will start
  # taking pods and you will debug Kubernetes for an hour to find a WSL problem.
  local need_mb=4000
  [[ "$PROFILE" == commerce ]] && need_mb=5000   # order-service is a second JVM
  # full-app adds a Go service (small) and a full WildFly install (not small,
  # and unmeasured in k3d as of this writing) on top of everything commerce
  # already needs.
  [[ "$PROFILE" == full-app ]] && need_mb=6000
  (( avail_mb > need_mb )) || die "need >${need_mb} MB free for the ${PROFILE} profile; close something or raise WSL memory in .wslconfig"

  # This is a real ceiling, not a suggestion: an unconfigured WSL2 default is
  # ~7.4 GB total (measured, not the 11 GB docs/getting-started-locally.md's
  # .wslconfig override targets), and full-app's own estimate leaves little
  # headroom inside that. See docs/architecture.md §8.
  if [[ "$PROFILE" == full-app && "$total_mb" -lt 8000 ]]; then
    warn "WSL2 total memory is ${total_mb} MB -- the .wslconfig override this profile was" \
         "designed against (11 GB) does not appear to be applied. full-app may not fit;" \
         "if it doesn't, that's docs/getting-started-locally.md#memory, not a bug here."
  fi

  if pgrep -f 'docker build' >/dev/null 2>&1; then
    warn "a docker build is running. Builds and the full profile do not co-exist in 11 GB."
  fi
}

create_cluster() {
  if k3d cluster list | grep -q "^${CLUSTER}\b"; then
    log "cluster ${CLUSTER} exists, reusing it"
  else
    log "creating k3d cluster (traefik and servicelb disabled)"
    k3d cluster create --config "${ROOT}/scripts/k3d-cluster.yaml"
  fi
  kubectl config use-context "k3d-${CLUSTER}" >/dev/null
}

# k3s ships metrics-server and scripts/k3d-cluster.yaml disables it, because the
# ~50 MB it costs buys nothing on a cluster nobody autoscales. But `kubectl top`
# is the only way to replace this repository's estimated memory figures with
# measured ones, so it is an opt-in rather than a deletion.
#
# --kubelet-insecure-tls is required on k3d: the kubelet serves a self-signed
# certificate that metrics-server has no way to verify. On EKS this flag is not
# set, and must not be.
install_metrics() {
  [[ "$METRICS" == yes ]] || return 0
  log "installing metrics-server (opt-in; needed for 'kubectl top')"
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set 'args={--kubelet-insecure-tls}' \
    --set resources.requests.memory=32Mi \
    --set resources.limits.memory=96Mi \
    --wait --timeout 3m
}

install_platform() {
  log "installing ingress-nginx"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=ClusterIP \
    --set controller.hostPort.enabled=true \
    --set controller.resources.requests.memory=96Mi \
    --set controller.resources.limits.memory=192Mi \
    --set controller.metrics.enabled=true \
    --wait --timeout 5m

  log "installing cert-manager"
  helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true \
    --set resources.requests.memory=48Mi \
    --wait --timeout 5m

  kubectl apply -f "${ROOT}/platform-repo/dev/ingress/issuer.yaml"
  kubectl wait --for=condition=Ready certificate/aquashop-ca -n cert-manager --timeout=120s
}

build_images() {
  log "building images (this is the memory-hungry step; observability profile must be down)"
  local images=(aquashop/catalog-service:dev aquashop/storefront:dev)
  docker build -t aquashop/catalog-service:dev "${ROOT}/services/catalog-service"
  docker build -t aquashop/storefront:dev      "${ROOT}/services/storefront"
  if [[ "$PROFILE" == commerce || "$PROFILE" == full-app ]]; then
    docker build -t aquashop/inventory-service:dev "${ROOT}/services/inventory-service"
    docker build -t aquashop/order-service:dev     "${ROOT}/services/order-service"
    # Slowest build in the repository by a wide margin. Cargo's dependency
    # layer is cached, but a cold build is minutes, not seconds.
    docker build -t aquashop/payment-service:dev   "${ROOT}/services/payment-service"
    docker build -t aquashop/aquatics-advisor:dev  "${ROOT}/services/aquatics-advisor"
    images+=(aquashop/inventory-service:dev aquashop/order-service:dev \
             aquashop/payment-service:dev aquashop/aquatics-advisor:dev)
  fi
  if [[ "$PROFILE" == full-app ]]; then
    docker build -t aquashop/notification-service:dev "${ROOT}/services/notification-service"
    # The slowest build in the repository now: a Maven build stage plus a
    # WildFly base image, neither of which is small.
    docker build -t aquashop/staff-portal:dev         "${ROOT}/services/staff-portal"
    images+=(aquashop/notification-service:dev aquashop/staff-portal:dev)
  fi
  log "importing images into k3d (no registry round-trip)"
  k3d image import -c "${CLUSTER}" "${images[@]}"
}

deploy() {
  log "applying dev overlay"
  kubectl apply -k "${ROOT}/platform-repo/dev"
  # Phase 1 only: Phase 4 hands this to Argo CD and this line is deleted.
  kubectl -n "$NS" set image deployment/catalog-service catalog-service=aquashop/catalog-service:dev
  kubectl -n "$NS" set image deployment/storefront      storefront=aquashop/storefront:dev

  log "waiting for postgres"
  kubectl -n "$NS" rollout status statefulset/postgres --timeout=180s
  log "waiting for catalog-service (Flyway runs during startup, inside the startup probe window)"
  kubectl -n "$NS" rollout status deployment/catalog-service --timeout=300s
  log "waiting for storefront"
  kubectl -n "$NS" rollout status deployment/storefront --timeout=120s

  if [[ "$PROFILE" == commerce || "$PROFILE" == full-app ]]; then
    # Applied with -f, not through the dev kustomization, because the
    # kustomization is the `core` profile. At Phase 4 Argo CD owns profiles and
    # both of these lines go away.
    log "applying commerce profile (inventory, order, payment, advisor)"
    kubectl apply -f "${ROOT}/platform-repo/dev/inventory/"
    kubectl apply -f "${ROOT}/platform-repo/dev/payment/"
    kubectl apply -f "${ROOT}/platform-repo/dev/advisor/"
    kubectl apply -f "${ROOT}/platform-repo/dev/order/"
    kubectl -n "$NS" set image deployment/inventory-service inventory-service=aquashop/inventory-service:dev
    kubectl -n "$NS" set image deployment/order-service     order-service=aquashop/order-service:dev
    kubectl -n "$NS" set image deployment/payment-service   payment-service=aquashop/payment-service:dev
    kubectl -n "$NS" set image deployment/aquatics-advisor aquatics-advisor=aquashop/aquatics-advisor:dev
    # The role and database are created by the Postgres init script, which only
    # runs on an empty data directory. On a cluster whose PVC predates this
    # service, see docs/runbooks/add-a-service-database.md.
    log "waiting for inventory-service (migrations run inside the startup probe window)"
    kubectl -n "$NS" rollout status deployment/inventory-service --timeout=120s
    log "waiting for payment-service"
    kubectl -n "$NS" rollout status deployment/payment-service --timeout=120s
    log "waiting for aquatics-advisor"
    kubectl -n "$NS" rollout status deployment/aquatics-advisor --timeout=120s
    log "waiting for order-service"
    kubectl -n "$NS" rollout status deployment/order-service --timeout=300s
  fi

  if [[ "$PROFILE" == full-app ]]; then
    log "applying full-app profile (notification, staff-portal)"
    kubectl apply -f "${ROOT}/platform-repo/dev/notification/"
    kubectl apply -f "${ROOT}/platform-repo/dev/staff-portal/"
    kubectl -n "$NS" set image deployment/notification-service notification-service=aquashop/notification-service:dev
    kubectl -n "$NS" set image deployment/staff-portal         staff-portal=aquashop/staff-portal:dev
    log "waiting for notification-service"
    kubectl -n "$NS" rollout status deployment/notification-service --timeout=120s
    # This is what flips order-service's default-noop NotificationClient on.
    # commerce alone never sets these, so a commerce-only cluster is byte-for-
    # byte unaffected by any of this profile's code.
    kubectl -n "$NS" set env deployment/order-service \
      NOTIFICATION_CLIENT=http NOTIFICATION_BASE_URL=http://notification-service:8085
    log "waiting for order-service to pick up the notification client (triggers a rollout)"
    kubectl -n "$NS" rollout status deployment/order-service --timeout=180s
    # WildFly's boot time is unmeasured in this repository as of this writing --
    # generous on purpose, matching catalog-service's own "slow JVM boot"
    # precedent (30 x 5s). Correct this after the first real measurement.
    log "waiting for staff-portal (WildFly boot -- this is the slow one)"
    kubectl -n "$NS" rollout status deployment/staff-portal --timeout=600s
  fi
}

verify() {
  log "verifying"
  kubectl -n "$NS" get pods -o wide
  echo
  if curl -fsk "https://${HOST}/api/categories" >/dev/null; then
    log "catalog API answering through ingress"
  else
    die "ingress reachable but the API is not answering; try: kubectl -n $NS logs deploy/catalog-service"
  fi
  echo
  log "open https://${HOST}/  (self-signed certificate: the browser warning is expected)"
  log "measured footprint:"
  if ! kubectl top pods -A 2>/dev/null; then
    warn "metrics-server is not installed, so there are no measured figures."
    warn "Re-run with --metrics to install it, or use 'docker stats' for the node total."
  fi
}

destroy() { log "deleting cluster"; k3d cluster delete "$CLUSTER"; }

main() {
  while (( $# )); do
    case "$1" in
      --destroy) destroy; exit 0 ;;
      --profile) PROFILE="${2:-}"; shift 2 ;;
      --metrics) METRICS=yes; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  case "$PROFILE" in
    core|commerce|full-app) ;;
    *) die "unknown profile: ${PROFILE} (core|commerce|full-app)" ;;
  esac
  log "profile: ${PROFILE}"

  preflight
  create_cluster
  install_metrics
  install_platform
  build_images
  deploy
  verify
}
main "$@"
