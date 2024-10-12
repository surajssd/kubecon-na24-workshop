#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

export POD_NAME="debugger"

info "Deleting existing ${POD_NAME} pod if it exists ..."
kubectl -n default delete pod ${POD_NAME} --ignore-not-found

NODE_NAME=$(kubectl get nodes -o name)
export NODE_NAME=${NODE_NAME#node/}

info "Creating ${POD_NAME} pod on node ${NODE_NAME} ..."
envsubst <"${SCRIPT_DIR}/node-debugger.yaml" | kubectl apply -f -

# Wait for the pod to be ready
info "Waiting for ${POD_NAME} pod to be ready ..."
kubectl -n default wait --for=condition=Ready pod/debugger --timeout=300s

SSH_PRIVATE_KEY="${SSH_KEY%.pub}"
kubectl -n default -c debugger cp $SSH_PRIVATE_KEY debugger:/host/root/.ssh/id_rsa
kubectl -n default -c debugger exec debugger -- chmod 400 /host/root/.ssh/id_rsa
kubectl -n default -c debugger exec -it debugger -- chroot /host /bin/bash
