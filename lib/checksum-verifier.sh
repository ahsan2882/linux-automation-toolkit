# shellcheck shell=bash
# shellcheck disable=SC2153  # EXTRACT_DIR, SAMPLE_FILE and SAMPLE_SIZE are set by verify.sh and its config
verify_sample() {
    local archive="$1"
    local checked=0 skipped=0 failed=0
    local file top parent source_file source
    local -A parent_of=()

    for source in "${SOURCE_DIRS[@]}"; do
        parent_of["$(basename -- "$source")"]="$(dirname -- "$source")"
    done

    while IFS= read -r file; do
        top="${file%%/*}"
        parent="${parent_of[$top]:-}"

        if [[ -z "$parent" ]]; then
            log "WARNING: No source directory mapped for: $file"
            skipped=$((skipped + 1))
            continue
        fi

        source_file="${parent}/${file}"

        # Skip files deleted or modified after the backup was made.
        if [[ ! -e "$source_file" || "$source_file" -nt "$archive" ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        if cmp -s -- "${EXTRACT_DIR}/${file}" "$source_file"; then
            checked=$((checked + 1))
        else
            log "ERROR: Content differs from source: $file"
            failed=$((failed + 1))
        fi
    done < "${SAMPLE_FILE:-/dev/null}"

    log "Sample result: ${checked} matched, ${failed} differed, ${skipped} skipped."

    if (( failed > 0 )); then
        return 1
    fi

    if (( checked == 0 )); then
        log "WARNING: No sampled file could be compared with the source."
    fi
}
