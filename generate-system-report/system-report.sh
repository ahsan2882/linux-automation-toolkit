#!/usr/bin/env bash

set -Eeuo pipefail

# -------------------- Configuration --------------------

TOP_PROCESSES=15
DISK_WARNING_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=80

# -------------------- Formatting --------------------

BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
GREEN='\033[32m'
RESET='\033[0m'

section() {
    printf '\n%b=== %s ===%b\n' "$CYAN" "$1" "$RESET"
}

# -------------------- System Information --------------------

printf '%bSYSTEM REPORT%b\n' "$BOLD" "$RESET"
printf 'Hostname: %s\n' "$(hostname)"
printf 'Date:     %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'OS:       %s\n' "$(. /etc/os-release && echo "$PRETTY_NAME")"
printf 'Kernel:   %s\n' "$(uname -r)"

# -------------------- Uptime and Load --------------------

section "UPTIME & LOAD"

uptime -p
printf 'Load averages: %s\n' "$(awk '{print $1, $2, $3}' /proc/loadavg)"
printf 'Logged-in users: %s\n' "$(who | wc -l)"

# -------------------- CPU --------------------

section "CPU"

printf 'Processors: %s\n' "$(nproc)"
printf 'CPU model:  %s\n' \
    "$(awk -F ': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"

if command -v mpstat >/dev/null 2>&1; then
    mpstat 1 1 | tail -n 1
else
    printf 'CPU usage: Install sysstat for live CPU utilization.\n'
fi

# -------------------- Memory --------------------

section "MEMORY"

free -h

MEMORY_USED_PERCENT=$(
    awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2}
         END {
             if (total > 0) printf "%.0f", 100 * (total - available) / total;
             else print 0
         }' /proc/meminfo
)

if (( MEMORY_USED_PERCENT >= MEMORY_WARNING_THRESHOLD )); then
    printf '%bWARNING: Memory usage is %s%%%b\n' \
        "$YELLOW" "$MEMORY_USED_PERCENT" "$RESET"
else
    printf 'Memory usage: %s%%\n' "$MEMORY_USED_PERCENT"
fi

# -------------------- Disk Usage --------------------

section "DISK USAGE"

df -hT -x tmpfs -x devtmpfs -x squashfs

while read -r filesystem type size used available percent mountpoint; do
    usage=${percent%%%}

    if [[ "$usage" =~ ^[0-9]+$ ]] &&
       (( usage >= DISK_WARNING_THRESHOLD )); then
        printf '%bWARNING: %s is %s%% full (%s)%b\n' \
            "$RED" "$mountpoint" "$usage" "$filesystem" "$RESET"
    fi
done < <(
    df -hT -x tmpfs -x devtmpfs -x squashfs |
        tail -n +2
)

# -------------------- Top Processes --------------------

section "TOP ${TOP_PROCESSES} PROCESSES BY CPU"

ps -eo pid,comm,%cpu,%mem --sort=-%cpu |
    head -n "$((TOP_PROCESSES + 1))"

section "TOP ${TOP_PROCESSES} PROCESSES BY MEMORY"

ps -eo pid,comm,%cpu,%mem --sort=-%mem |
    head -n "$((TOP_PROCESSES + 1))"

# -------------------- Failed Services --------------------

section "FAILED SYSTEMD SERVICES"

if command -v systemctl >/dev/null 2>&1; then
    FAILED_SERVICES=$(systemctl --failed --no-legend --no-pager 2>/dev/null || true)

    if [[ -n "$FAILED_SERVICES" ]]; then
        printf '%b%s%b\n' "$RED" "$FAILED_SERVICES" "$RESET"
    else
        printf '%bNo failed services.%b\n' "$GREEN" "$RESET"
    fi
else
    printf 'systemctl is unavailable.\n'
fi

# -------------------- End --------------------

printf '\n%bReport completed.%b\n' "$BOLD" "$RESET"
