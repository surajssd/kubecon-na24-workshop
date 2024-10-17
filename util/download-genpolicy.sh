#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utility.sh"

pushd $(mktemp -d)
curl -LO https://github.com/kata-containers/kata-containers/releases/download/3.9.0/kata-static-3.9.0-amd64.tar.xz
tar -xJf kata-static-3.9.0-amd64.tar.xz ./opt/kata/bin/genpolicy

info "Tool downloaded in $(pwd)/opt/kata/bin/genpolicy"

popd
