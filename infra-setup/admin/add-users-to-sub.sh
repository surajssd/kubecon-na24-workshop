#!/usr/bin/env bash
# THIS DOES NOT WORK ATM.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
  set -x
fi

: "${EMAILS_FILE:?Environment variable must be set}"
: "${GROUP_NAME:?Environment variable must be set}"
: "${AZURE_TENANT_ID:?Environment variable must be set}"

REDIRECT_URL="https://myapplications.microsoft.com/?tenantid=${AZURE_TENANT_ID}"
GROUP_ID=$(az ad group show --group "${GROUP_NAME}" --query id --output tsv 2>/dev/null)

# Process each email
while IFS= read -r EMAIL || [ -n "$EMAIL" ]; do
  EMAIL=$(echo "${EMAIL}" | xargs) # Trim whitespace
  if [ -z "${EMAIL}" ]; then
    continue # Skip empty lines
  fi

  info "Processing email: ${EMAIL}"
  if ! az ad user show --id "${EMAIL}" --query objectId --output tsv >/dev/null 2>&1; then
    info "Creating an user invitation"

    # Install using https://github.com/microsoftgraph/msgraph-cli/releases
    # If mgc does not work, more on it here: https://github.com/microsoftgraph/msgraph-cli/issues/248#issuecomment-1458188036
    # Invite the guest user
    mgc invitations create --body "{
      \"invitedUserEmailAddress\": \"${EMAIL}\",
      \"inviteRedirectUrl\": \"${REDIRECT_URL}\"
    }"
  else
    warn "User already exists!"
  fi

  USER_ID=$(az ad user show --id "$EMAIL" --query objectId --output tsv 2>/dev/null)
  # Add the user to the group
  info "Adding $EMAIL to group ${GROUP_NAME}..."
  az ad group member add --group "${GROUP_ID}" --member-id "${USER_ID}" 2>/dev/null
  info "Successfully added $EMAIL to group."
  info "---------------------------------------------"
done <"${EMAILS_FILE}"

# For now add users manually by going to here
https://portal.azure.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Members/groupId/f82623c7-8099-415b-bac4-f7ed56eeb87e/menuId/
