#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------- Validation --------------------

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <archive.tar.gz> <destination-directory>" >&2
    exit 1
fi

ARCHIVE="$1"
DESTINATION="$2"

if [[ ! -f "$ARCHIVE" || ! -r "$ARCHIVE" ]]; then
    echo "Error: Archive does not exist or is not readable: $ARCHIVE" >&2
    exit 1
fi

if ! tar -tzf "$ARCHIVE" > /dev/null; then
    echo "Error: Invalid or corrupted tar.gz archive: $ARCHIVE" >&2
    exit 1
fi

# -------------------- Extraction --------------------

mkdir -p -- "$DESTINATION"

echo "Archive:     $ARCHIVE"
echo "Destination: $DESTINATION"
echo

tar --extract \
    --gzip \
    --file="$ARCHIVE" \
    --directory="$DESTINATION" \
    --verbose \
    --no-same-owner \
    --no-same-permissions

echo
echo "Extraction completed successfully."
