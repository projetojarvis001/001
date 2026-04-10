#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/readiness/readiness_safe_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um readiness_safe valido"
  exit 1
fi

echo "===== READINESS SAFE REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"MODE=" + (.mode // ""),
"READINESS=" + (.readiness // ""),
"RECOMENDACAO=" + (.executive_recommendation // ""),
"SCORE=" + (.score|tostring) + "/" + (.max_score|tostring),
"",
"===== CHECKS =====",
(.checks | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== OBSERVABILITY =====",
(.observability | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== ARTIFACTS =====",
(.artifacts | to_entries[] | (.key + "=" + .value))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio safe emitido"
