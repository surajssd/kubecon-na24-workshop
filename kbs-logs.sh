#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

kubectl logs -n coco-tenant -f $(kubectl get pods -n coco-tenant -l app=kbs -o jsonpath='{.items[0].metadata.name}')
