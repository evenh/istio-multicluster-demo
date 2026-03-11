#!/usr/bin/env bash
set -Eeuo pipefail

source ../files/scripts/common.sh
ensure_contexts

kubectl label deployment talk-demo skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_EAST"
wait_for_deployment_available "$CLUSTER_EAST" example talk-demo

kubectl label deployment talk-demo skiperator.kartverket.no/ignore- -nexample --context "$CLUSTER_WEST"
wait_for_deployment_available "$CLUSTER_WEST" example talk-demo
