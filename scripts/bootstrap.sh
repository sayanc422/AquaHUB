#!/usr/bin/env bash
# AquaShop local bootstrap. From nothing to a fish in a browser.
#
#   ./scripts/bootstrap.sh                      bring up the `core` profile
#   ./scripts/bootstrap.sh --profile commerce   core + inventory-service
#   ./scripts/bootstrap.sh --destroy            delete the cluster
#
# Profiles exist because 11 GB does not hold the whole platform at once. They
# are not a workaround bolted on at the end: they are why NATS replaced Kafka,
# why one Postgres instance hosts a database per service, and why only one
# environment is ever materialised.
#
# Everything here runs against k3d. Nothing in this script touches AWS.
set -Eeuo pipefail

CLUSTER=aquashop
PROFILE=core
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

  local avail_mb
  avail_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  log "available memory: ${avail_mb} MB"
  # The core profile needs ~2.6 GB. Below 4 GB free, the OOM killer will start
  # taking pods and you will debug Kubernetes for an hour to find a WSL problem.
  local need_mb=4000
  [[ "$PROFILE" == commerce ]] && need_mb=5000   # order-service is a second JVM
  (( avail_mb > need_mb )) || die "need >${need_mb} MB free for the ${PROFILE} profile; close something or raise WSL memory in .wslconfig"

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
  if [[ "$PROFILE" == commerce ]]; then
    docker build -t aquashop/inventory-service:dev "${ROOT}/services/inventory-service"
    docker build -t aquashop/order-service:dev     "${ROOT}/services/order-service"
    # Slowest build in the repository by a wide margin. Cargo's dependency
    # layer is cached, but a cold build is minutes, not seconds.
    docker build -t aquashop/payment-service:dev   "${ROOT}/services/payment-service"
    images+=(aquashop/inventory-service:dev aquashop/order-service:dev aquashop/payment-service:dev)
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

  if [[ "$PROFILE" == commerce ]]; then
    # Applied with -f, not through the dev kustomization, because the
    # kustomization is the `core` profile. At Phase 4 Argo CD owns profiles and
    # both of these lines go away.
    log "applying commerce profile (inventory-service, order-service, payment-service)"
    kubectl apply -f "${ROOT}/platform-repo/dev/inventory/"
    kubectl apply -f "${ROOT}/platform-repo/dev/payment/"
    kubectl apply -f "${ROOT}/platform-repo/dev/order/"
    kubectl -n "$NS" set image deployment/inventory-service inventory-service=aquashop/inventory-service:dev
    kubectl -n "$NS" set image deployment/order-service     order-service=aquashop/order-service:dev
    kubectl -n "$NS" set image deployment/payment-service   payment-service=aquashop/payment-service:dev
    # The role and database are created by the Postgres init script, which only
    # runs on an empty data directory. On a cluster whose PVC predates this
    # service, see docs/runbooks/add-a-service-database.md.
    log "waiting for inventory-service (migrations run inside the startup probe window)"
    kubectl -n "$NS" rollout status deployment/inventory-service --timeout=120s
    log "waiting for payment-service"
    kubectl -n "$NS" rollout status deployment/payment-service --timeout=120s
    log "waiting for order-service"
    kubectl -n "$NS" rollout status deployment/order-service --timeout=300s
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
  kubectl top pods -A 2>/dev/null || warn "metrics-server is disabled; use 'docker stats' for the node total"
}

destroy() { log "deleting cluster"; k3d cluster delete "$CLUSTER"; }

main() {
  while (( $# )); do
    case "$1" in
      --destroy) destroy; exit 0 ;;
      --profile) PROFILE="${2:-}"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  case "$PROFILE" in
    core|commerce) ;;
    *) die "unknown profile: ${PROFILE} (core|commerce)" ;;
  esac
  log "profile: ${PROFILE}"

  preflight
  create_cluster
  install_platform
  build_images
  deploy
  verify
}
main "$@"
