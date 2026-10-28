#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/drive-mount.conf"
FAILED=0

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERROR: Cannot read configuration: $CONFIG_FILE"
    exit 1
fi

while IFS='|' read -r UUID MOUNT_POINT FILESYSTEM_TYPE; do
    # Skip blank lines and comments.
    [[ -z "${UUID//[[:space:]]/}" ]] && continue
    [[ "$UUID" =~ ^[[:space:]]*# ]] && continue

    # Remove surrounding whitespace from each field.
    UUID="${UUID//[[:space:]]/}"
    MOUNT_POINT="${MOUNT_POINT#"${MOUNT_POINT%%[![:space:]]*}"}"
    MOUNT_POINT="${MOUNT_POINT%"${MOUNT_POINT##*[![:space:]]}"}"
    FILESYSTEM_TYPE="${FILESYSTEM_TYPE//[[:space:]]/}"

    if [[ -z "$UUID" || -z "$MOUNT_POINT" || -z "$FILESYSTEM_TYPE" ]]; then
        echo "ERROR: Invalid configuration line for UUID '$UUID'"
        FAILED=1
        continue
    fi

    echo "Checking $UUID at $MOUNT_POINT..."

    # Do not mount over an existing mount.
    if mountpoint -q -- "$MOUNT_POINT"; then
        echo "Already mounted: $MOUNT_POINT"
        continue
    fi

    DEVICE="/dev/disk/by-uuid/$UUID"

    if [[ ! -e "$DEVICE" ]]; then
        echo "ERROR: Drive UUID $UUID is unavailable"
        FAILED=1
        continue
    fi

    if ! mkdir -p -- "$MOUNT_POINT"; then
        echo "ERROR: Could not create $MOUNT_POINT"
        FAILED=1
        continue
    fi

    if mount -t "$FILESYSTEM_TYPE" "UUID=$UUID" "$MOUNT_POINT"; then
        echo "Successfully mounted $UUID at $MOUNT_POINT"
    else
        echo "ERROR: Failed to mount $UUID at $MOUNT_POINT"
        FAILED=1
    fi

done < "$CONFIG_FILE"

if (( FAILED )); then
    echo "Completed with one or more errors."
    exit 1
fi

echo "All configured drives are mounted."
