#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------- Configuration --------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/cleanup.conf"

DRY_RUN=true

# Exact paths that must never be cleanup targets.
PROTECTED_PATHS=(
    /
    /home
    /root
    /etc
    /usr
    /bin
    /sbin
    /lib
    /lib64
    /boot
    /dev
    /proc
    /sys
    /run
    /var
)


# -------------------- Argument Parsing --------------------

usage() {
    cat <<EOF
Usage: $0 [--dry-run | --execute] [--config FILE]

Options:
  --dry-run    Show files that would be deleted (default)
  --execute    Delete eligible files
  --config     Specify an alternative configuration file
  --help, -h       Show this help message
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
            if (($# < 2)) || [[ -z "$2" ]]; then
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

# Resolve the configuration file path.
CONFIG_FILE="$(realpath -e -- "$CONFIG_FILE")"

# -------------------- Path Validation --------------------

is_protected_path() {
    local target="$1"
    local protected

    for protected in "${PROTECTED_PATHS[@]}"; do
        if [[ "$target" == "$protected" ]]; then
            return 0
        fi
    done

    return 1
}


# -------------------- Execution Mode --------------------

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

while IFS= read -r line || [[ -n "$line" ]]; do

    # Skip blank lines and comments.
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse configuration: days|path
    days=""
    path=""
    extra=""

    IFS='|' read -r days path extra <<< "$line"

    # Trim surrounding whitespace.
    days="${days//[[:space:]]/}"
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"

    if [[ ! "$days" =~ ^[0-9]+$ ]] ||
       [[ -z "$path" ]] ||
       [[ -n "$extra" ]]; then
        echo "WARNING: Invalid configuration entry: $line" >&2
        ((total_failed += 1))
        continue
    fi

    # Require an existing directory and reject symlink targets.
    if [[ ! -d "$path" || -L "$path" ]]; then
        echo "WARNING: Directory missing or is a symbolic link: $path" >&2
        ((total_failed += 1))
        continue
    fi

    # Canonicalize before checking protected paths.
    canonical_path="$(realpath -e -- "$path")"

    if is_protected_path "$canonical_path"; then
        echo "ERROR: Protected directory rejected: $canonical_path" >&2
        ((total_failed += 1))
        continue
    fi

    # Reject filesystem roots that resolve to protected directories.
    if [[ "$canonical_path" == "/" ]]; then
        echo "ERROR: Filesystem root cannot be cleaned." >&2
        ((total_failed += 1))
        continue
    fi

    echo "Scanning: $canonical_path (older than $days days)"

    # Do not traverse into other mounted filesystems.
    while IFS= read -r -d '' file; do
        ((total_found += 1))

        if [[ "$DRY_RUN" == true ]]; then
            printf 'WOULD DELETE: %s\n' "$file"
            continue
        fi

        if rm -- "$file"; then
            printf 'DELETED: %s\n' "$file"
            ((total_deleted += 1))
        else
            printf 'FAILED: %s\n' "$file" >&2
            ((total_failed += 1))
        fi
    done < <(
        find "$canonical_path" -xdev -type f -mtime "+$days" -print0
    )

    echo

done < "$CONFIG_FILE"

# -------------------- Summary --------------------

echo "-------------------- Summary --------------------"
echo "Files found:    $total_found"

if [[ "$DRY_RUN" == true ]]; then
    echo "Files deleted:  0 (dry-run mode)"
else
    echo "Files deleted:  $total_deleted"
fi

echo "Failures:       $total_failed"
