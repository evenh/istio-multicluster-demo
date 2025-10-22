#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_EAST" && \
kubectl scale deployment hello-stavanger --replicas=0 -nexample --context "$CLUSTER_EAST"
echo "Waiting for pods to be terminated in $CLUSTER_EAST..."
kubectl wait --for=delete pod -l app=hello-stavanger -n example --timeout=120s --context "$CLUSTER_EAST"
echo "All pods terminated in $CLUSTER_EAST"


kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_WEST" && \
kubectl scale deployment hello-stavanger --replicas=0 -nexample --context "$CLUSTER_WEST"
echo "Waiting for pods to be terminated in $CLUSTER_WEST..."
kubectl wait --for=delete pod -l app=hello-stavanger -n example --timeout=120s --context "$CLUSTER_WEST"
echo "All pods terminated in $CLUSTER_WEST"
