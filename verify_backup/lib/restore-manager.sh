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
