#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
  set -x
fi

# Compulsory env vars
: "${IAM_GROUP_NAME:?Environment variable must be set}"
: "${IAM_GROUP_MAIL_NICKNAME:?Environment variable must be set}"
: "${AZURE_SUBSCRIPTION_ID:?Environment variable must be set}"
: "${ATTENDEES_ROLE_NAME:?Environment variable must be set}"
: "${NUMBER_OF_AUTO_GEN_USERS:?Environment variable must be set}"

SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}"

# Check if the role exists
if ! az role definition list --name "${ATTENDEES_ROLE_NAME}" --query [0].id --output tsv >/dev/null 2>&1; then
  info "Creating role ${ATTENDEES_ROLE_NAME}..."
  az role definition create \
    --role-definition "$(envsubst <${SCRIPT_DIR}/role.json)"
fi

az role definition update \
  --role-definition "$(envsubst <${SCRIPT_DIR}/role.json)"

# Check if the group exists
if ! az ad group show --group "${IAM_GROUP_NAME}" --query id --output tsv >/dev/null 2>&1; then
  info "Creating group ${IAM_GROUP_NAME}..."
  GROUP_ID=$(az ad group create \
    --display-name "${IAM_GROUP_NAME}" \
    --mail-nickname "$IAM_GROUP_MAIL_NICKNAME" \
    --query id --output tsv)
  info "Group created with ID: ${GROUP_ID}"
else
  GROUP_ID=$(az ad group show --group "${IAM_GROUP_NAME}" --query id --output tsv 2>/dev/null)
  warn "Group already exists with ID: ${GROUP_ID}"
fi

# Assign role to the group
info "Assigning role ${ATTENDEES_ROLE_NAME} to group ${IAM_GROUP_NAME} at scope ${SCOPE}..."

MAX_RETRIES=20
for i in $(seq 1 $MAX_RETRIES); do
  if az role assignment create \
    --assignee-object-id "${GROUP_ID}" \
    --assignee-principal-type Group \
    --role "${ATTENDEES_ROLE_NAME}" \
    --scope "${SCOPE}"; then
    break
  fi
  info "Retrying the role assignment in $((2 ** (i - 1))) seconds..."
  sleep $((2 ** (i - 1)))
done

info "Role assignment successful."

# if the env var NUMBER_OF_AUTO_GEN_USERS has value more than 0
# then create the users and assign them to the group
if [ "${NUMBER_OF_AUTO_GEN_USERS}" -gt 0 ]; then
  ACCOUNT_DOMAIN_NAME=$(az account show \
    --subscription "${AZURE_SUBSCRIPTION_ID}" \
    --query tenantDefaultDomain -o tsv)

  ACCESS_TOKEN=$(az account get-access-token \
    --resource=https://graph.microsoft.com \
    --query accessToken -o tsv)
else
  warn "NUMBER_OF_AUTO_GEN_USERS is set to 0. Skipping user creation."
fi

for ((i = 1; i <= NUMBER_OF_AUTO_GEN_USERS; i++)); do
  USER_PRINCIPAL_NAME="user$i@${ACCOUNT_DOMAIN_NAME}"
  USER_PASSWORD=$(tr </dev/urandom -dc 'A-Za-z0-9!@#$%&*_-' | head -c12 || true) # Generate a random password

  info "Creating user ${USER_PRINCIPAL_NAME} with password ${USER_PASSWORD}"

  # If a user exists with the same user principal name, skip the user creation
  if ! az ad user show --id "${USER_PRINCIPAL_NAME}" --query id -o tsv >/dev/null 2>&1; then
    az ad user create \
      --display-name "user $i" \
      --password "${USER_PASSWORD}" \
      --user-principal-name "${USER_PRINCIPAL_NAME}"
  else
    warn "User ${USER_PRINCIPAL_NAME} already exists. Updating the password..."
    az ad user update \
      --id "${USER_PRINCIPAL_NAME}" \
      --password "${USER_PASSWORD}"
  fi

  # Add user to the group
  USER_PRINCIPAL_ID=$(az ad user show --id "${USER_PRINCIPAL_NAME}" --query id -o tsv)

  # Check if the output of this command is true / false
  IS_USER_PART_OF_GROUP=$(az ad group member check \
    --group "${IAM_GROUP_NAME}" \
    --member-id "${USER_PRINCIPAL_ID}" \
    --query value -o tsv)
  if [ "${IS_USER_PART_OF_GROUP}" = "true" ]; then
    warn "${USER_PRINCIPAL_NAME} is already a member of ${IAM_GROUP_NAME}"
  else
    info "Adding ${USER_PRINCIPAL_NAME} to group ${IAM_GROUP_NAME}"
    az ad group member add \
      --group "${IAM_GROUP_NAME}" \
      --member-id "${USER_PRINCIPAL_ID}"
  fi

  # Assign Directory Reader role to the user
  # TODO: May hit this issue on the actual subscription because of the admin permissiosn we have.
  info "Assigning Directory Reader role to ${USER_PRINCIPAL_NAME}"
  ERROR_RESPONSE=$(curl -s -X POST "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" -H "Authorization : Bearer ${ACCESS_TOKEN}" -H "Content-Type: application/json" -d '{
    "principalId": "'${USER_PRINCIPAL_ID}'",
    "@odata.type": "#microsoft.graph.unifiedRoleAssignment",
    "roleDefinitionId": "88d8e3e3-8f55-4a1e-953a-9b9898b8876b",
    "directoryScopeId": "/"
  }' | jq -r '.error.message')

  # Ignore if the ERROR_RESPONSE is empty or ERROR_RESPONSE contains
  if [ -n "${ERROR_RESPONSE}" ] && [[ ! "${ERROR_RESPONSE}" =~ "null" ]] && [[ ! "${ERROR_RESPONSE}" =~ "A conflicting object with one or more of the specified property values is present in the directory" ]]; then
    error "Error assigning Directory Reader role to ${USER_PRINCIPAL_NAME}: ${ERROR_RESPONSE}"
  fi
done
