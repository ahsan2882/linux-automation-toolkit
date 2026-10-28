#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# Load configuration relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    printf 'ERROR: Configuration file not found: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate configuration
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${LOG_FILE:?LOG_FILE is required}"
: "${BACKUP_PREFIX:?BACKUP_PREFIX is required}"
: "${RETENTION_COUNT:?RETENTION_COUNT is required}"
: "${COMPRESSION_LEVEL:?COMPRESSION_LEVEL is required}"

if [[ ! "$RETENTION_COUNT" =~ ^[1-9][0-9]*$ ]] ||
   [[ ! "$COMPRESSION_LEVEL" =~ ^[1-9]$ ]] ||
   (( COMPRESSION_LEVEL > 9 )); then
    printf 'ERROR: Invalid retention count or compression level.\n' >&2
    exit 1
fi

if (( ${#SOURCE_DIRS[@]} == 0 )); then
    printf 'ERROR: No source directories configured.\n' >&2
    exit 1
fi

# Required utilities
for cmd in tar gzip pv du findmnt realpath flock find sort tee; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'ERROR: Required command not found: %s\n' "$cmd" >&2
        exit 1
    fi
done

# Log to both the configured log file and the terminal.
# If the log cannot be opened, fail before starting the backup.
if ! { exec 3>>"$LOG_FILE"; } 2>/dev/null; then
    printf 'ERROR: Cannot write to log file: %s\n' "$LOG_FILE" >&2
    exit 1
fi

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" |
        tee /dev/fd/3
}

# Validate sources
for source in "${SOURCE_DIRS[@]}"; do
    if [[ ! -d "$source" ]]; then
        log "ERROR: Source directory does not exist: $source"
        exit 1
    fi
done

# Destination must already exist: do not silently create it
# when the external disk is unmounted.
if [[ ! -d "$BACKUP_DIR" ]]; then
    log "ERROR: Backup destination missing: $BACKUP_DIR"
    exit 1
fi

BACKUP_REAL="$(realpath -e -- "$BACKUP_DIR")"

if [[ ! -w "$BACKUP_REAL" ]]; then
    log "ERROR: Destination is not writable: $BACKUP_REAL"
    exit 1
fi

# Ensure destination is not on the root filesystem.
# For stronger protection, additionally verify the expected
# external disk UUID before every backup.
DEST_DEVICE="$(findmnt -n -o MAJ:MIN -T "$BACKUP_REAL")"
ROOT_DEVICE="$(findmnt -n -o MAJ:MIN -T /)"

if [[ "$DEST_DEVICE" == "$ROOT_DEVICE" ]]; then
    log "ERROR: Destination is on the root filesystem."
    exit 1
fi

# Prevent concurrent runs
exec 9>"${BACKUP_REAL}/.backup.lock"

if ! flock -n 9; then
    log "ERROR: Another backup is already running."
    exit 1
fi

# Build GNU tar exclusion arguments.
EXCLUDE_ARGS=()

for pattern in "${EXCLUDE_DIR_PATTERNS[@]}" \
               "${EXCLUDE_FILE_PATTERNS[@]}"; do
    EXCLUDE_ARGS+=( "--exclude=${pattern}" )
done

# Estimate source size, excluding the configured patterns.
TOTAL_BYTES="$(
    du -sb --total "${EXCLUDE_ARGS[@]}" -- "${SOURCE_DIRS[@]}" |
        awk 'END { print $1 }'
)"

if [[ ! "$TOTAL_BYTES" =~ ^[0-9]+$ ]] || (( TOTAL_BYTES < 1 )); then
    log "ERROR: Could not determine a valid source size."
    exit 1
fi

# Prepare archive and temporary output
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
ARCHIVE="${BACKUP_REAL}/${BACKUP_PREFIX}_${TIMESTAMP}.tar.gz"

if [[ -e "$ARCHIVE" ]]; then
    log "ERROR: Archive already exists: $ARCHIVE"
    exit 1
fi

TEMP_ARCHIVE="$(mktemp "${BACKUP_REAL}/.${BACKUP_PREFIX}.XXXXXX")"
HASH_FILE="${TEMP_ARCHIVE}.sha256"
LIST_FILE="${TEMP_ARCHIVE}.list"

cleanup() {
    local leftover

    for leftover in "${TEMP_ARCHIVE:-}" "${HASH_FILE:-}" "${LIST_FILE:-}"; do
        if [[ -n "$leftover" && -f "$leftover" ]]; then
            rm -f -- "$leftover"
        fi
    done
}
trap cleanup EXIT

# Use paths relative to their parent directories.
TAR_ARGS=()

for source in "${SOURCE_DIRS[@]}"; do
    TAR_ARGS+=( -C "$(dirname -- "$source")" "$(basename -- "$source")" )
done

log "Starting backup."
log "Destination: $BACKUP_REAL"
log "Estimated input size: $TOTAL_BYTES bytes"
log "Creating archive: $(basename -- "$ARCHIVE")"
log "Progress below is an estimate; tar adds archive metadata."

# Stream tar -> progress monitor -> gzip.
# pv displays a live progress bar, throughput, elapsed time,
# and ETA. The percentage is approximate because tar adds headers.
if ! tar --create --file=- --verbose --index-file="$LIST_FILE" \
    "${EXCLUDE_ARGS[@]}" \
    "${TAR_ARGS[@]}" |
    pv --progress --timer --eta --rate --bytes \
       --size "$TOTAL_BYTES" |
    gzip "-${COMPRESSION_LEVEL}" |
    tee -- "$TEMP_ARCHIVE" |
    sha256sum |
    awk -v name="$(basename -- "$ARCHIVE")" '{ print $1 "  " name }' > "$HASH_FILE"; then
    log "ERROR: Backup creation failed. Existing backups preserved."
    exit 1
fi

# Validate compressed data and archive contents
if ! gzip -t "$TEMP_ARCHIVE" ||
   ! tar -tzf "$TEMP_ARCHIVE" >/dev/null; then
    log "ERROR: Archive validation failed."
    exit 1
fi

# Publish completed archive atomically on the same filesystem
mv -- "$TEMP_ARCHIVE" "$ARCHIVE"
mv -- "$HASH_FILE" "${ARCHIVE}.sha256"
mv -- "$LIST_FILE" "${ARCHIVE}.list"
TEMP_ARCHIVE=""
HASH_FILE=""
LIST_FILE=""

log "Backup created and validated: $ARCHIVE"

# Retain newest archives matching this tool's filename format.
mapfile -t BACKUPS < <(
    find "$BACKUP_REAL" -maxdepth 1 -type f \
        -regextype posix-extended \
        -regex ".*/${BACKUP_PREFIX}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.tar\.gz" \
        -printf '%f\n' |
        sort -r
)

if (( ${#BACKUPS[@]} > RETENTION_COUNT )); then
    for (( i = RETENTION_COUNT; i < ${#BACKUPS[@]}; i++ )); do
        OLD_BACKUP="${BACKUP_REAL}/${BACKUPS[$i]}"

                if rm -- "$OLD_BACKUP" &&
           rm -f -- "${OLD_BACKUP}.sha256" "${OLD_BACKUP}.list"; then
            log "Removed old backup: ${BACKUPS[$i]}"
        else
            log "ERROR: Could not remove old backup: $OLD_BACKUP"
            exit 1
        fi
    done
fi

log "Backup completed successfully."
