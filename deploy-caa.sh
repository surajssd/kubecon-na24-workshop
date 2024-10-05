#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${ARTIFACTS_DIR:?Environment variable must be set}"
: "${AZURE_RESOURCE_GROUP:?Environment variable must be set}"
: "${AZURE_REGION:?Environment variable must be set}"
: "${CLUSTER_NAME:?Environment variable must be set}"
: "${AZURE_INSTANCE_SIZE:?Environment variable must be set}"
: "${AZURE_WORKLOAD_IDENTITY_NAME:?Environment variable must be set}"

: "${CAA_IMAGE:?Environment variable must be set}"
: "${CAA_VERSION:?Environment variable must be set}"
: "${CAA_TAG:?Environment variable must be set}"
: "${COCO_OPERATOR_VERSION:?Environment variable must be set}"
: "${AZURE_IMAGE_ID:?Environment variable must be set}"

SSH_KEY="${SSH_KEY:-${ARTIFACTS_DIR}/ssh.pub}"
CAA_CODE="${ARTIFACTS_DIR}/cloud-api-adaptor-${CAA_VERSION}"

DISABLECVM="false"
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
AKS_RG="${AZURE_RESOURCE_GROUP}-aks"

USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_WORKLOAD_IDENTITY_NAME}" \
    --query 'clientId' \
    -otsv)"

AZURE_VNET_NAME=$(az network vnet list \
    --resource-group "${AKS_RG}" \
    --query "[0].name" \
    --output tsv)

AZURE_SUBNET_ID=$(az network vnet subnet list \
    --resource-group "${AKS_RG}" \
    --vnet-name "${AZURE_VNET_NAME}" \
    --query "[0].id" \
    --output tsv)

# Pull the CAA code
if [ ! -d "${CAA_CODE}" ]; then
    info "Getting the Cloud API Adaptor release..."
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

# If the KBS service is not deployed then fail
if ! kubectl get svc kbs -n coco-tenant >/dev/null 2>&1; then
    error "KBS is not deployed. Please deploy KBS and try again."
    exit 1
fi

KBS_URL=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$(kubectl get svc kbs -n coco-tenant -o jsonpath='{.spec.ports[0].nodePort}')

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
  - ENABLE_CLOUD_PROVIDER_EXTERNAL_PLUGIN="false"
  - CLOUD_CONFIG_VERIFY="false"
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
info "Installing the Confidential Containers Operator..."
kubectl apply -k "github.com/confidential-containers/operator/config/release?ref=v${COCO_OPERATOR_VERSION}"
kubectl apply -k "github.com/confidential-containers/operator/config/samples/ccruntime/peer-pods?ref=v${COCO_OPERATOR_VERSION}"

info "Installing the Cloud API Adaptor..."
kubectl apply -k "install/overlays/azure"

# Wait until the runtimeclass is created
MAX_RETRIES=20
for i in $(seq 1 $MAX_RETRIES); do
    if kubectl get runtimeclass kata-remote >/dev/null 2>&1; then
        break
    fi

    info "Waiting for runtimeclass to be created for $((2 ** (i - 1))) seconds..."
    sleep $((2 ** (i - 1)))
done

# Wait until the pod created by cloud-api-adaptor-daemonset in the namespace cloud-api-adaptor-daemonset is Ready
for i in $(seq 1 $MAX_RETRIES); do
    if kubectl get pod -n confidential-containers-system -l app=cloud-api-adaptor -o jsonpath='{.items[0].status.phase}' | grep -q Running; then
        break
    fi

    info "Waiting for cloud-api-adaptor-daemonset pod to be Ready for $((2 ** (i - 1))) seconds..."
    sleep $((2 ** (i - 1)))
done
