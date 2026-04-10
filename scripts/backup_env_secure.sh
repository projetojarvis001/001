#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="backups/env"
OUT_FILE="${OUT_DIR}/env_${STAMP}.bak"

mkdir -p "${OUT_DIR}"

if [ ! -f .env ]; then
  echo "[ERRO] arquivo .env nao encontrado"
  exit 1
fi

cp .env "${OUT_FILE}"
chmod 600 "${OUT_FILE}"

echo "[OK] backup do .env criado em ${OUT_FILE}"
ls -l "${OUT_FILE}"
