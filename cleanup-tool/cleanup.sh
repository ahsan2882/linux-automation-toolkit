#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------- Configuration --------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/cleanup.conf"

DRY_RUN=true

# -------------------- Argument Parsing --------------------

usage() {
    cat <<EOF
Usage: $0 [--dry-run | --execute] [--config FILE]

Options:
  --dry-run    Show files that would be deleted (default)
  --execute    Delete eligible files
  --config     Specify an alternative configuration file
  --help       Show this help message
EOF
}

while (($#)); do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --execute)
            DRY_RUN=false
            shift
            ;;
        --config)
            if (($# < 2)); then
                echo "ERROR: --config requires a file path." >&2
                exit 2
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# -------------------- Validation --------------------

if [[ ! -f "$CONFIG_FILE" || ! -r "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found or unreadable: $CONFIG_FILE" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Mode: DRY RUN — no files will be deleted."
else
    echo "Mode: EXECUTE — eligible files will be deleted."
fi

echo "Configuration: $CONFIG_FILE"
echo

# -------------------- Cleanup --------------------

total_found=0
total_deleted=0
total_failed=0

while IFS='|' read -r days path || [[ -n "${days:-}${path:-}" ]]; do
    # Skip blank lines and comments.
    [[ -z "${days//[[:space:]]/}" ]] && continue
    [[ "$days" =~ ^[[:space:]]*# ]] && continue

    # Remove surrounding whitespace.
    days="${days//[[:space:]]/}"
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"

    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ -z "$path" ]]; then
        echo "WARNING: Invalid configuration entry: $days|$path" >&2
        total_failed=$((total_failed + 1))
        continue
    fi

    if [[ ! -d "$path" ]]; then
        echo "WARNING: Directory does not exist: $path"
        continue
    fi

    echo "Scanning: $path (older than $days days)"

    # find does not follow symbolic links by default.
    while IFS= read -r -d '' file; do
        total_found=$((total_found + 1))

        if [[ "$DRY_RUN" == true ]]; then
            printf 'WOULD DELETE: %s\n' "$file"
            continue
        fi

        if rm -- "$file"; then
            printf 'DELETED: %s\n' "$file"
            total_deleted=$((total_deleted + 1))
        else
            printf 'FAILED: %s\n' "$file" >&2
            total_failed=$((total_failed + 1))
        fi
    done < <(
        find "$path" -type f -mtime "+$days" -print0
    )

    echo
done < "$CONFIG_FILE"

# -------------------- Summary --------------------

echo "-------------------- Summary --------------------"
echo "Files found:   $total_found"

if [[ "$DRY_RUN" == true ]]; then
    echo "Files deleted: 0 (dry-run mode)"
else
    echo "Files deleted: $total_deleted"
fi

echo "Failures:      $total_failed"
