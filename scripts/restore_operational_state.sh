#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

BASE_DIR="backups/operational_state"
INPUT_FILE="${1:-}"

mkdir -p "${BASE_DIR}"

if [ -n "${INPUT_FILE}" ]; then
  BACKUP_FILE="${INPUT_FILE}"
else
  BACKUP_FILE=$(ls -1t "${BASE_DIR}"/*.tar.gz 2>/dev/null | head -n 1 || true)
fi

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "[ERRO] backup nao encontrado"
  exit 1
fi

TMP_DIR=$(mktemp -d)
tar -xzf "${BACKUP_FILE}" -C "${TMP_DIR}"

SNAPSHOT_DIR=$(find "${TMP_DIR}" -maxdepth 1 -type d -name 'snapshot_*' | head -n 1)

if [ -z "${SNAPSHOT_DIR}" ]; then
  echo "[ERRO] snapshot invalido no backup"
  rm -rf "${TMP_DIR}"
  exit 1
fi

rm -rf logs/state logs/history
mkdir -p logs

cp -R "${SNAPSHOT_DIR}/state" logs/state
cp -R "${SNAPSHOT_DIR}/history" logs/history

rm -rf "${TMP_DIR}"

echo "[OK] restore concluido a partir de ${BACKUP_FILE}"
echo
echo "===== STATE ====="
ls -l logs/state
echo
echo "===== HISTORY ====="
ls -l logs/history
