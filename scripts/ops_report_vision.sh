#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/ops"
OUT_FILE="${OUT_DIR}/vision_ops_${STAMP}.log"

mkdir -p "${OUT_DIR}"

{
  echo "===== DATA ====="
  date
  echo

  if ! command -v docker >/dev/null 2>&1; then
  echo "[ERRO] docker nao encontrado no PATH"
  exit 1
fi

echo "===== GIT ====="
  git log --oneline -n 3
  echo

  echo "===== CONTAINERS ====="
  docker ps --format 'table {{.Names}}\t{{.Status}}'
  echo

  echo "===== STACK HEALTH ====="
  curl -fsS http://127.0.0.1:3000/stack/health
  echo
  echo

  echo "===== VALIDACAO FASE 6 ====="
  ./scripts/validate_fase6.sh
  echo

  echo "===== LOGS CORE ====="
  docker logs --tail 120 jarvis-jarvis-core-1 2>&1
  echo

  echo "===== FIM ====="
} | tee "${OUT_FILE}"

echo
echo "[OK] relatorio salvo em ${OUT_FILE}"
