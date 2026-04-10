#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase77_vision_policy_evidence_${TS}.json"
OUT_MD="docs/generated/phase77_vision_policy_evidence_${TS}.md"

RESULT_QUALITY="$(ls -1t runtime/vision/policy/out/policy_result_*_quality.json 2>/dev/null | head -n 1 || true)"
RESULT_SPEED="$(ls -1t runtime/vision/policy/out/policy_result_*_speed.json 2>/dev/null | head -n 1 || true)"

if [ -z "${RESULT_QUALITY}" ] || [ -z "${RESULT_SPEED}" ]; then
  echo "[ERRO] result files de policy nao encontrados"
  exit 1
fi

POLICY_Q="$(jq -r '.policy_used // ""' "${RESULT_QUALITY}")"
ROUTE_Q="$(jq -r '.chosen_route // ""' "${RESULT_QUALITY}")"
CLASS_Q="$(jq -r '.classification // ""' "${RESULT_QUALITY}")"

POLICY_S="$(jq -r '.policy_used // ""' "${RESULT_SPEED}")"
ROUTE_S="$(jq -r '.chosen_route // ""' "${RESULT_SPEED}")"
CLASS_S="$(jq -r '.classification // ""' "${RESULT_SPEED}")"

FLOW_OK=false
if [ "${POLICY_Q}" = "quality_first" ] && [ "${ROUTE_Q}" = "route_primary_simulated" ] && \
   [ "${POLICY_S}" = "speed_first" ] && [ "${ROUTE_S}" = "route_secondary_simulated" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg result_quality "${RESULT_QUALITY}" \
  --arg result_speed "${RESULT_SPEED}" \
  --arg policy_q "${POLICY_Q}" \
  --arg route_q "${ROUTE_Q}" \
  --arg class_q "${CLASS_Q}" \
  --arg policy_s "${POLICY_S}" \
  --arg route_s "${ROUTE_S}" \
  --arg class_s "${CLASS_S}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    policy_flow: {
      quality_case: {
        result_file: $result_quality,
        policy_used: $policy_q,
        chosen_route: $route_q,
        classification: $class_q
      },
      speed_case: {
        result_file: $result_speed,
        policy_used: $policy_s,
        chosen_route: $route_s,
        classification: $class_s
      },
      routing_policy_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 77 — Vision Policy Evidence

## Quality Case
- policy_used: ${POLICY_Q}
- chosen_route: ${ROUTE_Q}
- classification: ${CLASS_Q}

## Speed Case
- policy_used: ${POLICY_S}
- chosen_route: ${ROUTE_S}
- classification: ${CLASS_S}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] policy evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
