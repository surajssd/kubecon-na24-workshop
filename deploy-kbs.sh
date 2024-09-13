#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${KEY_FILE}:?"

ARTIFACTS_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)/artifacts"
KBS_VERSION="${KBS_VERSION:-0.9.0}"
KBS_CODE="${ARTIFACTS_DIR}/trustee-${KBS_VERSION}"

# Pull the KBS code base if it is not available
if [ ! -d "${KBS_CODE}" ]; then
    pushd ${ARTIFACTS_DIR}
    curl -LO "https://github.com/confidential-containers/trustee/archive/refs/tags/v${KBS_VERSION}.tar.gz"
    tar -xzf "v${KBS_VERSION}.tar.gz"
    popd
fi

pushd "${KBS_CODE}/kbs/config/kubernetes"

pushd base
kustomize edit set image kbs-container-image=ghcr.io/confidential-containers/staged-images/kbs:e890fc90c384207668fa3a4d6a2f2a2d652797ee
popd

pushd overlays

# Convert the KEY_FILE to an absolute path if it is not
KEY_FILE="$(realpath "${KEY_FILE}")"
cp ${KEY_FILE} key.bin

popd

export DEPLOYMENT_DIR=nodeport
./deploy-kbs.sh
