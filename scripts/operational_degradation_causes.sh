#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/operational_degradation_causes_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

SCORE_FILE="$(ls -1t logs/executive/operational_score_[0-9]*.json 2>/dev/null | head -n 1 || true)"
RELIABILITY_FILE="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
PACKET_FILE="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
SEMAPHORE_FILE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"

for f in "${SCORE_FILE}" "${RELIABILITY_FILE}" "${PACKET_FILE}" "${SEMAPHORE_FILE}"; do
  if [ -z "${f}" ] || [ ! -f "${f}" ]; then
    echo "[ERRO] artefato obrigatorio ausente: ${f}"
    exit 1
  fi
done

TMP_ITEMS="/tmp/operational_degradation_causes_$$.jsonl"
rm -f "${TMP_ITEMS}"
touch "${TMP_ITEMS}"

add_cause() {
  local cause="$1"
  local weight="$2"
  local scope="$3"
  local source="$4"
  local note="$5"

  jq -nc \
    --arg cause "${cause}" \
    --argjson weight "${weight}" \
    --arg scope "${scope}" \
    --arg source "${source}" \
    --arg note "${note}" \
    '{
      cause: $cause,
      weight: $weight,
      scope: $scope,
      source: $source,
      note: $note
    }' >> "${TMP_ITEMS}"
}

DAY_RISK="$(jq -r '.counters.risk_releases // 0' "${SCORE_FILE}")"
DAY_BLOCKED="$(jq -r '.counters.blocked_releases // 0' "${SCORE_FILE}")"
DAY_ROLLBACK="$(jq -r '.counters.rollback_releases // 0' "${SCORE_FILE}")"
DAY_FREEZE="$(jq -r '.context.freeze_active // false' "${SCORE_FILE}")"
DAY_STACK_OK="$(jq -r '.context.stack_ok // true' "${SCORE_FILE}")"

REL_RISK="$(jq -r '.context.risk_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_WINDOW="$(jq -r '.context.window_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_APPROVAL="$(jq -r '.context.approval_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_POST="$(jq -r '.context.post_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_ROLLBACK="$(jq -r '.context.rollback_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_DEPLOY="$(jq -r '.context.deploy_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_SEMAPHORE="$(jq -r '.context.semaphore_status // "UNKNOWN"' "${RELIABILITY_FILE}")"

PACKET_SIGNAL="$(jq -r '.decision.executive_signal // "UNKNOWN"' "${PACKET_FILE}")"

if [ "${DAY_RISK}" -gt 0 ]; then
  add_cause "risk_release" 10 "day" "$(basename "${SCORE_FILE}")" "Dia teve liberacoes com risco controlado."
fi

if [ "${DAY_BLOCKED}" -gt 0 ]; then
  add_cause "blocked_release" 20 "day" "$(basename "${SCORE_FILE}")" "Dia teve releases bloqueadas."
fi

if [ "${DAY_ROLLBACK}" -gt 0 ]; then
  add_cause "rollback_release" 25 "day" "$(basename "${SCORE_FILE}")" "Dia teve rollback registrado."
fi

if [ "${DAY_FREEZE}" = "true" ]; then
  add_cause "freeze_active" 30 "day" "$(basename "${SCORE_FILE}")" "Freeze operacional ativo."
fi

if [ "${DAY_STACK_OK}" != "true" ]; then
  add_cause "stack_not_ok" 30 "day" "$(basename "${SCORE_FILE}")" "Stack nao estava saudavel."
fi

if [ "${REL_RISK}" = "LIBERAR_COM_RISCO" ]; then
  add_cause "release_with_risk" 10 "release" "$(basename "${RELIABILITY_FILE}")" "Ultima release exigiu liberacao com risco."
fi

if [ "${REL_WINDOW}" = "OVERRIDE" ]; then
  add_cause "window_override" 5 "release" "$(basename "${RELIABILITY_FILE}")" "Ultima release ocorreu com override de janela."
fi

if [ "${REL_APPROVAL}" = "VALID" ]; then
  add_cause "exception_approval" 5 "release" "$(basename "${RELIABILITY_FILE}")" "Ultima release exigiu aprovacao excepcional."
fi

case "${REL_SEMAPHORE}" in
  YELLOW) add_cause "yellow_semaphore" 10 "release" "$(basename "${SEMAPHORE_FILE}")" "Semaforo executivo amarelo." ;;
  RED) add_cause "red_semaphore" 25 "release" "$(basename "${SEMAPHORE_FILE}")" "Semaforo executivo vermelho." ;;
  BLACK) add_cause "black_semaphore" 40 "release" "$(basename "${SEMAPHORE_FILE}")" "Semaforo executivo preto." ;;
esac

if [ "${REL_POST}" = "FAIL" ]; then
  add_cause "post_deploy_fail" 30 "release" "$(basename "${RELIABILITY_FILE}")" "Falha no pos-deploy."
fi

case "${REL_ROLLBACK}" in
  EXECUTADO|ROLLBACK_EXECUTADO) add_cause "rollback_executado" 25 "release" "$(basename "${RELIABILITY_FILE}")" "Rollback executado apos release." ;;
  FALHOU|ROLLBACK_FALHOU) add_cause "rollback_falhou" 50 "release" "$(basename "${RELIABILITY_FILE}")" "Rollback falhou apos release." ;;
esac

if [ "${REL_DEPLOY}" != "EXECUTADO" ]; then
  add_cause "deploy_not_executed" 100 "release" "$(basename "${RELIABILITY_FILE}")" "Deploy nao foi executado."
fi

if [ ! -s "${TMP_ITEMS}" ]; then
  add_cause "no_material_degradation" 0 "system" "$(basename "${PACKET_FILE}")" "Sem degradadores materiais detectados."
fi

MAIN_DRIVER="$(jq -r -s 'sort_by(-.weight, .cause) | .[0].cause // "none"' "${TMP_ITEMS}")"
MAIN_WEIGHT="$(jq -s 'sort_by(-.weight, .cause) | .[0].weight // 0' "${TMP_ITEMS}")"

jq -s \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg executive_signal "${PACKET_SIGNAL}" \
  --arg main_driver "${MAIN_DRIVER}" \
  --argjson main_weight "${MAIN_WEIGHT}" \
  '{
    created_at: $created_at,
    executive_signal: $executive_signal,
    top_causes: (sort_by(-.weight, .cause)),
    decision: {
      main_driver: $main_driver,
      operator_note:
        (if $main_driver == "no_material_degradation" then
          "Nao houve degradador material relevante no ciclo atual."
         elif $main_driver == "risk_release" or $main_driver == "release_with_risk" then
          "Principal degradador foi a liberacao com risco."
         elif $main_driver == "window_override" or $main_driver == "exception_approval" then
          "Principal degradador foi governanca excepcional de liberacao."
         elif $main_driver == "yellow_semaphore" or $main_driver == "red_semaphore" or $main_driver == "black_semaphore" then
          "Principal degradador foi o semaforo executivo."
         elif $main_driver == "rollback_executado" or $main_driver == "rollback_falhou" then
          "Principal degradador foi evento de rollback."
         elif $main_driver == "post_deploy_fail" then
          "Principal degradador foi falha no pos-deploy."
         else
          "Principal degradador operacional identificado no ranking."
         end)
    }
  }' "${TMP_ITEMS}" > "${OUT_FILE}"

rm -f "${TMP_ITEMS}"

echo "[OK] causas de degradacao geradas em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
