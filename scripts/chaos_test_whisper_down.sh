#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/chaos"
OUT_FILE="${OUT_DIR}/chaos_whisper_down_${STAMP}.log"
ENV_FILE=".env"
BACKUP_FILE=".env.bak.whisper.${STAMP}"

mkdir -p "${OUT_DIR}" logs/state
cp "${ENV_FILE}" "${BACKUP_FILE}"

restore_env() {
  cp "${BACKUP_FILE}" "${ENV_FILE}"
  docker compose build --no-cache jarvis-core >/dev/null 2>&1 || true
  docker compose up -d >/dev/null 2>&1 || true

  for i in $(seq 1 24); do
    if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  for i in $(seq 1 24); do
    if curl -fsS http://127.0.0.1:3000/stack/health >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
}
trap restore_env EXIT

python3 - <<'PY'
from pathlib import Path
import re
p = Path(".env")
txt = p.read_text()
txt = re.sub(r'^VISION_WHISPER_URL=.*$', 'VISION_WHISPER_URL=http://127.0.0.1:5997', txt, flags=re.M)
p.write_text(txt)
print("[OK] whisper sabotado")
PY

START_TS=$(date +%s)

for i in $(seq 1 24); do
  if curl -fsS http://127.0.0.1:3000/stack/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

{
  echo "===== CHAOS TEST WHISPER DOWN ====="
  date
  echo

  echo "===== RESET STATES ====="
  cat > logs/state/alert_state.json <<'JSON'
{
  "last_alert_key": "",
  "last_alert_at": 0,
  "last_severity": "",
  "repeat_count": 0,
  "last_recovery_at": 0
}
JSON

  cat > logs/state/auto_heal_state.json <<'JSON'
{
  "last_attempt_epoch": 0,
  "attempt_count_window": 0,
  "window_start_epoch": 0,
  "last_action": "",
  "last_result": "",
  "last_diagnosis_kind": "",
  "last_diagnosis_detail": "",
  "last_command": "",
  "last_duration_seconds": 0,
  "last_exit_code": 0,
  "postcheck_ok": false
}
JSON
  echo "[OK] estados resetados"
  echo

  echo "===== REBUILD CORE ====="
  docker compose build --no-cache jarvis-core
  docker compose up -d
  sleep 15
  echo

  echo "===== DIAGNOSTICO ====="
  ./scripts/diagnose_stack.sh | jq .
  echo

  echo "===== CLASSIFICADOR ====="
  ./scripts/classify_stack_alert.sh | jq .
  echo

  echo "===== CHECK ALERT ====="
  ./scripts/check_stack_alert.sh || true
  echo

  echo "===== AUTO HEAL ====="
  cat logs/state/auto_heal_state.json | jq .
  echo

  echo "===== ALERT STATE ====="
  cat logs/state/alert_state.json | jq .
  echo

  echo "===== STACK HEALTH ====="
  curl -s http://127.0.0.1:3000/stack/health | jq .
  echo
} | tee "${OUT_FILE}"

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
echo "[OK] chaos whisper down concluido em ${DURATION}s" | tee -a "${OUT_FILE}"
