#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <east|west>"
  exit 1
fi

picked="$1"

case "$picked" in
  east)
    CONTEXT="$CLUSTER_EAST"
    ;;
  west)
    CONTEXT="$CLUSTER_WEST"
    ;;
  *)
    echo "Invalid option: $picked (must be 'east' or 'west')"
    exit 1
    ;;
esac

echo "Yielding control to skiperator for demo app in $CONTEXT"
kubectl label deployment talk-demo skiperator.kartverket.no/ignore- -nexample --context "$CONTEXT"
echo "Waiting for pods to be ready in $CONTEXT"
kubectl wait --for=condition=Ready pod -l app=talk-demo -nexample --timeout=120s --context "$CONTEXT"
echo "Pods ready, accepting traffic in $CONTEXT"
