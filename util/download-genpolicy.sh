#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utility.sh"

export KATA_RELEASE_VERSION="3.9.0"

pushd $(mktemp -d)
info "Downloading the kata-containers release ..."
curl -sLO "https://github.com/kata-containers/kata-containers/releases/download/${KATA_RELEASE_VERSION}/kata-static-${KATA_RELEASE_VERSION}-amd64.tar.xz"
warn "Extracting the genpolicy from the tar, this may take a while ..."
tar -xJf "kata-static-${KATA_RELEASE_VERSION}-amd64.tar.xz" ./opt/kata/bin/genpolicy

info "genpolicy tool downloaded in $(pwd)/opt/kata/bin/genpolicy"
warn "To use the tool from anywhere, either copy it into your PATH or run:"
warn "export PATH=\$PATH:$(pwd)/opt/kata/bin/genpolicy"

popd
