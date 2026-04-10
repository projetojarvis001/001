#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATE_FILE="logs/state/auto_heal_state.json"

echo "===== DIAGNOSTICO ATUAL ====="
./scripts/diagnose_stack.sh | jq .
echo

echo "===== AUTO HEAL STATE ====="
if [ -f "${STATE_FILE}" ]; then
  cat "${STATE_FILE}" | jq .
else
  echo "[INFO] sem estado de auto-heal"
fi
echo

echo "===== ULTIMOS LOGS ====="
ls -1t logs/autoheal/ 2>/dev/null | head -n 5 | while read f; do
  echo "--- ${f} ---"
  tail -n 30 "logs/autoheal/${f}"
  echo
done
