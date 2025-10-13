#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_EAST" && \
kubectl scale deployment hello-stavanger --replicas=0 -nexample --context "$CLUSTER_EAST"

kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore=true -nexample --context "$CLUSTER_WEST" && \
kubectl scale deployment hello-stavanger --replicas=0 -nexample --context "$CLUSTER_WEST"
