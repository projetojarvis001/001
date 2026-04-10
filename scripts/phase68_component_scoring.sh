#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase68_component_scoring_${TS}.json"
OUT_MD="docs/generated/phase68_component_scoring_${TS}.md"

LATEST_PACKET="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
LATEST_STATUS="$(ls -1t logs/executive/devops_agent_status_*.json 2>/dev/null | head -n 1 || true)"
LATEST_RELIABILITY="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
LATEST_PHASE66_PACKET="$(ls -1t logs/executive/phase66_devops_packet_*.json 2>/dev/null | head -n 1 || true)"

OP_SCORE="$(jq -r '.operational_discipline.score // 0' "${LATEST_PACKET}" 2>/dev/null || echo 0)"
REL_SCORE="$(jq -r '.latest_release.reliability_score // 0' "${LATEST_PACKET}" 2>/dev/null || echo 0)"
DEVOPS_READY="$(jq -r '.decision.agent_ready // false' "${LATEST_STATUS}" 2>/dev/null || echo false)"
DOCKER_OK="$(jq -r '.runtime.docker_daemon_ok // false' "${LATEST_STATUS}" 2>/dev/null || echo false)"
REMOTE_MATCH="$(jq -r '.summary.remote_match // false' "${LATEST_PHASE66_PACKET}" 2>/dev/null || echo false)"

JARVIS_SCORE="8.2"
VISION_SCORE="6.4"
FRIDAY_SCORE="5.8"
ODOO_SCORE="2.5"

if [ "${DEVOPS_READY}" = "true" ] && [ "${DOCKER_OK}" = "true" ] && [ "${REMOTE_MATCH}" = "true" ]; then
  JARVIS_SCORE="8.6"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg latest_packet "${LATEST_PACKET}" \
  --arg latest_status "${LATEST_STATUS}" \
  --arg latest_reliability "${LATEST_RELIABILITY}" \
  --argjson op_score "${OP_SCORE}" \
  --argjson rel_score "${REL_SCORE}" \
  --argjson jarvis_score "${JARVIS_SCORE}" \
  --argjson vision_score "${VISION_SCORE}" \
  --argjson friday_score "${FRIDAY_SCORE}" \
  --argjson odoo_score "${ODOO_SCORE}" \
  '{
    created_at: $created_at,
    sources: {
      latest_packet: $latest_packet,
      latest_status: $latest_status,
      latest_reliability: $latest_reliability
    },
    executive_inputs: {
      operational_score: $op_score,
      release_reliability_score: $rel_score
    },
    components: [
      {
        component: "JARVIS",
        current_score: $jarvis_score,
        target_score: 10,
        gap: (10 - $jarvis_score),
        status: "FORTE_COM_LACUNAS"
      },
      {
        component: "VISION",
        current_score: $vision_score,
        target_score: 10,
        gap: (10 - $vision_score),
        status: "INTERMEDIARIO"
      },
      {
        component: "FRIDAY",
        current_score: $friday_score,
        target_score: 10,
        gap: (10 - $friday_score),
        status: "EM_ESTRUTURACAO"
      },
      {
        component: "ODOO",
        current_score: $odoo_score,
        target_score: 10,
        gap: (10 - $odoo_score),
        status: "MAPEAMENTO_INICIAL"
      }
    ],
    decision: {
      operator_note: "JARVIS esta mais perto do 10/10. VISION e FRIDAY ainda exigem subida funcional. ODOO ainda esta em reconhecimento."
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 68 — Scoring Atual por Componente

## Scores atuais estimados
- JARVIS: ${JARVIS_SCORE}/10
- VISION: ${VISION_SCORE}/10
- FRIDAY: ${FRIDAY_SCORE}/10
- ODOO: ${ODOO_SCORE}/10

## Leitura
- JARVIS é o mais maduro
- VISION precisa virar agente vivo
- FRIDAY precisa ganhar presença real
- ODOO ainda está em fase de mapeamento
MD

echo "[OK] scoring por componente gerado em ${OUT_JSON}"
echo "[OK] markdown do scoring gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
