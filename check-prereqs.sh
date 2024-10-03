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

            # Add instructions to install tools
            case "${CLI}" in
            "az")
                error "To install Azure CLI (az) follow instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
                ;;
            "kustomize")
                error "To install Kustomize follow instructions here: https://kubectl.docs.kubernetes.io/installation/kustomize/"
                ;;
            "kubectl")
                error "To install kubectl follow instructions here: https://kubernetes.io/docs/tasks/tools/#kubectl"
                ;;
            "skopeo")
                error "To install Skopeo follow instructions here: https://github.com/containers/skopeo/blob/main/install.md"
                ;;
            esac

            exit 1
        fi
    done
}

# Check if the required CLIs are installed
check_cli "curl" "python3" "git" "openssl" "az" "kustomize" "kubectl" "skopeo"
