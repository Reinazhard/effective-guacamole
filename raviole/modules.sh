#!/bin/bash

# Ensure the script stops on errors
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 -f <input_file> -b <branch>"
    echo "  -f <input_file>   Path to the input XML file"
    echo "  -b <branch>       Git branch to use for subtree integration"
    exit 1
}

# Parse command-line arguments
while getopts ":f:b:" opt; do
    case "${opt}" in
        f) input_file=${OPTARG} ;;
        b) branch=${OPTARG} ;;
        *) usage ;;
    esac
done

# Ensure both arguments are provided
if [[ -z "${input_file}" || -z "${branch}" ]]; then
    usage
fi

# Check if the input file exists
if [[ ! -f "${input_file}" ]]; then
    echo "Error: File '${input_file}' not found."
    exit 1
fi

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not inside a git repository."
    exit 1
fi

# Process the input file
echo "Processing input file: ${input_file}"
echo "Using branch: ${branch}"

while IFS= read -r line; do
    if [[ "${line}" == *'project path'* ]]; then
        # Extract 'path' and 'name' using regex-like string manipulation
        original_path=$(echo "${line}" | grep -oP 'path="[^"]+"' | cut -d'"' -f2)
        name=$(echo "${line}" | grep -oP 'name="[^"]+"' | cut -d'"' -f2)

        # Modify the path to use ./google-modules/ instead of ./private/google-modules/
        adjusted_path=$(echo "${original_path}" | sed 's|^private/google-modules/|google-modules/|')

        # Display and execute git subtree command
        echo "Adding subtree for ${name} at ${adjusted_path}..."
        git subtree add --prefix="${adjusted_path}" "https://android.googlesource.com/${name}" "${branch}"
    fi
done < "${input_file}"

echo "All modules have been integrated successfully."
