#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/../util/utility.sh"

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# These regions have been chosen because this is where the vm images are available.
# TODO: Replicate the image to all the regions we have quota in.
locations=("eastus" "eastus2" "northeurope" "westeurope")

# AMD SEV SNP machine types: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dcasv5-series
sizes=("Standard_DC2as_v5" "Standard_DC4as_v5" "Standard_DC8as_v5" "Standard_DC16as_v5" "Standard_DC32as_v5" "Standard_DC48as_v5" "Standard_DC64as_v5" "Standard_DC96as_v5")

# Loop through each location
for LOCATION in "${locations[@]}"; do
    # Fetch all SKUs for the location in a single call
    info "Available SKUs in ${LOCATION}:"
    available_skus=$(az vm list-skus --location "${LOCATION}" --output tsv --query '[].{Size: name}')

    # Loop through each size and check if it's available in the fetched SKUs
    for SIZE in "${sizes[@]}"; do
        if echo "$available_skus" | grep -q "${SIZE}"; then
            warn "${SIZE}"
        fi
    done

    # Print Quota for this region.
    echo ""
    info "Quota for ${LOCATION}:"
    az vm list-usage -l ${LOCATION} --query "[?name.value == 'standardDCASv5Family'].{currentvalue: currentValue, limit: limit}"
    echo ""
done
