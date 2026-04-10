#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-$(ls -1t logs/executive/phase79_vision_observability_*.json 2>/dev/null | head -n 1 || true)}"

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] observability file nao encontrado"
  exit 1
fi

echo "===== PHASE 79 VISION EXEC REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== LIVE CAPABILITIES =====",
(.observability.live_capabilities | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== COUNTERS =====",
(.observability.counters | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== LATENCY =====",
(.observability.latency | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SCORE =====",
(.score | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== GOVERNANCE =====",
(.governance | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio executivo do vision emitido"
