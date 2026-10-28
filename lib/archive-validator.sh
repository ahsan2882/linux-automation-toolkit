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

verify_archive_hash() {
    local archive="$1"
    local hash_file="${archive}.sha256"

    if [[ ! -f "$hash_file" ]]; then
        log "ERROR: Missing checksum file: $hash_file"
        return 1
    fi

    log "Verifying archive checksum..."

    if ! (cd -- "$(dirname -- "$archive")" &&
          sha256sum -c --quiet -- "$(basename -- "$hash_file")"); then
        log "ERROR: Archive checksum does not match the one recorded at backup time."
        return 1
    fi
}

verify_file_list() {
    local archive="$1"
    local list_file="${archive}.list"
    local differences

    if [[ ! -f "$list_file" ]]; then
        log "ERROR: Missing file list: $list_file"
        return 1
    fi

    log "Comparing archive contents with the list recorded at backup time..."

    differences="$(
        diff <(LC_ALL=C sort -- "$list_file") \
             <(tar -tzf "$archive" | LC_ALL=C sort) | head -n 20
    )" || true

    if [[ -n "$differences" ]]; then
        log "ERROR: File list differs (first differences below)."
        printf '%s\n' "$differences" >&2
        return 1
    fi

    log "File count: $(wc -l < "$list_file") entries."
}
