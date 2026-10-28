# shellcheck shell=bash
# shellcheck disable=SC2153  # EXTRACT_DIR, SAMPLE_FILE and SAMPLE_SIZE are set by verify.sh and its config
restore_archive() {
    local archive="$1"

    if [[ ! -d "$TEMP_DIR" || ! -w "$TEMP_DIR" ]]; then
        log "ERROR: Temporary directory is missing or not writable: $TEMP_DIR"
        return 1
    fi

    WORK_DIR="$(mktemp -d "${TEMP_DIR%/}/backup-verify.XXXXXX")" || {
        log "ERROR: Could not create temporary workspace."
        return 1
    }

    EXTRACT_DIR="${WORK_DIR}/extracted"

    if ! mkdir -m 700 -- "$EXTRACT_DIR"; then
        log "ERROR: Could not create extraction directory."
        return 1
    fi

    log "Extracting archive into temporary workspace..."
    log "Workspace: $EXTRACT_DIR"

    # Do not restore original ownership or privileged permissions.
    if ! tar --extract --gzip --file="$archive" --directory="$EXTRACT_DIR" --no-same-owner --same-permissions; then
        log "ERROR: Archive extraction failed."
        return 1
    fi

    return 0
}

restore_sample() {
    local archive="$1"
    local list_file="${archive}.list"

    if [[ ! -d "$TEMP_DIR" || ! -w "$TEMP_DIR" ]]; then
        log "ERROR: Temporary directory is missing or not writable: $TEMP_DIR"
        return 1
    fi

    WORK_DIR="$(mktemp -d "${TEMP_DIR%/}/backup-verify.XXXXXX")" || {
        log "ERROR: Could not create temporary workspace."
        return 1
    }

    EXTRACT_DIR="${WORK_DIR}/extracted"
    SAMPLE_FILE="${WORK_DIR}/sample.txt"
    mkdir -m 700 -- "$EXTRACT_DIR"

    # Files only (directory entries end with "/"), randomly chosen.
    { grep -v '/$' -- "$list_file" || true; } | shuf -n "$SAMPLE_SIZE" > "$SAMPLE_FILE"

    if [[ ! -s "$SAMPLE_FILE" ]]; then
        log "WARNING: Archive contains no regular files to sample."
        return 0
    fi

    log "Extracting $(wc -l < "$SAMPLE_FILE") sampled files in one pass..."

    if ! tar --extract --gzip --file="$archive" --directory="$EXTRACT_DIR" \
             --no-same-owner --files-from="$SAMPLE_FILE"; then
        log "ERROR: Sample extraction failed."
        return 1
    fi
}
