#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 26 ====="

echo
echo "===== CHECK ANTES ====="
./scripts/check_config_consistency.sh || true

echo
echo "===== FIX DATABASE URL ====="
./scripts/fix_database_url.sh

echo
echo "===== CHECK DEPOIS DO FIX ====="
./scripts/check_config_consistency.sh

echo
echo "===== REBUILD CORE ====="
docker compose build --no-cache jarvis-core
docker compose up -d
sleep 15

echo
echo "===== CHECK POS-REBUILD ====="
./scripts/check_config_consistency.sh

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase25.sh

echo
echo "[OK] fase 26 validada"
