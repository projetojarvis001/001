#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um backup valido do .env"
  exit 1
fi

cp .env ".env.restore.$(date +%Y%m%d-%H%M%S).bak" 2>/dev/null || true
cp "${INPUT_FILE}" .env
chmod 600 .env

echo "[OK] .env restaurado a partir de ${INPUT_FILE}"
