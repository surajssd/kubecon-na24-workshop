#!/usr/bin/env bash

# Print the message in green
function info() {
    echo -e "\e[32m$1\e[0m"
}

# Print the message in red
function error() {
    echo -e "\e[31m$1\e[0m"
}

# Print the message in yellow
function warn() {
    echo -e "\e[33m$1\e[0m"
}

function generate_ssh_key() {
    local SSH_KEY="${1}"
    # if the key already exists then skip
    if [ -f "${SSH_KEY}" ]; then
        info "SSH key: '${SSH_KEY}' already exists, skipping..."
        return
    fi

    info "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY%.pub}" -N "" -C "SSH key for CAA AKS cluster"
}

function generate_unique_rg_name() {
    local AZURE_RG_FILE="${1}"
    # if the file already exists then skip
    if [ -f "${AZURE_RG_FILE}" ]; then
        warn "Resource Group file: '${AZURE_RG_FILE}' already exists, skipping..."
        return
    fi

    # This has to be unique in the subscription, 1-90 chars, underscores,
    # hyphens, periods, parentheses, and letters or digits.
    local RG_NAME_PREFIX="rg"
    local AZURE_USER=$(az account show --query user.name -o tsv)

    # If the user is not logged in $AZURE_USER is empty
    # And for some reason the env var $USER is empty then use $RANDOM
    if [ -z "${AZURE_USER}" ] && [ -z "${USER}" ]; then
        RG_USERNAME=$RANDOM$RANDOM
    else
        RG_USERNAME="${AZURE_USER:-$USER}"
    fi
    local USER_HASH=$(echo -n "${RG_USERNAME}" | sha256sum | cut -c1-6)
    local TIMESTAMP=$(date +%s)

    echo "${RG_NAME_PREFIX}-${USER_HASH}-${TIMESTAMP}" | tee "${AZURE_RG_FILE}"
}

function generate_unique_acr_name() {
    local AZURE_ACR_FILE="${1}"
    # if the file already exists then skip
    if [ -f "${AZURE_ACR_FILE}" ]; then
        warn "ACR file: '${AZURE_ACR_FILE}' already exists, skipping..."
        return
    fi

    # This has to unique globally and 5-50 alphanumeric characters, lowercase
    # only.
    local ACR_NAME_PREFIX="acr"
    local AZURE_USER=$(az account show --query user.name -o tsv)

    # If the user is not logged in $AZURE_USER is empty
    # And for some reason the env var $USER is empty then use $RANDOM
    if [ -z "${AZURE_USER}" ] && [ -z "${USER}" ]; then
        ACR_USERNAME=$RANDOM$RANDOM
    else
        ACR_USERNAME="${AZURE_USER:-$USER}"
    fi
    local USER_HASH=$(echo -n "${ACR_USERNAME}" | sha256sum | cut -c1-6)
    local TIMESTAMP=$(date +%s)

    echo "${ACR_NAME_PREFIX}${USER_HASH}${TIMESTAMP}" | tee "${AZURE_ACR_FILE}"
}
