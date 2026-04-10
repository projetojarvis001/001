#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== BACKUPS POSTGRES ====="
ls -lh backups/postgres/* 2>/dev/null || echo "[INFO] nenhum backup postgres encontrado"
echo

echo "===== BACKUPS ENV ====="
ls -lh backups/env/* 2>/dev/null || echo "[INFO] nenhum backup env encontrado"
