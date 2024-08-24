#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Compulsory env vars
: "${AZURE_RESOURCE_GROUP:?Environment variable must be set}"

SSH_KEY="${SSH_KEY:-artifacts/ssh.pub}"

# If SSH_KEY is not set, generate a new SSH key
if [ -n "${SSH_KEY:-}" ]; then
    generate_ssh_key "${SSH_KEY}"
fi

# Optional env vars
AZURE_REGION=${AZURE_REGION:-northeurope}
CLUSTER_NAME="${CLUSTER_NAME:-caa-aks}"
AKS_WORKER_NODE_SIZE="${AKS_WORKER_NODE_SIZE:-Standard_F4s_v2}"

# Static env vars
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
AKS_WORKER_USER_NAME="azuser"
AKS_RG="${AZURE_RESOURCE_GROUP}-aks"
AZURE_WORKLOAD_IDENTITY_NAME="caa-identity"

info "Creating Resource Group '${AZURE_RESOURCE_GROUP}' in region '${AZURE_REGION}'..."
az group create --name "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

# Create AKS only if it does not exists
if ! az aks show --resource-group "${AZURE_RESOURCE_GROUP}" --name "${CLUSTER_NAME}" >/dev/null 2>&1; then
    info "Creating AKS cluster: ${CLUSTER_NAME}..."
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
info "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --overwrite-existing

# TODO: Figure out a better way to expose the apps on AKS.
CLUSTER_SPECIFIC_DNS_ZONE=$(az aks show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -otsv)
export CLUSTER_SPECIFIC_DNS_ZONE

info "Creating Azure Identity: ${AZURE_WORKLOAD_IDENTITY_NAME}..."
az identity create \
    --name "${AZURE_WORKLOAD_IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

AKS_OIDC_ISSUER="$(az aks show \
    --name "$CLUSTER_NAME" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query "oidcIssuerProfile.issuerUrl" \
    -otsv)"
export AKS_OIDC_ISSUER

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
export USER_ASSIGNED_CLIENT_ID

for i in {1..10}; do
    if az ad sp show \
        --id "${USER_ASSIGNED_CLIENT_ID}" >/dev/null 2>&1; then
        break
    fi
    info "Waiting for service principal to be created..."
    sleep 5
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

warn "Run the following command before deploying KBS:"
warn "export CLUSTER_SPECIFIC_DNS_ZONE=${CLUSTER_SPECIFIC_DNS_ZONE}"
