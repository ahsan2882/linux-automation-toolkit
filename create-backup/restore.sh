#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/archive-validator.sh"

# -------------------- Validation --------------------

usage() {
    cat >&2 <<EOF
Usage:
  $0 [--dry-run] <archive.tar.gz> <destination-directory>

Options:
  --dry-run    Validate and list archive contents without extracting.
EOF
}

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

ARCHIVE="$1"
DESTINATION="$2"

if ! validate_archive "$ARCHIVE"; then
    echo "Error: Archive validation failed." >&2
    exit 1
fi

# -------------------- Dry Run --------------------

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: no files will be extracted."
    echo "Archive: $ARCHIVE"
    echo "Contents:"
    tar --list --gzip --file="$ARCHIVE" --verbose
    exit 0
fi

# -------------------- Confirmation --------------------

printf 'Archive:     %s\n' "$ARCHIVE"
printf 'Destination: %s\n\n' "$DESTINATION"

read -r -p "Extract this archive into the destination? [y/N] " confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo "Extraction cancelled."
    exit 0
fi

# -------------------- Extraction --------------------

mkdir -p -- "$DESTINATION"

tar \
    --extract \
    --gzip \
    --file="$ARCHIVE" \
    --directory="$DESTINATION" \
    --verbose \
    --no-same-owner \
    --no-same-permissions \
    --no-absolute-names

echo
echo "Extraction completed successfully."
