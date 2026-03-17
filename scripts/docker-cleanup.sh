#!/usr/bin/env bash
# =============================================================================
# docker-cleanup.sh — Clean up unused Docker resources
# Usage: ./docker-cleanup.sh [--dry-run] [--all]
# =============================================================================

set -euo pipefail

DRY_RUN=false
CLEAN_ALL=false

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
action(){ echo -e "${CYAN}[RUN]${NC}   $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --all)     CLEAN_ALL=true; shift ;;
        *) echo "Usage: $0 [--dry-run] [--all]"; exit 1 ;;
    esac
done

run() {
    if ${DRY_RUN}; then
        warn "DRY-RUN: $*"
    else
        action "Executing: $*"
        eval "$@"
    fi
}

require_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker is not installed or not in PATH." >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker daemon is not running." >&2
        exit 1
    fi
}

disk_before() {
    docker system df 2>/dev/null || true
}

cleanup_containers() {
    info "Removing stopped containers..."
    local containers
    containers=$(docker ps -aq --filter status=exited --filter status=created 2>/dev/null || true)
    if [[ -n "${containers}" ]]; then
        run "docker rm ${containers}"
        info "Removed $(echo "${containers}" | wc -w) container(s)"
    else
        info "No stopped containers to remove."
    fi
}

cleanup_images() {
    info "Removing dangling images (untagged)..."
    local images
    images=$(docker images -q --filter dangling=true 2>/dev/null || true)
    if [[ -n "${images}" ]]; then
        run "docker rmi ${images}"
    else
        info "No dangling images found."
    fi

    if ${CLEAN_ALL}; then
        warn "Removing ALL unused images (--all flag set)..."
        run "docker image prune -af"
    fi
}

cleanup_volumes() {
    info "Removing unused volumes..."
    run "docker volume prune -f"
}

cleanup_networks() {
    info "Removing unused networks..."
    run "docker network prune -f"
}

cleanup_build_cache() {
    info "Removing build cache..."
    if ${CLEAN_ALL}; then
        run "docker builder prune -af"
    else
        run "docker builder prune -f"
    fi
}

main() {
    require_docker

    echo -e "\n${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Docker Cleanup — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    ${DRY_RUN} && echo -e "${YELLOW}  *** DRY RUN MODE — no changes will be made ***${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}\n"

    echo -e "${CYAN}── Disk usage BEFORE ───────────────────────────${NC}"
    disk_before

    cleanup_containers
    cleanup_images
    cleanup_volumes
    cleanup_networks
    cleanup_build_cache

    echo -e "\n${CYAN}── Disk usage AFTER ────────────────────────────${NC}"
    docker system df 2>/dev/null || true

    info "Docker cleanup complete ✓"
}

main "$@"
