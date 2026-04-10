#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 57 ====="

echo
echo "===== BUILD BUNDLE ====="
./scripts/daily_executive_bundle.sh

INDEX_FILE="$(ls -1t logs/executive/bundles/daily_bundle_*/index.json 2>/dev/null | head -n 1 || true)"
ARCHIVE_FILE="$(ls -1t logs/executive/bundles/daily_bundle_*.tar.gz 2>/dev/null | head -n 1 || true)"

if [ -z "${INDEX_FILE}" ] || [ ! -f "${INDEX_FILE}" ]; then
  echo "[ERRO] index do bundle ausente"
  exit 1
fi

if [ -z "${ARCHIVE_FILE}" ] || [ ! -f "${ARCHIVE_FILE}" ]; then
  echo "[ERRO] archive do bundle ausente"
  exit 1
fi

echo "INDEX_FILE=${INDEX_FILE}"
echo "ARCHIVE_FILE=${ARCHIVE_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.reference_day != null' "${INDEX_FILE}" >/dev/null
jq -e '.executive_signal != null' "${INDEX_FILE}" >/dev/null
jq -e '.files | length >= 9' "${INDEX_FILE}" >/dev/null
jq -e '.operational_score >= 0 and .operational_score <= 100' "${INDEX_FILE}" >/dev/null
jq -e '.release_reliability_score >= 0 and .release_reliability_score <= 100' "${INDEX_FILE}" >/dev/null
echo "[OK] index consistente"

echo
echo "===== CHECK FILES ====="
jq -e '.files[] | select(.name == "executive_ops_dashboard.json")' "${INDEX_FILE}" >/dev/null
jq -e '.files[] | select(.name | contains("daily_executive_packet_"))' "${INDEX_FILE}" >/dev/null
jq -e '.files[] | select(.name | contains("release_manifest_"))' "${INDEX_FILE}" >/dev/null
echo "[OK] arquivos criticos presentes"

echo
echo "===== CHECK ARCHIVE ====="
tar -tzf "${ARCHIVE_FILE}" >/dev/null
echo "[OK] archive valido"

echo
echo "===== REPORT ====="
./scripts/daily_executive_bundle_report.sh "${INDEX_FILE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/daily_executive_bundle.sh
bash -n scripts/daily_executive_bundle_report.sh
bash -n scripts/validate_fase57.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 57 validada"
