#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATE_FILE="logs/state/auto_heal_state.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "[ERRO] arquivo nao encontrado: ${STATE_FILE}"
  exit 1
fi

echo "===== AUTO HEAL STATE ====="
cat "${STATE_FILE}"
echo

echo "===== ULTIMOS LOGS ====="
ls -1t logs/autoheal/ 2>/dev/null | head -n 3 | while read f; do
  echo "--- ${f} ---"
  tail -n 40 "logs/autoheal/${f}"
  echo
done
