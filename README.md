# 🛠️ Bash Admin Toolkit

A collection of production-grade Bash scripts for Linux server administration and DevOps automation.

## Scripts

### 📦 `backup.sh` — Directory Backup with Rotation

Creates compressed `.tar.gz` archives with automatic cleanup of old backups.

```bash
chmod +x scripts/backup.sh

# Backup /var/www to /mnt/backups, keep 14 days
./scripts/backup.sh /var/www /mnt/backups --keep 14

# Backup with defaults (keep 7 days, store in /tmp/backups)
./scripts/backup.sh /etc
```

Features:
- Multi-day retention with `--keep N`
- Archive integrity verification via `tar -tzf`
- Logging to `/var/log/backup.log`
- Non-zero exit code on failure (safe for cron)

---

### 💽 `disk-monitor.sh` — Disk Usage Monitor

Checks all mounted filesystems and alerts when usage exceeds threshold.

```bash
chmod +x scripts/disk-monitor.sh

# Default threshold: 80%
./scripts/disk-monitor.sh

# Custom threshold + email alert
./scripts/disk-monitor.sh --threshold 90 --alert-email admin@example.com
```

Cron example (run every hour):
```cron
0 * * * * /opt/scripts/disk-monitor.sh --threshold 85 >> /var/log/disk-check.log 2>&1
```

---

### 🐳 `docker-cleanup.sh` — Docker Resource Cleanup

Removes unused containers, images, volumes, networks, and build cache.

```bash
chmod +x scripts/docker-cleanup.sh

# Preview what would be deleted (safe)
./scripts/docker-cleanup.sh --dry-run

# Clean dangling resources
./scripts/docker-cleanup.sh

# Full cleanup — all unused images too
./scripts/docker-cleanup.sh --all
```

---

## Design Principles

All scripts follow these practices:

| Practice | Implementation |
|----------|---------------|
| Strict mode | `set -euo pipefail` — fail on errors, undefined vars, pipe failures |
| Logging | Timestamped output with INFO/WARN/ERROR/ALERT levels |
| Idempotent | Safe to run multiple times |
| Dry-run support | `--dry-run` flag where destructive actions are involved |
| Exit codes | Non-zero on failure, compatible with cron and CI |
| No root required | Scripts work as regular user where possible |

## Requirements

- Bash 4.0+
- Linux (tested on Ubuntu 22.04, Debian 12)
- `tar`, `df`, `du`, `free` (standard coreutils)
- `docker` (for docker-cleanup.sh only)
