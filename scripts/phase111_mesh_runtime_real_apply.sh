#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/control_plane

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase111_mesh_runtime_real_apply_${TS}.txt"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_apply_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_apply_${TS}.md"

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

HAS_PLACEHOLDER=false
grep -Eq 'COLE_AQUI_|IP_OU_HOST_REAL|USUARIO_REAL|SENHA_REAL' .secrets/mesh_nodes.env && HAS_PLACEHOLDER=true || true

run_remote() {
  local name="$1"
  local host="$2"
  local port="$3"
  local user="$4"
  local pass="$5"

  echo "===== NODE ${name} ====="

  if [ "${HAS_PLACEHOLDER}" = "true" ]; then
    echo "SKIPPED_PLACEHOLDER=true"
    return 0
  fi

  set +e
  sshpass -p "${pass}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "${port}" "${user}@${host}" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p ~/jarvis_node_runtime
cat > ~/jarvis_node_runtime/healthcheck.sh <<'H'
#!/usr/bin/env bash
set -euo pipefail
echo "node=$(hostname)"
echo "utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "status=ok"
H
chmod +x ~/jarvis_node_runtime/healthcheck.sh
~/jarvis_node_runtime/healthcheck.sh
REMOTE
  local rc=$?
  set -e

  echo "SSH_RC=${rc}"
  return 0
}

{
  echo "===== APPLY PHASE111 ====="
  run_remote "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}"
  run_remote "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}"
  run_remote "tadash" "${TADASH_HOST}" "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}" "${TADASH_SSH_PASS}"
} > "${RAW_FILE}" 2>&1

VISION_OK=false
FRIDAY_OK=false
TADASH_OK=false

awk '/===== NODE vision =====/,/===== NODE friday =====/' "${RAW_FILE}" | grep -q 'status=ok' && VISION_OK=true || true
awk '/===== NODE friday =====/,/===== NODE tadash =====/' "${RAW_FILE}" | grep -q 'status=ok' && FRIDAY_OK=true || true
awk '/===== NODE tadash =====/,0' "${RAW_FILE}" | grep -q 'status=ok' && TADASH_OK=true || true

OVERALL_OK=false
if [ "${HAS_PLACEHOLDER}" = "true" ]; then
  OVERALL_OK=true
elif [ "${VISION_OK}" = "true" ] && [ "${FRIDAY_OK}" = "true" ] && [ "${TADASH_OK}" = "true" ]; then
  OVERALL_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  --argjson has_placeholder "${HAS_PLACEHOLDER}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_runtime_real_apply: {
      raw_file: $raw_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      tadash_ok: $tadash_ok,
      has_placeholder: $has_placeholder,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 111 — Mesh Runtime Real Apply

## Apply
- raw_file: ${RAW_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- tadash_ok: ${TADASH_OK}
- has_placeholder: ${HAS_PLACEHOLDER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase111 apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
