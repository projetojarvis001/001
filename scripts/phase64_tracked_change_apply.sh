#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p docs/generated logs/executive
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase64_tracked_change_${TS}.json"
OUT_MD="docs/generated/phase64_tracked_change_${TS}.md"
TARGET_FILE="docs/generated/devops_agent_tracked_probe.md"

BEFORE_EXISTS=false
[ -f "${TARGET_FILE}" ] && BEFORE_EXISTS=true

if [ ! -f "${TARGET_FILE}" ]; then
  cat > "${TARGET_FILE}" <<'MD'
# DevOps Agent Tracked Probe

Arquivo rastreável para mudanças mínimas controladas do DevOps Agent.
MD
fi

CHANGE_LINE="- phase64_tracked_change_applied_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
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
      type: "tracked_minimal_write",
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

echo "[OK] tracked change gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
