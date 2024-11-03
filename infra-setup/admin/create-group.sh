#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
  set -x
fi

# Compulsory env vars
: "${GROUP_NAME:?Environment variable must be set}"
: "${GROUP_MAIL_NICKNAME:?Environment variable must be set}"
: "${AZURE_SUBSCRIPTION_ID:?Environment variable must be set}"
: "${ROLE_NAME:?Environment variable must be set}"

SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}"

# Check if the group exists
if ! az ad group show --group "${GROUP_NAME}" --query id --output tsv >/dev/null 2>&1; then
  info "Creating group ${GROUP_NAME}..."
  GROUP_ID=$(az ad group create \
    --display-name "${GROUP_NAME}" \
    --mail-nickname "$GROUP_MAIL_NICKNAME" \
    --query id --output tsv)
  info "Group created with ID: ${GROUP_ID}"
else
  GROUP_ID=$(az ad group show --group "${GROUP_NAME}" --query id --output tsv 2>/dev/null)
  warn "Group already exists with ID: ${GROUP_ID}"
fi

# Assign role to the group
info "Assigning role ${ROLE_NAME} to group ${GROUP_NAME} at scope ${SCOPE}..."

MAX_RETRIES=20
for i in $(seq 1 $MAX_RETRIES); do
  if az role assignment create \
    --assignee-object-id "${GROUP_ID}" \
    --assignee-principal-type Group \
    --role "${ROLE_NAME}" \
    --scope "${SCOPE}"; then
    break
  fi
  info "Retrying the role assignment in $((2 ** (i - 1))) seconds..."
  sleep $((2 ** (i - 1)))
done

info "Role assignment successful."
