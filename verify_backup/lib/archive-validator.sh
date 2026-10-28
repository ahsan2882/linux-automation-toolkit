# shellcheck shell=bash
validate_archive() {
    local archive="$1"
    local member

    if [[ ! -f "$archive" || ! -r "$archive" ]]; then
        log "ERROR: Archive is missing or unreadable."
        return 1
    fi

    log "Checking gzip integrity..."

    if ! gzip -t -- "$archive"; then
        log "ERROR: Gzip integrity test failed."
        return 1
    fi

    log "Checking tar archive structure..."

    if ! tar -tzf "$archive" >/dev/null; then
        log "ERROR: Unable to read tar archive."
        return 1
    fi

    log "Checking archive member paths..."

    # Archives created by backup.sh use relative paths.
    # Reject absolute paths and any '..' path component.
    while IFS= read -r member; do
        if [[ "$member" == /* ]]; then
            log "ERROR: Absolute archive path rejected: $member"
            return 1
        fi

        case "/${member}/" in
            */../*)
                log "ERROR: Parent-directory traversal rejected: $member"
                return 1
                ;;
        esac
    done < <(tar -tzf "$archive") || {
        log "ERROR: Could not inspect archive paths."
        return 1
    }

    return 0
}
