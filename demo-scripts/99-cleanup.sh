#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment talk-demo skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_EAST"
kubectl wait --for=condition=Ready pod -l app=talk-demo -nexample --timeout=120s --context "$CLUSTER_EAST"

kubectl label deployment talk-demo skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_WEST"
kubectl wait --for=condition=Ready pod -l app=talk-demo -nexample --timeout=120s --context "$CLUSTER_WEST"
