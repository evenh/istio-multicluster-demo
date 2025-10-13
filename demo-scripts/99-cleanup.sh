#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_EAST"
kubectl label deployment hello-stavanger skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_WEST"
