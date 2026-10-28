verify_checksums() {
    local archive="$1"
    local extract_dir="$2"
    local compare_log="${WORK_DIR}/compare-errors.txt"

    log "Comparing archive against extracted files..."

    if tar --compare \
        --gzip \
        --file="$archive" \
        --directory="$extract_dir" \
        2>"$compare_log"; then
        log "PASS: Archive contents match the extracted files."
        return 0
    else
        cat "$compare_log" >&2
        log "ERROR: Archive comparison detected differences."
        return 1
    fi
}
