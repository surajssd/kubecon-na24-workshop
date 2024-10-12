#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# first argument to the script is the path to the key file, check if it is set
if [ -z "${1:-}" ]; then
    error "Path to key file must be set"
    info "Usage: $0 <path-to-key-file> <key-id>"
    exit 1
fi

# second argument is the key id
if [ -z "${2:-}" ]; then
    error "Key ID must be set"
    info "Usage: $0 <path-to-key-file> <key-id>"
    exit 1
fi

KEY_FILE="${1}"
KEY_ID="${2}"

# Find the KBS pod deployed in the coco-tenant namespace
KBS_POD=$(kubectl get pods -n coco-tenant -l app=kbs -o jsonpath='{.items[0].metadata.name}')

# Create the directory in the KBS repository
KEY_PATH_IN_POD="/opt/confidential-containers/kbs/repository/${KEY_ID}"
kubectl exec -n coco-tenant "${KBS_POD}" -- mkdir -p "$(dirname ${KEY_PATH_IN_POD})"
kubectl cp -n coco-tenant "${KEY_FILE}" "${KBS_POD}:${KEY_PATH_IN_POD}"

info "Key uploaded to KBS!"
