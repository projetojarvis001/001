#!/usr/bin/env bash
set -e

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
./scripts/validate_fase5.sh

echo
echo "[OK] stack vision pronta"
