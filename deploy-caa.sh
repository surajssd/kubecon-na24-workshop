#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${AZURE_RESOURCE_GROUP}:?"
: "${KBS_URL}:?"

ARTIFACTS_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)/artifacts"

SSH_KEY="${SSH_KEY:-${ARTIFACTS_DIR}/ssh.pub}"
AZURE_REGION=${AZURE_REGION:-northeurope}
CLUSTER_NAME="${CLUSTER_NAME:-caa-aks}"

CAA_IMAGE="${CAA_IMAGE:-quay.io/confidential-containers/cloud-api-adaptor}"
CAA_VERSION="${CAA_VERSION:-0.9.0}"
CAA_TAG="${CAA_TAG:-v0.9.0-amd64}"
COCO_OPERATOR_VERSION="${COCO_OPERATOR_VERSION:-0.9.0}"

CAA_CODE="${ARTIFACTS_DIR}/cloud-api-adaptor-${CAA_VERSION}"

AZURE_INSTANCE_SIZE="Standard_DC2as_v5"
DISABLECVM="false"

AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
AKS_RG="${AZURE_RESOURCE_GROUP}-aks"

AZURE_IMAGE_ID="/CommunityGalleries/cocopodvm-d0e4f35f-5530-4b9c-8596-112487cdea85/Images/podvm_image0/Versions/${CAA_VERSION}"
AZURE_WORKLOAD_IDENTITY_NAME="caa-identity"

USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_WORKLOAD_IDENTITY_NAME}" \
    --query 'clientId' \
    -otsv)"
export USER_ASSIGNED_CLIENT_ID

AZURE_VNET_NAME=$(az network vnet list \
    --resource-group "${AKS_RG}" \
    --query "[0].name" \
    --output tsv)
export AZURE_VNET_NAME

AZURE_SUBNET_ID=$(az network vnet subnet list \
    --resource-group "${AKS_RG}" \
    --vnet-name "${AZURE_VNET_NAME}" \
    --query "[0].id" \
    --output tsv)
export AZURE_SUBNET_ID

CLUSTER_SPECIFIC_DNS_ZONE=$(az aks show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -otsv)
export CLUSTER_SPECIFIC_DNS_ZONE

# Pull the CAA code
if [ ! -d "${CAA_CODE}" ]; then
    pushd ${ARTIFACTS_DIR}
    curl -LO "https://github.com/confidential-containers/cloud-api-adaptor/archive/refs/tags/v${CAA_VERSION}.tar.gz"
    tar -xvzf "v${CAA_VERSION}.tar.gz"
    popd
fi

pushd ${CAA_CODE}/src/cloud-api-adaptor

cat <<EOF >install/overlays/azure/workload-identity.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloud-api-adaptor-daemonset
  namespace: confidential-containers-system
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-api-adaptor
  namespace: confidential-containers-system
  annotations:
    azure.workload.identity/client-id: "$USER_ASSIGNED_CLIENT_ID"
EOF

cat <<EOF >install/overlays/azure/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../yamls
images:
- name: cloud-api-adaptor
  newName: "${CAA_IMAGE}"
  newTag: "${CAA_TAG}"
generatorOptions:
  disableNameSuffixHash: true
configMapGenerator:
- name: peer-pods-cm
  namespace: confidential-containers-system
  literals:
  - CLOUD_PROVIDER="azure"
  - AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
  - AZURE_REGION="${AZURE_REGION}"
  - AZURE_INSTANCE_SIZE="${AZURE_INSTANCE_SIZE}"
  - AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
  - AZURE_SUBNET_ID="${AZURE_SUBNET_ID}"
  - AZURE_IMAGE_ID="${AZURE_IMAGE_ID}"
  - DISABLECVM="${DISABLECVM}"
  - AA_KBC_PARAMS="cc_kbc::http://${KBS_URL}"
secretGenerator:
- name: peer-pods-secret
  namespace: confidential-containers-system
- name: ssh-key-secret
  namespace: confidential-containers-system
  files:
  - id_rsa.pub
patchesStrategicMerge:
- workload-identity.yaml
EOF

cp $SSH_KEY install/overlays/azure/id_rsa.pub

# Install operator
kubectl apply -k "github.com/confidential-containers/operator/config/release?ref=v${COCO_OPERATOR_VERSION}"
kubectl apply -k "github.com/confidential-containers/operator/config/samples/ccruntime/peer-pods?ref=v${COCO_OPERATOR_VERSION}"

kubectl apply -k "install/overlays/azure"

# Wait until the runtimeclass is created
for i in {1..20}; do
    if kubectl get runtimeclass kata-remote >/dev/null 2>&1; then
        break
    fi

    info "Waiting for runtimeclass to be created..."
    sleep 6
done
