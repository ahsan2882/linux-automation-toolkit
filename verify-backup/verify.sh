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
: "${SAMPLE_SIZE:?SAMPLE_SIZE is required}"
: "${SOURCE_DIRS[0]:?SOURCE_DIRS is required}"
: "${KEEP_TEMP_ON_FAILURE:?KEEP_TEMP_ON_FAILURE is required}"

if [[ ! "$SAMPLE_SIZE" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERROR: SAMPLE_SIZE must be a positive integer.\n' >&2
    exit 1
fi

if [[ ! "$KEEP_TEMP_ON_FAILURE" =~ ^(true|false)$ ]]; then
    printf 'ERROR: KEEP_TEMP_ON_FAILURE must be true or false.\n' >&2
    exit 1
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
    library_path="${SCRIPT_DIR}/../lib/${library}"

    if [[ ! -f "$library_path" ]]; then
        log "ERROR: Missing library: $library_path"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$library_path"
done

# Check required commands
for command_name in \
    tar gzip find sort head wc sha256sum realpath mktemp shuf cmp diff grep
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

# shellcheck disable=SC2317,SC2329  # invoked via trap
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

# Stage 2: Archive file matches the checksum recorded at backup time
if ! verify_archive_hash "$ARCHIVE"; then
    log "FAIL: Archive checksum verification failed."
    exit 1
fi

log "PASS: Archive checksum."

# Stage 3: Archive holds exactly the files recorded at backup time
if ! verify_file_list "$ARCHIVE"; then
    log "FAIL: File list verification failed."
    exit 1
fi

log "PASS: File list and count."

# Stage 4: Extract a random sample and compare it with the live files
if ! restore_sample "$ARCHIVE"; then
    log "FAIL: Sample extraction failed."
    exit 1
fi

if ! verify_sample "$ARCHIVE"; then
    log "FAIL: Sample content verification failed."
    exit 1
fi

log "PASS: Sample content verification."
log "PASS: Backup verification completed."
log "=================================================="

exit 0
