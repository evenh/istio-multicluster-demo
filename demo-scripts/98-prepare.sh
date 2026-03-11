#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment talk-demo skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_EAST" && \
kubectl scale deployment talk-demo --replicas=0 -nexample --context "$CLUSTER_EAST"
echo "Waiting for deployment rollout to finish in $CLUSTER_EAST..."
wait_for_deployment_rollout "$CLUSTER_EAST" example talk-demo
echo "Deployment scaled down in $CLUSTER_EAST"


kubectl label deployment talk-demo skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_WEST" && \
kubectl scale deployment talk-demo --replicas=0 -nexample --context "$CLUSTER_WEST"
echo "Waiting for deployment rollout to finish in $CLUSTER_WEST..."
wait_for_deployment_rollout "$CLUSTER_WEST" example talk-demo
echo "Deployment scaled down in $CLUSTER_WEST"
