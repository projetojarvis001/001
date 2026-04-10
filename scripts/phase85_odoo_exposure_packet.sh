#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase85_odoo_exposure_packet_${TS}.json"
OUT_MD="docs/generated/phase85_odoo_exposure_packet_${TS}.md"

PROBE_FILE="$(ls -1t logs/executive/phase85_odoo_exposure_probe_*.json 2>/dev/null | head -n 1 || true)"
EXT_FILE="$(ls -1t logs/executive/phase85_odoo_external_check_*.json 2>/dev/null | head -n 1 || true)"
PACKET84="$(ls -1t logs/executive/phase84_odoo_surface_packet_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${PROBE_FILE}" ] || [ -z "${EXT_FILE}" ] || [ -z "${PACKET84}" ]; then
  echo "[ERRO] arquivos da fase 85 nao encontrados"
  exit 1
fi

HAS_8069_GLOBAL="$(jq -r '.exposure_probe.has_8069_global // false' "${PROBE_FILE}")"
HAS_5432_GLOBAL="$(jq -r '.exposure_probe.has_5432_global // false' "${PROBE_FILE}")"
HAS_5432_LOCAL="$(jq -r '.exposure_probe.has_5432_local // false' "${PROBE_FILE}")"
NGINX_FOUND="$(jq -r '.exposure_probe.nginx_found // false' "${PROBE_FILE}")"
APACHE_FOUND="$(jq -r '.exposure_probe.apache_found // false' "${PROBE_FILE}")"
PROXY_PASS_FOUND="$(jq -r '.exposure_probe.proxy_pass_found // false' "${PROBE_FILE}")"
HAS_58069_LISTEN="$(jq -r '.exposure_probe.has_58069_listen // false' "${PROBE_FILE}")"
HTTP_200="$(jq -r '.external_check.http_200 // false' "${EXT_FILE}")"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 5.3' "${PACKET84}")"

EXPOSURE_CLEAR=false
if [ "${HAS_5432_GLOBAL}" = "false" ] && [ "${HAS_5432_LOCAL}" = "true" ] && [ "${HTTP_200}" = "true" ]; then
  EXPOSURE_CLEAR=true
fi

PROXY_MODE="unknown"
if [ "${NGINX_FOUND}" = "true" ] || [ "${APACHE_FOUND}" = "true" ] || [ "${PROXY_PASS_FOUND}" = "true" ]; then
  PROXY_MODE="reverse_proxy_present"
elif [ "${HAS_58069_LISTEN}" = "true" ]; then
  PROXY_MODE="port_binding_present"
else
  PROXY_MODE="direct_or_undetermined"
fi

RISK_AFTER="MEDIUM"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

if [ "${EXPOSURE_CLEAR}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 0.7, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg probe_file "${PROBE_FILE}" \
  --arg ext_file "${EXT_FILE}" \
  --arg proxy_mode "${PROXY_MODE}" \
  --arg risk_after "${RISK_AFTER}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  --argjson has_8069_global "${HAS_8069_GLOBAL}" \
  --argjson has_5432_global "${HAS_5432_GLOBAL}" \
  --argjson has_5432_local "${HAS_5432_LOCAL}" \
  --argjson exposure_clear "${EXPOSURE_CLEAR}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_85_ODOO_EXPOSURE_VERIFICATION",
      proxy_mode: $proxy_mode,
      has_8069_global: $has_8069_global,
      has_5432_global: $has_5432_global,
      has_5432_local: $has_5432_local,
      exposure_clear: $exposure_clear,
      risk_after: $risk_after,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO agora tem diagnostico claro de exposicao e proxy."
    },
    sources: {
      probe_file: $probe_file,
      external_file: $ext_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 85 — ODOO Exposure Packet

## Summary
- proxy_mode: ${PROXY_MODE}
- has_8069_global: ${HAS_8069_GLOBAL}
- has_5432_global: ${HAS_5432_GLOBAL}
- has_5432_local: ${HAS_5432_LOCAL}
- exposure_clear: ${EXPOSURE_CLEAR}
- risk_after: ${RISK_AFTER}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] exposure packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
