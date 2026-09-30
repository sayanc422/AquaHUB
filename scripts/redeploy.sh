#!/usr/bin/env bash
# Rebuild one or more services and roll them out to a cluster that
# bootstrap.sh already created. This is the everyday "I changed code, put it
# in the cluster" loop; bootstrap.sh is the from-nothing path.
#
#   ./scripts/redeploy.sh storefront                    one service
#   ./scripts/redeploy.sh catalog-service storefront    several
#   ./scripts/redeploy.sh --all                         every service deployed in the cluster
#   ./scripts/redeploy.sh --list                        what is deployed, and which image it runs
#
# Why a new tag per build, not bootstrap.sh's fixed `:dev`:
#   Re-importing an image under a tag the Deployment already uses changes
#   nothing in the Deployment's spec, so Kubernetes starts no rollout and the
#   old code keeps running. You then need a `rollout restart`, and you still
#   cannot tell from the cluster which build is live. A tag made from the git
#   commit (plus a timestamp when the tree has uncommitted changes) makes every
#   build a spec change, makes "what is running" answerable with `--list`, and
#   makes `kubectl rollout undo` a real rollback to the previous build.
#   Cost: every build leaves an image in Docker and in the k3d node. Prune them
#   now and then (docs/operations-guide.md, "Disk").
#
# Nothing here touches AWS, Postgres data, Secrets or the ingress.
set -Eeuo pipefail

CLUSTER=aquashop
NS=aquashop-dev
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES=(catalog-service storefront inventory-service order-service payment-service
          aquatics-advisor notification-service staff-portal)

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

# Rollout deadlines, taken from bootstrap.sh's own. The JVMs run migrations
# inside their startup probe window, and WildFly is the slowest boot here.
timeout_for() {
  case "$1" in
    catalog-service|order-service) echo 300s ;;
    staff-portal)                  echo 600s ;;
    *)                             echo 120s ;;
  esac
}

is_known() { local s; for s in "${SERVICES[@]}"; do [[ "$s" == "$1" ]] && return 0; done; return 1; }

deployed() { kubectl -n "$NS" get deployment "$1" >/dev/null 2>&1; }

preflight() {
  local t
  for t in docker k3d kubectl git; do
    command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
  done
  docker info >/dev/null 2>&1 || die "docker engine is not reachable (WSL without systemd: sudo service docker start)"
  k3d cluster list 2>/dev/null | grep -q "^${CLUSTER}\b" \
    || die "no k3d cluster '${CLUSTER}'. Create it first: ./scripts/bootstrap.sh --profile full-app"
  kubectl config use-context "k3d-${CLUSTER}" >/dev/null
  kubectl -n "$NS" get deployment >/dev/null 2>&1 \
    || die "cannot reach namespace ${NS}. Is the cluster running? k3d cluster start ${CLUSTER}"
}

list() {
  kubectl -n "$NS" get deployments \
    -o custom-columns='DEPLOYMENT:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
}

make_tag() {
  local sha
  sha=$(git -C "$ROOT" rev-parse --short HEAD)
  # An uncommitted change gets its own tag, so two different builds are never
  # given the same name. The timestamp is what keeps the second one distinct.
  if [[ -n "$(git -C "$ROOT" status --porcelain -- services)" ]]; then
    echo "git-${sha}-dirty-$(date +%Y%m%d%H%M%S)"
  else
    echo "git-${sha}"
  fi
}

main() {
  local targets=() a
  (( $# )) || die "usage: $0 <service>... | --all | --list   (services: ${SERVICES[*]})"
  for a in "$@"; do
    case "$a" in
      --list) preflight; list; exit 0 ;;
      --all)  targets=("${SERVICES[@]}") ;;
      -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
      *) is_known "$a" || die "unknown service: $a (known: ${SERVICES[*]})"; targets+=("$a") ;;
    esac
  done

  preflight

  local wanted=() s
  for s in "${targets[@]}"; do
    if deployed "$s"; then
      wanted+=("$s")
    elif [[ "$#" -eq 1 && "$1" == --all ]]; then
      # --all means "everything this profile runs". A core cluster has no
      # payment-service, and building one it will never run is ten minutes wasted.
      warn "skipping $s: not deployed in this cluster (smaller profile)"
    else
      die "$s is not deployed in ${NS}. Deploy its profile first: ./scripts/bootstrap.sh --profile full-app"
    fi
  done
  (( ${#wanted[@]} )) || die "nothing to do"

  local tag images=()
  tag=$(make_tag)
  log "tag: ${tag}"

  # Build everything before touching the cluster: a compile error should leave
  # the running shop exactly as it was, not half rolled out.
  for s in "${wanted[@]}"; do
    log "building aquashop/${s}:${tag}"
    docker build -t "aquashop/${s}:${tag}" "${ROOT}/services/${s}"
    images+=("aquashop/${s}:${tag}")
  done

  log "importing into k3d (no registry)"
  k3d image import -c "$CLUSTER" "${images[@]}"

  local failed=()
  for s in "${wanted[@]}"; do
    log "rolling out ${s}"
    kubectl -n "$NS" set image "deployment/${s}" "${s}=aquashop/${s}:${tag}"
    if ! kubectl -n "$NS" rollout status "deployment/${s}" --timeout="$(timeout_for "$s")"; then
      warn "${s} did not become ready. With maxUnavailable: 0 the previous build keeps serving (staff-portal excepted: it stops first)."
      warn "  look:      kubectl -n ${NS} describe pod -l app=${s}"
      warn "  logs:      kubectl -n ${NS} logs deploy/${s} --tail=100"
      warn "  roll back: kubectl -n ${NS} rollout undo deployment/${s}"
      failed+=("$s")
    fi
  done

  echo
  list
  if (( ${#failed[@]} )); then
    die "not ready: ${failed[*]}"
  fi
  log "done. Old pods may answer for a few more seconds; check 'kubectl -n ${NS} get pods' before verifying photos or pages."
}
main "$@"
