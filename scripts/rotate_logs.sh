#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

BASE_DIR="logs"
HOT_DAYS=7
RETENTION_DAYS=30

echo "===== LOG ROTATION ====="
date
echo

mkdir -p "${BASE_DIR}"

# Diretórios elegíveis para rotação
TARGET_DIRS=(
  "${BASE_DIR}/alerts"
  "${BASE_DIR}/autoheal"
  "${BASE_DIR}/chaos"
  "${BASE_DIR}/ops"
  "${BASE_DIR}/stack_health"
)

for dir in "${TARGET_DIRS[@]}"; do
  [ -d "${dir}" ] || continue

  echo "===== PROCESSANDO: ${dir} ====="

  # Comprimir logs mais antigos que HOT_DAYS e ainda não comprimidos
  find "${dir}" -type f \
    ! -name '*.gz' \
    -mtime +"${HOT_DAYS}" \
    -print | while read -r f; do
      gzip -f "$f"
      echo "[GZIP] $f"
    done

  # Apagar logs comprimidos mais antigos que RETENTION_DAYS
  find "${dir}" -type f -name '*.gz' -mtime +"${RETENTION_DAYS}" -print | while read -r f; do
    rm -f "$f"
    echo "[DEL] $f"
  done

  # Apagar logs não comprimidos muito antigos caso algum tenha escapado
  find "${dir}" -type f ! -name '*.gz' -mtime +"${RETENTION_DAYS}" -print | while read -r f; do
    rm -f "$f"
    echo "[DEL] $f"
  done

  echo
done

echo "===== RESUMO DE USO ====="
du -sh logs/* 2>/dev/null || true
echo
echo "[OK] rotacao concluida"
