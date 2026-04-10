#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-logs/executive/audit_bundle_index.json}"

if [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] indice de auditoria nao encontrado"
  exit 1
fi

echo "===== AUDIT BUNDLE INDEX REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"TOTAL_BUNDLES=" + (length|tostring),
"",
"===== REGISTROS =====",
(if length == 0
 then "nenhum_bundle"
 else .[] | (
   (.reference_day // "") + " | signal=" + (.executive_signal // "") +
   " | go_live=" + (.go_live_status // "") +
   " | op_score=" + (.operational_score|tostring) +
   " | rel_score=" + (.release_reliability_score|tostring) +
   " | archive_ok=" + (.archive_ok|tostring)
 )
 end)
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do indice emitido"
