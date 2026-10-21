#!/usr/bin/env bash
set -Eeuo pipefail

export CLUSTER_EAST="do-nyc3-east"
export CLUSTER_WEST="do-sfo2-west"

KUBE_REQUEST_TIMEOUT="${KUBE_REQUEST_TIMEOUT:-5s}"
KUBE_WAIT_TIMEOUT="${KUBE_WAIT_TIMEOUT:-120s}"

die() { echo "✖ $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ctx_exists() {
  local ctx="$1"
  kubectl config get-contexts -o name 2>/dev/null | grep -Fx -- "$ctx" >/dev/null
}

probe_ctx() {
  local ctx="$1"
  # Try version first (cheap). Fallback: list a core resource.
  kubectl --context="$ctx" --request-timeout="$KUBE_REQUEST_TIMEOUT" version --short >/dev/null 2>&1 \
    || kubectl --context="$ctx" --request-timeout="$KUBE_REQUEST_TIMEOUT" get ns kube-system >/dev/null 2>&1
}

ensure_contexts() {
  require_cmd kubectl

  [[ "$CLUSTER_EAST" != "$CLUSTER_WEST" ]] \
    || die "CLUSTER_EAST and CLUSTER_WEST must differ (both are '$CLUSTER_EAST')."

  ctx_exists "$CLUSTER_EAST" || die "kubectl context not found: $CLUSTER_EAST"
  ctx_exists "$CLUSTER_WEST" || die "kubectl context not found: $CLUSTER_WEST"

  probe_ctx "$CLUSTER_EAST" || die "API unreachable for context: $CLUSTER_EAST"
  probe_ctx "$CLUSTER_WEST" || die "API unreachable for context: $CLUSTER_WEST"

  export CLUSTER_EAST CLUSTER_WEST
}

wait_for_deployment_available() {
  local ctx="$1"
  local namespace="$2"
  local name="$3"
  local timeout="${4:-$KUBE_WAIT_TIMEOUT}"

  kubectl wait \
    --for=condition=Available \
    "deployment/$name" \
    -n "$namespace" \
    --timeout="$timeout" \
    --context "$ctx"
}

wait_for_deployment_rollout() {
  local ctx="$1"
  local namespace="$2"
  local name="$3"
  local timeout="${4:-$KUBE_WAIT_TIMEOUT}"

  kubectl rollout status \
    "deployment/$name" \
    -n "$namespace" \
    --timeout="$timeout" \
    --context "$ctx"
}
