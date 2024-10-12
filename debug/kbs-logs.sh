#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

KBS_POD=$(kubectl get pods -n coco-tenant -l app=kbs -o jsonpath='{.items[0].metadata.name}')

info "Getting logs from KBS ..."
warn "Press Ctrl+C to stop the log streaming."
kubectl logs -n coco-tenant -c kbs -f "${KBS_POD}"
