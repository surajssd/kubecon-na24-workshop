#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

kubectl logs -n confidential-containers-system -f $(kubectl get pods -n confidential-containers-system -l app=cloud-api-adaptor -o jsonpath='{.items[0].metadata.name}')
