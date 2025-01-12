#!/bin/bash

# This script is used to add modules to kernel with 'git subtree' command.
#
# Usage example:
#	./fetch_modules.sh -m default.xml
#
# This script is specified to use manifest.xml from https://gitlab.hentaios.com/hentaios-gs-6.x/manifest.git.

# Ensure the script stops on errors
set -e

# Define the usage function
usage() {
    echo "Usage: $0 -m <manifest_file>"
    echo "  -m <manifest_file>   Path to the input manifest XML file"
    exit 1
}

# Parse command-line arguments
while getopts ":m:" opt; do
    case "${opt}" in
        m) manifest_file=${OPTARG} ;;
        *) usage ;;
    esac
done

# Ensure the manifest file is provided
if [[ -z "${manifest_file}" ]]; then
    usage
fi

# Check if the manifest file exists
if [[ ! -f "${manifest_file}" ]]; then
    echo "Error: File '${manifest_file}' not found."
    exit 1
fi

# Extract the default revision
default_revision=$(grep -oP '<default.*revision="\K[^"]+' "${manifest_file}")
if [[ -z "${default_revision}" ]]; then
    echo "Error: Default revision not found in the manifest."
    exit 1
fi

# Define the default revision for helluva remote
helluva_revision="refs/heads/Vallhound"

echo "Default revision: ${default_revision}"
echo "Helluva revision: ${helluva_revision}"

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not inside a git repository."
    exit 1
fi

# Define the list of desired modules
modules=(
    "soc/gs"
    "amplifiers"
    "aoc_whi"
    "aoc_ipc"
    "bluetooth/broadcom"
    "bms"
    "display/samsung"
    "display/common"
    "edgetpu/abrolhos"
    "fingerprint/fpc"
    "gps/broadcom/bcm47765"
    "gpu"
    "lwis"
    "power/reset"
    "power/mitigation"
    "sensors/hall_sensor"
    "radio/samsung/s5300"
    "touch/common"
    "touch/fts"
    "trusty"
    "uwb/qorvo/dw3000"
    "video/gchips_whi"
    "nfc"
    "wlan/bcm4389"
)

# Extract and process project details
while IFS= read -r line; do
    if [[ "${line}" == *"<project "* ]]; then
        # Extract attributes
        path=$(echo "${line}" | grep -oP 'path="\K[^"]+')
        name=$(echo "${line}" | grep -oP 'name="\K[^"]+')
        remote=$(echo "${line}" | grep -oP 'remote="\K[^"]+' || echo "aosp")
        revision=$(echo "${line}" | grep -oP 'revision="\K[^"]+' || true)

        # Use the appropriate revision based on the remote
        if [[ "${remote}" == "helluva" ]]; then
            revision="${helluva_revision}"
        elif [[ -z "${revision}" ]]; then
            revision="${default_revision}"
        fi

	# Check if the module is in the list
	if [[ ! "${modules[@]}" =~ "$(echo "${path}" | sed 's|^private/google-modules/||')" ]]; then
		continue
	fi

        # Determine the base URL based on the remote
        case "${remote}" in
            helluva)
                base_url="https://gitlab.hentaios.com/hentaios-gs-6.x"
                ;;
            aosp)
                base_url="https://android.googlesource.com"
                ;;
            *)
                echo "Error: Unknown remote '${remote}' for project ${name}. Skipping."
                continue
                ;;
        esac

        # Construct the repository URL
        repo_url="${base_url}/${name}"

	# Modify path to google-modules
	new_path=$(echo "${path}" | sed 's|^private/google-modules/|google-modules/|')

        # Add the subtree
        echo "Adding subtree for ${name} into ${new_path} from ${repo_url} (revision: ${revision})..."
        if [[ ! -d "${new_path}" ]]; then
            git subtree add --prefix="${new_path}" --squash "${repo_url}" "${revision}" || {
                echo "Error: Failed to add subtree for ${new_name} from ${repo_url}. Skipping."
                continue
            }
        else
            echo "Directory ${new_path} already exists. Skipping subtree addition."
        fi
    fi
done < <(grep "<project " "${manifest_file}")

echo "All specified modules have been processed."
