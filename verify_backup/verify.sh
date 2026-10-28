#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/verify.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    printf 'ERROR: Configuration file not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${BACKUP_PREFIX:?BACKUP_PREFIX is required}"
: "${TEMP_DIR:?TEMP_DIR is required}"
: "${VERIFY_LOG:?VERIFY_LOG is required}"

if [[ ! "$KEEP_TEMP_ON_FAILURE" =~ ^(true|false)$ ]]; then
    printf 'ERROR: KEEP_TEMP_ON_FAILURE must be true or false.\n' >&2
    exit 1
fi

# Resolve log path relative to this script when not absolute.
if [[ "$VERIFY_LOG" != /* ]]; then
    VERIFY_LOG="${SCRIPT_DIR}/${VERIFY_LOG}"
fi

mkdir -p -- "$(dirname -- "$VERIFY_LOG")"

if ! { exec 3>>"$VERIFY_LOG"; } 2>/dev/null; then
    printf 'ERROR: Cannot write to log: %s\n' "$VERIFY_LOG" >&2
    exit 1
fi

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" |
        tee /dev/fd/3
}

# Load library modules
for library in \
    archive-validator.sh \
    restore-manager.sh \
    checksum-verifier.sh
do
    library_path="${SCRIPT_DIR}/lib/${library}"

    if [[ ! -f "$library_path" ]]; then
        log "ERROR: Missing library: $library_path"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$library_path"
done

# Check required commands
for command_name in \
    tar gzip find sort head wc sha256sum realpath mktemp
do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log "ERROR: Required command not found: $command_name"
        exit 1
    fi
done

# Validate backup destination
if [[ ! -d "$BACKUP_DIR" ]]; then
    log "ERROR: Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

BACKUP_REAL="$(realpath -e -- "$BACKUP_DIR")" || {
    log "ERROR: Cannot resolve backup directory."
    exit 1
}

# Prevent overlapping verification runs
LOCK_FILE="${SCRIPT_DIR}/.verify.lock"
exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    log "ERROR: Another verification is already running."
    exit 1
fi

# Select the newest timestamped archive.
# Ignore temporary files and unrelated archives.
mapfile -t ARCHIVES < <(
    find "$BACKUP_REAL" -maxdepth 1 -type f \
        -regextype posix-extended \
        -regex ".*/${BACKUP_PREFIX}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.tar\.gz" \
        -printf '%f\n' |
        sort -r
)

if (( ${#ARCHIVES[@]} == 0 )); then
    log "FAIL: No matching backup archives found."
    exit 1
fi

ARCHIVE="${BACKUP_REAL}/${ARCHIVES[0]}"

log "=================================================="
log "Starting backup verification."
log "Archive: $ARCHIVE"

WORK_DIR=""

cleanup() {
    local exit_code=$?

    if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
        if (( exit_code == 0 )) || [[ "$KEEP_TEMP_ON_FAILURE" == false ]]; then
            rm -rf -- "$WORK_DIR"
            log "Temporary workspace cleaned up."
        else
            log "Temporary workspace preserved: $WORK_DIR"
        fi
    fi
}

trap cleanup EXIT

# Stage 1: Validate archive integrity and member paths
if ! validate_archive "$ARCHIVE"; then
    log "FAIL: Archive validation failed."
    exit 1
fi

log "PASS: Archive integrity and path validation."

# Stage 2: Extract into an isolated temporary directory
if ! restore_archive "$ARCHIVE"; then
    log "FAIL: Extraction failed."
    exit 1
fi

log "PASS: Archive extracted successfully."

# Stage 3: Verify counts, checksums, and archived contents
if ! verify_checksums "$ARCHIVE" "$EXTRACT_DIR"; then
    log "FAIL: Content verification failed."
    exit 1
fi

log "PASS: File counts and content verification."
log "PASS: Backup verification completed."
log "=================================================="

exit 0
