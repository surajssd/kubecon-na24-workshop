#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

: "${ENCRYPTION_KEY_FILE:?Environment variable must be set}"
: "${ENCRYPTION_KEY_ID:?Environment variable must be set}"
: "${SOURCE_IMAGE:?Environment variable must be set}"
: "${DESTINATION_IMAGE:?Environment variable must be set}"
: "${COCO_KEY_PROVIDER:?Environment variable must be set}"

# Ensure we pull the images that are needed to perfom the encryption
docker pull "${SOURCE_IMAGE}"
docker pull "${COCO_KEY_PROVIDER}"

# If the encryption key file does not exists, then create it
if [ ! -f "${ENCRYPTION_KEY_FILE}" ]; then
    info "Encryption key file not found, creating new one: ${ENCRYPTION_KEY_FILE}"
    head -c 32 /dev/urandom | openssl enc >"$ENCRYPTION_KEY_FILE"
fi

WORK_DIR="$(mktemp -d)"
docker run -v "${WORK_DIR}:/output" "${COCO_KEY_PROVIDER}" /encrypt.sh \
    -k "$(base64 <${ENCRYPTION_KEY_FILE})" \
    -i "kbs://${ENCRYPTION_KEY_ID}" \
    -s "docker://${SOURCE_IMAGE}" \
    -d dir:/output

info "Pushing encrypted image ..."
skopeo copy "dir:${WORK_DIR}" "docker://${DESTINATION_IMAGE}"
info "Image encrypted and pushed to ${DESTINATION_IMAGE}"
