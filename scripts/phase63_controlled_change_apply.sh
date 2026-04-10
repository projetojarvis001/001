#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase63_controlled_change_${TS}.json"
OUT_MD="docs/generated/phase63_controlled_change_${TS}.md"

TARGET_FILE="runtime/devops_agent_controlled_change.log"
CHANGE_LINE="phase63_controlled_change_applied_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

BEFORE_EXISTS=false
[ -f "${TARGET_FILE}" ] && BEFORE_EXISTS=true

printf '%s\n' "${CHANGE_LINE}" >> "${TARGET_FILE}"

AFTER_EXISTS=false
[ -f "${TARGET_FILE}" ] && AFTER_EXISTS=true

LAST_LINE="$(tail -n 1 "${TARGET_FILE}" 2>/dev/null || true)"
FILE_SHA="$(shasum -a 256 "${TARGET_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg target_file "${TARGET_FILE}" \
  --arg last_line "${LAST_LINE}" \
  --arg file_sha "${FILE_SHA}" \
  --argjson before_exists "${BEFORE_EXISTS}" \
  --argjson after_exists "${AFTER_EXISTS}" \
  '{
    created_at: $created_at,
    change: {
      type: "controlled_minimal_write",
      target_file: $target_file,
      before_exists: $before_exists,
      after_exists: $after_exists,
      last_line: $last_line,
      file_sha256: $file_sha
    },
    governance: {
      deploy_executed: false,
      push_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 63 — Controlled Change Apply

## Mudança
- type: controlled_minimal_write
- target_file: ${TARGET_FILE}
- before_exists: ${BEFORE_EXISTS}
- after_exists: ${AFTER_EXISTS}

## Última linha gravada
- ${LAST_LINE}

## Hash
- ${FILE_SHA}

## Governança
- deploy_executed: false
- push_executed: false
- production_changed: false
MD

echo "[OK] controlled change gerado em ${OUT_JSON}"
echo "[OK] markdown do controlled change gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
