#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

BASE_DIR="backups/operational_state"
mkdir -p "${BASE_DIR}"

echo "===== OPERATIONAL BACKUPS ====="
ls -lh "${BASE_DIR}"/*.tar.gz 2>/dev/null || echo "[INFO] nenhum backup encontrado"
