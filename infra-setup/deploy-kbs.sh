#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${ARTIFACTS_DIR:?Environment variable must be set}"
: "${KBS_VERSION:?Environment variable must be set}"
: "${KBS_IMAGE:?Environment variable must be set}"

KBS_CODE="${ARTIFACTS_DIR}/trustee-${KBS_VERSION}"

# Pull the KBS code base if it is not available
if [ ! -d "${KBS_CODE}" ]; then
    pushd ${ARTIFACTS_DIR}
    curl -LO "https://github.com/confidential-containers/trustee/archive/${KBS_VERSION}.tar.gz"
    tar -xzf "${KBS_VERSION}.tar.gz"
    popd
fi

pushd "${KBS_CODE}/kbs/config/kubernetes"

pushd base
kustomize edit set image kbs-container-image=${KBS_IMAGE}
openssl genpkey -algorithm ed25519 >kbs.key
openssl pkey -in kbs.key -pubout -out kbs.pem
popd

export DEPLOYMENT_DIR=nodeport
cat <<EOF >$DEPLOYMENT_DIR/x86_64/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: coco-tenant

resources:
- ../../base/

patches:
- path: patch.yaml
  target:
    group: ""
    kind: Service
    name: kbs
EOF

kustomize build $DEPLOYMENT_DIR/x86_64 | kubectl apply -f -
info "KBS deployed successfully!"
