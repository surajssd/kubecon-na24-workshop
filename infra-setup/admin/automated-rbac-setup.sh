#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
  set -x
fi

# Compulsory env vars
: "${ADMIN_RESOURCE_GROUP:?Environment variable must be set}"
: "${ADMIN_RG_REGION:?Environment variable must be set}"
: "${AZURE_SUBSCRIPTION_ID:?Environment variable must be set}"

: "${EVENT_GRID_SYSTEM_TOPIC_NAME:?Environment variable must be set}"
: "${EVENT_GRID_TOPIC_TYPE:?Environment variable must be set}"
: "${EVENT_GRID_EVENT_SUBSCRIPTION_NAME:?Environment variable must be set}"

: "${LOGIC_APP_NAME:?Environment variable must be set}"
: "${LOGIC_APP_RBAC_ROLE:?Environment variable must be set}"
: "${LOGIC_APP_INIT_DEFINITION:?Environment variable must be set}"
: "${LOGIC_APP_FULL_DEFINITION:?Environment variable must be set}"

info "Creating ${ADMIN_RESOURCE_GROUP} resource group..."
az group create \
  --name "${ADMIN_RESOURCE_GROUP}" \
  --location "${ADMIN_RG_REGION}"

# Create a system topic in Event Grid
info "Creating a system topic ${EVENT_GRID_SYSTEM_TOPIC_NAME} in Azure Event Grid for subscription ${AZURE_SUBSCRIPTION_ID}..."
az eventgrid system-topic create \
  --name "${EVENT_GRID_SYSTEM_TOPIC_NAME}" \
  --resource-group "${ADMIN_RESOURCE_GROUP}" \
  --location "Global" \
  --source "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
  --topic-type "${EVENT_GRID_TOPIC_TYPE}"

# Create a Logic App workflow definition
info "Creating Logic App workflow definition..."
az logic workflow create \
  --definition "${LOGIC_APP_INIT_DEFINITION}" \
  --name "${LOGIC_APP_NAME}" \
  --resource-group "${ADMIN_RESOURCE_GROUP}" \
  --mi-system-assigned true

# Get the Logic App’s system-assigned managed identity
info "Fetching the managed identity of the Logic App..."
LOGIC_APP_IDENTITY=$(az logic workflow show \
  --name "${LOGIC_APP_NAME}" \
  --resource-group "${ADMIN_RESOURCE_GROUP}" \
  --query identity.principalId -o tsv)
export LOGIC_APP_IDENTITY

# Get the Logic App's callback URL
info "Fetching the callback URL of the Logic App..."
ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv)
CALLBACK_URL=$(curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${ADMIN_RESOURCE_GROUP}/providers/Microsoft.Logic/workflows/${LOGIC_APP_NAME}/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2016-06-01" | jq -r '.value')

# Create an event subscription for the Logic App
info "Creating an event subscription for the Logic App..."
az eventgrid system-topic event-subscription create \
  --name "${EVENT_GRID_EVENT_SUBSCRIPTION_NAME}" \
  --resource-group "${ADMIN_RESOURCE_GROUP}" \
  --system-topic-name "${EVENT_GRID_SYSTEM_TOPIC_NAME}" \
  --endpoint-type webhook \
  --endpoint "${CALLBACK_URL}" \
  --included-event-types "Microsoft.Resources.ResourceWriteSuccess" \
  --advanced-filter data.operationName stringIn 'Microsoft.Resources/subscriptions/resourceGroups/write'

info "Event Grid System Topic setup completed successfully."

# Assign the Logic App’s managed identity RBAC permissions at the subscription level
LOGIC_APP_RBAC_SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}"
info "Assigning ${LOGIC_APP_RBAC_ROLE} role to the Logic App's managed identity over subscription ${AZURE_SUBSCRIPTION_ID}..."
az role assignment create \
  --assignee "${LOGIC_APP_IDENTITY}" \
  --role "${LOGIC_APP_RBAC_ROLE}" \
  --scope "${LOGIC_APP_RBAC_SCOPE}"

# Update the Logic App workflow definition
info "Updating Logic App workflow definition..."

TMP_FILE=$(mktemp)
envsubst '$LOGIC_APP_IDENTITY' <$LOGIC_APP_FULL_DEFINITION >$TMP_FILE

az logic workflow update \
  --definition $TMP_FILE \
  --name "${LOGIC_APP_NAME}" \
  --resource-group "${ADMIN_RESOURCE_GROUP}"

rm $TMP_FILE

info "Logic App workflow updated successfully."
