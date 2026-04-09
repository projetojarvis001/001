#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


echo "===== BUILD ====="
docker compose build --no-cache jarvis-core

echo
echo "===== UP ====="
docker compose up -d

echo
echo "===== AGUARDANDO ====="
sleep 12

echo
echo "===== VALIDACAO ====="
./scripts/validate_fase6.sh

echo
echo "[OK] stack vision pronta"
