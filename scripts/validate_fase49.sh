#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 49 ====="

echo
echo "===== PREP SCORE ====="
./scripts/operational_score_daily.sh >/tmp/f49_score.out

echo
echo "===== UPDATE HISTORY ====="
./scripts/operational_score_history_update.sh

HISTORY_FILE="logs/executive/operational_score_history.json"
if [ ! -f "${HISTORY_FILE}" ]; then
  echo "[ERRO] historico nao criado"
  exit 1
fi

echo
echo "===== CHECK JSON ====="
jq -e 'type == "array"' "${HISTORY_FILE}" >/dev/null
jq -e 'length >= 1' "${HISTORY_FILE}" >/dev/null
jq -e '.[-1].reference_day != null' "${HISTORY_FILE}" >/dev/null
jq -e '.[-1].final_score >= 0 and .[-1].final_score <= 100' "${HISTORY_FILE}" >/dev/null
jq -e '.[-1].grade != null' "${HISTORY_FILE}" >/dev/null
jq -e '.[-1].status != null' "${HISTORY_FILE}" >/dev/null
echo "[OK] historico consistente"

echo
echo "===== CHECK IDEMPOTENCIA ====="
BEFORE_COUNT="$(jq 'length' "${HISTORY_FILE}")"
./scripts/operational_score_history_update.sh >/tmp/f49_history_rerun.out
AFTER_COUNT="$(jq 'length' "${HISTORY_FILE}")"

if [ "${BEFORE_COUNT}" != "${AFTER_COUNT}" ]; then
  echo "[ERRO] historico duplicou o mesmo dia"
  exit 1
fi
echo "[OK] update idempotente"

echo
echo "===== REPORT ====="
./scripts/operational_score_history_report.sh "${HISTORY_FILE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/operational_score_history_update.sh
bash -n scripts/operational_score_history_report.sh
bash -n scripts/validate_fase49.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 49 validada"
