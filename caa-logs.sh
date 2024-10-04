#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

kubectl logs -n confidential-containers-system -f $(kubectl get pods -n confidential-containers-system -l app=cloud-api-adaptor -o jsonpath='{.items[0].metadata.name}')
