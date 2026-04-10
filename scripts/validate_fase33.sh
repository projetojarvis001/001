#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 33 ====="

METRICS_BEFORE="/tmp/fase33_stack_metrics_before.json"
HISTORY_BEFORE="/tmp/fase33_stack_history_before.json"

cp logs/state/stack_metrics.json "${METRICS_BEFORE}"
cp logs/history/stack_daily_history.json "${HISTORY_BEFORE}"

echo
echo "===== READINESS STRICT ====="
./scripts/readiness_gate_strict.sh

LATEST_STRICT=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)

if [ -z "${LATEST_STRICT}" ] || [ ! -f "${LATEST_STRICT}" ]; then
  echo "[ERRO] readiness strict nao encontrado"
  exit 1
fi

echo "[OK] readiness strict selecionado: ${LATEST_STRICT}"

echo
echo "===== CHECK JSON ====="
jq -e '.mode == "STRICT_FRESHNESS_POLICY"' "${LATEST_STRICT}" >/dev/null
jq -e '.freshness != null' "${LATEST_STRICT}" >/dev/null
jq -e '.freshness_policy != null' "${LATEST_STRICT}" >/dev/null
jq -e '.checks.chaos_fresh_ok != null' "${LATEST_STRICT}" >/dev/null
jq -e '.checks.redis_backup_ok != null' "${LATEST_STRICT}" >/dev/null
echo "[OK] readiness strict consistente"

echo
echo "===== REPORT ====="
./scripts/readiness_report_strict.sh "${LATEST_STRICT}"

echo
echo "===== DASHBOARD EXECUTIVO ====="
./scripts/build_executive_ops_dashboard.sh
jq -e '.artifacts.readiness_file | contains("readiness_strict_")' logs/executive/executive_ops_dashboard.json >/dev/null
echo "[OK] dashboard usando readiness strict"

echo
echo "===== CHECK SEM CONTAMINAR METRICAS ====="

BEFORE_DATE=$(jq -r '.date' "${METRICS_BEFORE}")
BEFORE_DOWN=$(jq -r '.down_count' "${METRICS_BEFORE}")
BEFORE_TOTAL=$(jq -r '.total_downtime_seconds' "${METRICS_BEFORE}")
BEFORE_LAST=$(jq -r '.last_downtime_seconds' "${METRICS_BEFORE}")

AFTER_DATE=$(jq -r '.date' logs/state/stack_metrics.json)
AFTER_DOWN=$(jq -r '.down_count' logs/state/stack_metrics.json)
AFTER_TOTAL=$(jq -r '.total_downtime_seconds' logs/state/stack_metrics.json)
AFTER_LAST=$(jq -r '.last_downtime_seconds' logs/state/stack_metrics.json)

[ "${BEFORE_DATE}" = "${AFTER_DATE}" ] || { echo "[ERRO] data contaminada"; exit 1; }
[ "${BEFORE_DOWN}" = "${AFTER_DOWN}" ] || { echo "[ERRO] down_count contaminado"; exit 1; }
[ "${BEFORE_TOTAL}" = "${AFTER_TOTAL}" ] || { echo "[ERRO] total_downtime_seconds contaminado"; exit 1; }
[ "${BEFORE_LAST}" = "${AFTER_LAST}" ] || { echo "[ERRO] last_downtime_seconds contaminado"; exit 1; }

cmp -s "${HISTORY_BEFORE}" logs/history/stack_daily_history.json
echo "[OK] validate_fase33 nao contaminou historico"

echo
echo "===== TESTE BLOQUEIO CHAOS VENCIDO ====="
CHAOS_LATEST=$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${CHAOS_LATEST}" ] || [ ! -f "${CHAOS_LATEST}" ]; then
  echo "[ERRO] sem chaos suite para testar"
  exit 1
fi

cp "${CHAOS_LATEST}" /tmp/fase33_chaos_backup.json

python3 - <<PY
import json
from pathlib import Path
p = Path("${CHAOS_LATEST}")
obj = json.loads(p.read_text())
obj["created_at"] = "2026-01-01T00:00:00Z"
p.write_text(json.dumps(obj, indent=2))
print("[OK] chaos suite envelhecida artificialmente")
PY

./scripts/readiness_gate_strict.sh
LATEST_STRICT_AGED=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1)

jq -e '.checks.chaos_json_ok == true' "${LATEST_STRICT_AGED}" >/dev/null
jq -e '.checks.chaos_fresh_ok == false' "${LATEST_STRICT_AGED}" >/dev/null
jq -e '.checks.chaos_ok == false' "${LATEST_STRICT_AGED}" >/dev/null
jq -e '.readiness == "BLOCKED"' "${LATEST_STRICT_AGED}" >/dev/null
echo "[OK] gate strict bloqueou chaos vencido"

cp /tmp/fase33_chaos_backup.json "${CHAOS_LATEST}"

echo
echo "===== TESTE BLOQUEIO REDIS AUSENTE ====="
REDIS_FILES=$(ls backups/redis/*.rdb 2>/dev/null | wc -l | tr -d ' ')
if [ "${REDIS_FILES}" = "0" ]; then
  echo "[ERRO] sem backups redis para testar"
  exit 1
fi

TMP_HOLD_DIR="/tmp/fase33_redis_hold"
rm -rf "${TMP_HOLD_DIR}"
mkdir -p "${TMP_HOLD_DIR}"

find backups/redis -maxdepth 1 -type f -name "*.rdb" -exec mv {} "${TMP_HOLD_DIR}/" \;

./scripts/readiness_gate_strict.sh
LATEST_STRICT_NORDIS=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1)

jq -e '.checks.redis_backup_ok == false' "${LATEST_STRICT_NORDIS}" >/dev/null
jq -e '.readiness == "BLOCKED"' "${LATEST_STRICT_NORDIS}" >/dev/null
echo "[OK] gate strict bloqueou ausencia real de backup redis"

find "${TMP_HOLD_DIR}" -maxdepth 1 -type f -name "*.rdb" -exec mv {} backups/redis/ \;
rmdir "${TMP_HOLD_DIR}" 2>/dev/null || true

echo
echo "[OK] fase 33 validada"
