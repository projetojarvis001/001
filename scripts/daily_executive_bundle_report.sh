#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/bundles/daily_bundle_*/index.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um index de bundle valido"
  exit 1
fi

echo "===== DAILY EXECUTIVE BUNDLE REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"REFERENCE_DAY=" + (.reference_day // ""),
"BUNDLE_DIR=" + (.bundle_dir // ""),
"ARCHIVE_FILE=" + (.archive_file // ""),
"EXECUTIVE_SIGNAL=" + (.executive_signal // ""),
"GO_LIVE_STATUS=" + (.go_live_status // ""),
"OPERATIONAL_SCORE=" + (.operational_score|tostring),
"RELEASE_RELIABILITY_SCORE=" + (.release_reliability_score|tostring),
"",
"===== FILES =====",
(.files[] | (.name + " | sha256=" + .sha256))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do bundle emitido"
