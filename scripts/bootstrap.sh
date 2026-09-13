#!/usr/bin/env bash
# AquaShop local bootstrap. From nothing to a fish in a browser.
#
#   ./scripts/bootstrap.sh            bring up the `core` profile
#   ./scripts/bootstrap.sh --destroy  delete the cluster
#
# Everything here runs against k3d. Nothing in this script touches AWS.
set -Eeuo pipefail

CLUSTER=aquashop
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
  (( avail_mb > 4000 )) || die "need >4000 MB free; close something or raise WSL memory in .wslconfig"

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
  docker build -t aquashop/catalog-service:dev "${ROOT}/services/catalog-service"
  docker build -t aquashop/storefront:dev      "${ROOT}/services/storefront"
  log "importing images into k3d (no registry round-trip)"
  k3d image import -c "${CLUSTER}" aquashop/catalog-service:dev aquashop/storefront:dev
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
  [[ "${1:-}" == "--destroy" ]] && { destroy; exit 0; }
  preflight
  create_cluster
  install_platform
  build_images
  deploy
  verify
}
main "$@"
