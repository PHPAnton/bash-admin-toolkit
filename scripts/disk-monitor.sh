#!/usr/bin/env bash
# =============================================================================
# disk-monitor.sh — Disk usage monitor with alerts
# Usage: ./disk-monitor.sh [--threshold N] [--alert-email user@example.com]
# =============================================================================

set -euo pipefail

THRESHOLD=80
ALERT_EMAIL=""
LOG_FILE="/var/log/disk-monitor.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()   { echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "$1"; }
info()  { log "${GREEN}[INFO]${NC}  $1"; }
warn()  { log "${YELLOW}[WARN]${NC}  $1"; }
alert() { log "${RED}[ALERT]${NC} $1"; }

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold)   THRESHOLD="$2"; shift 2 ;;
        --alert-email) ALERT_EMAIL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Send alert ────────────────────────────────────────────────────────────────
send_alert() {
    local mount="$1" usage="$2"
    local message="DISK ALERT: ${mount} is at ${usage}% (threshold: ${THRESHOLD}%) on $(hostname)"

    if [[ -n "${ALERT_EMAIL}" ]] && command -v mail &>/dev/null; then
        echo "${message}" | mail -s "Disk Alert - $(hostname)" "${ALERT_EMAIL}"
        info "Alert email sent to ${ALERT_EMAIL}"
    fi

    # Write alert marker for external monitoring systems
    echo "$(date '+%Y-%m-%d %H:%M:%S') ALERT mount=${mount} usage=${usage}%" >> "/tmp/disk-alerts.log"
}

# ── Check disk usage ──────────────────────────────────────────────────────────
check_disks() {
    local alert_count=0

    echo -e "\n${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Disk Usage Report — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}  Host: $(hostname)  |  Threshold: ${THRESHOLD}%${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    printf "%-20s %6s %6s %6s %6s\n" "Mount" "Size" "Used" "Free" "Use%"
    echo -e "────────────────────────────────────────────────"

    while IFS= read -r line; do
        # Extract fields: filesystem size used avail use% mountpoint
        local usage mount
        usage=$(echo "${line}" | awk '{print $5}' | tr -d '%')
        mount=$(echo "${line}" | awk '{print $6}')
        local size used avail
        size=$(echo "${line}"  | awk '{print $2}')
        used=$(echo "${line}"  | awk '{print $3}')
        avail=$(echo "${line}" | awk '{print $4}')

        # Skip pseudo filesystems
        [[ "${mount}" == /proc* || "${mount}" == /sys* || "${mount}" == /dev* ]] && continue
        [[ "${mount}" == /run*  || "${mount}" == /snap* ]] && continue

        # Color based on usage
        local color="${GREEN}"
        [[ ${usage} -ge 70 ]] && color="${YELLOW}"
        [[ ${usage} -ge ${THRESHOLD} ]] && color="${RED}"

        printf "${color}%-20s %6s %6s %6s %5s%%${NC}\n" "${mount}" "${size}" "${used}" "${avail}" "${usage}"

        if [[ ${usage} -ge ${THRESHOLD} ]]; then
            alert "Disk usage critical: ${mount} is at ${usage}%"
            send_alert "${mount}" "${usage}"
            ((alert_count++))
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 || df -h | tail -n +2)

    echo -e "────────────────────────────────────────────────"

    if [[ ${alert_count} -eq 0 ]]; then
        info "All disks are within normal range (< ${THRESHOLD}%)"
    else
        alert "${alert_count} disk(s) exceeded the ${THRESHOLD}% threshold!"
    fi

    return ${alert_count}
}

# ── System summary ────────────────────────────────────────────────────────────
system_summary() {
    echo -e "\n${CYAN}── Memory ──────────────────────────────────────${NC}"
    free -h | awk 'NR==1{printf "%-12s %8s %8s %8s\n",$1,$2,$3,$4} NR==2{printf "%-12s %8s %8s %8s\n",$1,$2,$3,$4}'

    echo -e "\n${CYAN}── Top 5 large directories in / ────────────────${NC}"
    du -sh /[a-z]* 2>/dev/null | sort -rh | head -5 || true
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_disks || true
    system_summary
}

main "$@"
