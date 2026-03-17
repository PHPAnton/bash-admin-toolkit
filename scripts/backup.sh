#!/usr/bin/env bash
# =============================================================================
# backup.sh — Directory backup with rotation and logging
# Usage: ./backup.sh <source_dir> [destination_dir] [--keep N]
# =============================================================================

set -euo pipefail

# ── Config defaults ───────────────────────────────────────────────────────────
SOURCE_DIR="${1:-}"
DEST_DIR="${2:-/tmp/backups}"
KEEP_DAYS=7
LOG_FILE="/var/log/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
info()    { log "${GREEN}[INFO]${NC}  $1"; }
warn()    { log "${YELLOW}[WARN]${NC}  $1"; }
error()   { log "${RED}[ERROR]${NC} $1"; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 <source_dir> [destination_dir] [--keep N]"
    echo "  source_dir       Directory to back up (required)"
    echo "  destination_dir  Where to store backups (default: /tmp/backups)"
    echo "  --keep N         Keep backups for N days (default: 7)"
    exit 1
}

# ── Parse args ────────────────────────────────────────────────────────────────
parse_args() {
    [[ -z "${SOURCE_DIR}" ]] && usage
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep) KEEP_DAYS="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
}

# ── Validate ──────────────────────────────────────────────────────────────────
validate() {
    if [[ ! -d "${SOURCE_DIR}" ]]; then
        error "Source directory '${SOURCE_DIR}' does not exist."
        exit 1
    fi
    if ! command -v tar &>/dev/null; then
        error "'tar' is not installed."
        exit 1
    fi
    mkdir -p "${DEST_DIR}"
}

# ── Create backup ─────────────────────────────────────────────────────────────
create_backup() {
    local source_name
    source_name=$(basename "${SOURCE_DIR}")
    local archive="${DEST_DIR}/${source_name}_${TIMESTAMP}.tar.gz"

    info "Starting backup: ${SOURCE_DIR} → ${archive}"

    if tar -czf "${archive}" -C "$(dirname "${SOURCE_DIR}")" "${source_name}" 2>/dev/null; then
        local size
        size=$(du -sh "${archive}" | cut -f1)
        info "Backup created successfully. Size: ${size}"
        echo "${archive}"
    else
        error "Backup failed!"
        exit 1
    fi
}

# ── Rotate old backups ────────────────────────────────────────────────────────
rotate_backups() {
    local source_name
    source_name=$(basename "${SOURCE_DIR}")
    local deleted=0

    while IFS= read -r old_backup; do
        rm -f "${old_backup}"
        warn "Deleted old backup: $(basename "${old_backup}")"
        ((deleted++))
    done < <(find "${DEST_DIR}" -name "${source_name}_*.tar.gz" -mtime +${KEEP_DAYS} 2>/dev/null)

    [[ ${deleted} -gt 0 ]] && info "Rotated ${deleted} old backup(s) (older than ${KEEP_DAYS} days)"
}

# ── Verify backup ─────────────────────────────────────────────────────────────
verify_backup() {
    local archive="$1"
    info "Verifying archive integrity..."
    if tar -tzf "${archive}" &>/dev/null; then
        info "Archive integrity: OK ✓"
    else
        error "Archive is corrupt!"
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    validate
    info "=== Backup started ==="
    local archive
    archive=$(create_backup)
    verify_backup "${archive}"
    rotate_backups
    info "=== Backup finished ==="
}

main "$@"
