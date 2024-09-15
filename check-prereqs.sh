#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Check from an array of cli if they are installed if not print an error
function check_cli() {
    local CLIS=("$@")
    for CLI in "${CLIS[@]}"; do
        if ! command -v "${CLI}" &>/dev/null; then
            error "The CLI '${CLI}' is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Check if the required CLIs are installed
check_cli "curl" "python3" "az" "kustomize" "kubectl" "git"
