#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
BASE_DIR="backups/operational_state"
BACKUP_DIR="${BASE_DIR}/snapshot_${STAMP}"

mkdir -p "${BACKUP_DIR}"
mkdir -p logs/state logs/history

cp -R logs/state "${BACKUP_DIR}/state"
cp -R logs/history "${BACKUP_DIR}/history"

cat > "${BACKUP_DIR}/manifest.json" <<JSON
{
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "snapshot": "snapshot_${STAMP}",
  "paths": {
    "state": "${BACKUP_DIR}/state",
    "history": "${BACKUP_DIR}/history"
  }
}
JSON

tar -czf "${BACKUP_DIR}.tar.gz" -C "${BASE_DIR}" "snapshot_${STAMP}"
rm -rf "${BACKUP_DIR}"

echo "[OK] backup criado em ${BACKUP_DIR}.tar.gz"
ls -lh "${BACKUP_DIR}.tar.gz"
