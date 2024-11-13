#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../../util/utility.sh"

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
info "Pulling source image: ${SOURCE_IMAGE} ..."
docker pull --platform linux/amd64 "${SOURCE_IMAGE}"

info "Pulling container image encryptor application: ${COCO_KEY_PROVIDER} ..."
docker pull --platform linux/amd64 "${COCO_KEY_PROVIDER}"

# If the encryption key file does not exists, then create it
if [ ! -f "${ENCRYPTION_KEY_FILE}" ]; then
    info "Encryption key file not found, creating new one: ${ENCRYPTION_KEY_FILE}"
    head -c 32 /dev/urandom | openssl enc >"$ENCRYPTION_KEY_FILE"
fi

info "Running the container image encryptor application: ${COCO_KEY_PROVIDER}"
CONTAINER_NAME="coco-key-provider"
docker rm -f "${CONTAINER_NAME}" || true
docker run --rm -d --name "${CONTAINER_NAME}" "${COCO_KEY_PROVIDER}" sleep infinity

info "Ensuring container image encryptor application can push to the container registry"
docker exec -it "${CONTAINER_NAME}" mkdir -p /root/.docker
docker cp $HOME/.docker/config.json "${CONTAINER_NAME}":/root/.docker/config.json

info "Encrypting image ${SOURCE_IMAGE} using key ${ENCRYPTION_KEY_FILE} and pushing encrypted image ${DESTINATION_IMAGE} ..."
docker exec -it "${CONTAINER_NAME}" /encrypt.sh \
    -k "$(base64 <${ENCRYPTION_KEY_FILE})" \
    -i "kbs:///${ENCRYPTION_KEY_ID}" \
    -s "docker://${SOURCE_IMAGE}" \
    -d "docker://${DESTINATION_IMAGE}"

docker stop "${CONTAINER_NAME}"
info "Image encrypted and pushed to container registry successfully!"
