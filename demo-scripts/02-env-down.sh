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

echo "Taking control from skiperator for demo app in $CONTEXT"
kubectl label deployment talk-demo skiperator.kartverket.no/ignore=true -nexample --context "$CONTEXT" && \
kubectl scale deployment talk-demo --replicas=0 -nexample --context "$CONTEXT"
echo "Waiting for pods to be terminated in $CONTEXT..."
kubectl wait --for=delete pod -l app=talk-demo -n example --timeout=120s --context "$CONTEXT"
echo "All pods terminated in $CONTEXT"
