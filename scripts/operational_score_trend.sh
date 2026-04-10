#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
HISTORY_FILE="${OUT_DIR}/operational_score_history.json"
OUT_FILE="${OUT_DIR}/operational_score_trend_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

if [ ! -f "${HISTORY_FILE}" ]; then
  echo "[ERRO] historico de score inexistente"
  exit 1
fi

jq empty "${HISTORY_FILE}" >/dev/null 2>&1 || {
  echo "[ERRO] historico invalido"
  exit 1
}

jq \
  --arg source_file "${HISTORY_FILE}" \
  '
  def avg(arr): if (arr|length) == 0 then 0 else ((arr|add) / (arr|length)) end;

  . as $all
  | ($all | length) as $n
  | ($all | map(.final_score)) as $scores
  | ($all | if length >= 3 then .[-3:] else . end) as $recent
  | ($recent | map(.final_score)) as $recent_scores
  | ($all | if length >= 6 then .[-6:-3] else [] end) as $prev_window
  | ($prev_window | map(.final_score)) as $prev_scores
  | (avg($recent_scores)) as $recent_avg
  | (avg($prev_scores)) as $prev_avg
  | (if ($prev_scores|length) == 0 then
       "STABLE"
     elif ($recent_avg - $prev_avg) >= 5 then
       "UP"
     elif ($prev_avg - $recent_avg) >= 5 then
       "DOWN"
     else
       "STABLE"
     end) as $trend
  | (if $recent_avg >= 95 then
       "EXCELENTE"
     elif $recent_avg >= 85 then
       "BOA"
     elif $recent_avg >= 70 then
       "ATENCAO"
     else
       "CRITICA"
     end) as $executive_band
  | {
      created_at: (now | todateiso8601),
      source_file: $source_file,
      summary: {
        total_days: $n,
        average_score_all: (avg($scores)),
        average_score_recent: $recent_avg,
        average_score_previous_window: $prev_avg,
        trend: $trend,
        executive_band: $executive_band
      },
      highlights: {
        best_day: (if $n > 0 then ($all | max_by(.final_score)) else {} end),
        worst_day: (if $n > 0 then ($all | min_by(.final_score)) else {} end),
        latest_day: (if $n > 0 then $all[-1] else {} end)
      },
      decision: {
        operator_note:
          (if $trend == "UP" then
             "Disciplina operacional em melhora."
           elif $trend == "DOWN" then
             "Disciplina operacional em deterioracao. Revisar mudancas e governanca."
           else
             "Disciplina operacional estavel."
           end)
      }
    }
  ' "${HISTORY_FILE}" > "${OUT_FILE}"

echo "[OK] tendencia de score gerada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
