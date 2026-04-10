#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 60 ====="

echo
echo "===== UPDATE INDEX ====="
./scripts/audit_bundle_index_update.sh

INDEX_FILE="logs/executive/audit_bundle_index.json"
if [ ! -f "${INDEX_FILE}" ]; then
  echo "[ERRO] indice de auditoria nao foi gerado"
  exit 1
fi

echo "INDEX_FILE=${INDEX_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e 'type == "array"' "${INDEX_FILE}" >/dev/null
jq -e 'length >= 1' "${INDEX_FILE}" >/dev/null
jq -e '.[0].reference_day != null' "${INDEX_FILE}" >/dev/null
jq -e '.[0].bundle_dir != null' "${INDEX_FILE}" >/dev/null
jq -e '.[0].archive_file != null' "${INDEX_FILE}" >/dev/null
jq -e '.[0].index_sha256 != null' "${INDEX_FILE}" >/dev/null
jq -e '.[0].archive_ok == true or .[0].archive_ok == false' "${INDEX_FILE}" >/dev/null
echo "[OK] indice consistente"

echo
echo "===== CHECK CURRENT DAY ====="
jq -e '.[] | select(.reference_day == "2026-04-10")' "${INDEX_FILE}" >/dev/null
jq -e '.[] | select(.reference_day == "2026-04-10") | .archive_ok == true' "${INDEX_FILE}" >/dev/null
echo "[OK] bundle atual indexado"

echo
echo "===== CHECK IDEMPOTENCIA ====="
BEFORE_COUNT="$(jq 'length' "${INDEX_FILE}")"
./scripts/audit_bundle_index_update.sh >/tmp/f60_rerun.out
AFTER_COUNT="$(jq 'length' "${INDEX_FILE}")"
if [ "${BEFORE_COUNT}" != "${AFTER_COUNT}" ]; then
  echo "[ERRO] indice duplicou registros na reexecucao"
  exit 1
fi
echo "[OK] update idempotente"

echo
echo "===== REPORT ====="
./scripts/audit_bundle_index_report.sh "${INDEX_FILE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/audit_bundle_index_update.sh
bash -n scripts/audit_bundle_index_report.sh
bash -n scripts/validate_fase60.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 60 validada"
