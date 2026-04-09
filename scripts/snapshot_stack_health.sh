#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/stack_health"
OUT_FILE="${OUT_DIR}/stack_health_${STAMP}.json"

mkdir -p "${OUT_DIR}"

curl -fsS http://127.0.0.1:3000/stack/health > "${OUT_FILE}"

echo "[OK] snapshot salvo em ${OUT_FILE}"
cat "${OUT_FILE}"
