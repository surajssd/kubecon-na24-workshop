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
