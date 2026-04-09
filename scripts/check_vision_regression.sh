#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


echo "===== CHECAGEM REGRESSAO VISION ====="

BAD_SRC=$(grep -RniE '11434/api|192\.168\.8\.124' core/src core/dashboard 2>/dev/null || true)
BAD_CONTAINER=$(docker exec jarvis-jarvis-core-1 sh -lc 'grep -RniE "11434/api|192\.168\.8\.124" /app/dist /app/dashboard 2>/dev/null || true' || true)

if [ -n "$BAD_SRC" ]; then
  echo "[ERRO] Encontrados hardcodes no fonte:"
  echo "$BAD_SRC"
  exit 1
fi

if [ -n "$BAD_CONTAINER" ]; then
  echo "[ERRO] Encontrados hardcodes no container:"
  echo "$BAD_CONTAINER"
  exit 1
fi

echo "[OK] sem hardcodes proibidos no fonte e no container"
