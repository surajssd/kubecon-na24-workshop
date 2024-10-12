#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# TODO: Create a user specific RBAC

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${AZURE_RESOURCE_GROUP:?Environment variable must be set}"
: "${AZURE_REGION:?Environment variable must be set}"
: "${AZURE_WORKLOAD_IDENTITY_NAME:?Environment variable must be set}"
: "${CLUSTER_NAME:?Environment variable must be set}"
: "${AKS_WORKER_NODE_SIZE:?Environment variable must be set}"
: "${AKS_WORKER_USER_NAME:?Environment variable must be set}"
: "${ARTIFACTS_DIR:?Environment variable must be set}"
: "${SSH_KEY:?Environment variable must be set}"

# If SSH_KEY is not set, generate a new SSH key
if [ -n "${SSH_KEY:-}" ]; then
    generate_ssh_key "${SSH_KEY}"
fi

# Check if the user has logged in, if not then trigger a login
if ! az account show >/dev/null 2>&1; then
    az config set core.login_experience_v2=off
    az login --use-device-code
fi

# Static env vars
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
AKS_RG="${AZURE_RESOURCE_GROUP}-aks"

info "Creating Resource Group ${AZURE_RESOURCE_GROUP} in region ${AZURE_REGION} ..."
az group create --name "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

info "Creating Azure Container Registry: ${AZURE_ACR_NAME} ..."
az acr create \
    --name "${AZURE_ACR_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --sku Standard

az acr update --name "${AZURE_ACR_NAME}" \
    --anonymous-pull-enabled true

info "Logging into Azure Container Registry: ${AZURE_ACR_NAME} ..."
az acr login --name "${AZURE_ACR_NAME}"

# Create AKS only if it does not exists
if ! az aks show --resource-group "${AZURE_RESOURCE_GROUP}" --name "${CLUSTER_NAME}" >/dev/null 2>&1; then
    info "Creating AKS cluster: ${CLUSTER_NAME} ..."
    az aks create \
        --resource-group "${AZURE_RESOURCE_GROUP}" \
        --node-resource-group "${AKS_RG}" \
        --name "${CLUSTER_NAME}" \
        --location "${AZURE_REGION}" \
        --node-count 1 \
        --nodepool-labels node.kubernetes.io/worker= \
        --node-vm-size "${AKS_WORKER_NODE_SIZE}" \
        --ssh-key-value "${SSH_KEY}" \
        --admin-username "${AKS_WORKER_USER_NAME}" \
        --enable-addons http_application_routing \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --os-sku Ubuntu
fi

# TODO: Maybe we should not override the credentials
info "Getting AKS credentials ..."
az aks get-credentials \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --overwrite-existing

info "Creating Azure Identity: ${AZURE_WORKLOAD_IDENTITY_NAME} ..."
az identity create \
    --name "${AZURE_WORKLOAD_IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

AKS_OIDC_ISSUER="$(az aks show \
    --name "$CLUSTER_NAME" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query "oidcIssuerProfile.issuerUrl" \
    -otsv)"

az identity federated-credential create \
    --name caa-fedcred \
    --identity-name $AZURE_WORKLOAD_IDENTITY_NAME \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --issuer "${AKS_OIDC_ISSUER}" \
    --subject system:serviceaccount:confidential-containers-system:cloud-api-adaptor \
    --audience api://AzureADTokenExchange

USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_WORKLOAD_IDENTITY_NAME}" \
    --query 'clientId' \
    -otsv)"

MAX_RETRIES=20
for i in $(seq 1 $MAX_RETRIES); do
    if az ad sp show \
        --id "${USER_ASSIGNED_CLIENT_ID}" >/dev/null 2>&1; then
        break
    fi
    info "Waiting for service principal to be created for $((2 ** (i - 1))) seconds..."
    sleep $((2 ** (i - 1)))
done

az role assignment create \
    --role 'Virtual Machine Contributor' \
    --assignee "$USER_ASSIGNED_CLIENT_ID" \
    --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${AZURE_RESOURCE_GROUP}"

az role assignment create \
    --role 'Reader' \
    --assignee "$USER_ASSIGNED_CLIENT_ID" \
    --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${AZURE_RESOURCE_GROUP}"

az role assignment create \
    --role 'Network Contributor' \
    --assignee "$USER_ASSIGNED_CLIENT_ID" \
    --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${AKS_RG}"
