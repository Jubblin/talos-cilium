#!/usr/bin/env bash
# Validate the versions file format

set -e

VERSIONS_FILE="versions"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: versions file not found"
    exit 1
fi

# Check if CILIUM_VERSION is present and valid
if ! grep -qE '^CILIUM_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$VERSIONS_FILE"; then
    echo "Error: Invalid or missing CILIUM_VERSION in versions file"
    echo "Expected format: CILIUM_VERSION=X.Y.Z"
    exit 1
fi

# Check if TETRAGON_VERSION is present and valid
if ! grep -qE '^TETRAGON_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$VERSIONS_FILE"; then
    echo "Error: Invalid or missing TETRAGON_VERSION in versions file"
    echo "Expected format: TETRAGON_VERSION=X.Y.Z"
    exit 1
fi

echo "✓ versions file is valid"
exit 0
