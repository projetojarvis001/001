#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/chaos"
OUT_FILE="${OUT_DIR}/chaos_core_down_${STAMP}.log"

mkdir -p "${OUT_DIR}" logs/state

START_TS=$(date +%s)

{
  echo "===== CHAOS TEST CORE DOWN ====="
  date
  echo

  echo "===== PRECHECK ====="
  curl -fsS http://127.0.0.1:3000/stack/health | jq .
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
  "last_exit_code": 0
}
JSON

  echo "[OK] estados resetados"
  echo

  echo "===== STOP CORE ====="
  docker stop jarvis-jarvis-core-1
  sleep 5
  docker ps -a --format 'table {{.Names}}\t{{.Status}}' | grep jarvis-jarvis-core-1 || true
  echo

  echo "===== CHECK ALERT ====="
  ./scripts/check_stack_alert.sh || true
  echo

  echo "===== AGUARDA RECUPERACAO ====="
  for i in $(seq 1 18); do
    if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
      echo "[OK] core respondeu no ciclo ${i}"
      break
    fi
    sleep 5
  done
  echo

  echo "===== POSCHECK ====="
  curl -fsS http://127.0.0.1:3000/stack/health | jq .
  echo

  echo "===== AUTO HEAL STATE ====="
  cat logs/state/auto_heal_state.json | jq .
  echo

  echo "===== ALERT STATE ====="
  cat logs/state/alert_state.json | jq .
  echo

} | tee "${OUT_FILE}"

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
echo "[OK] chaos core down concluido em ${DURATION}s" | tee -a "${OUT_FILE}"
