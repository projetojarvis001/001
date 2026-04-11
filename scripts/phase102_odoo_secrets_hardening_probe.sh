#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase102_odoo_secrets_hardening_probe_${TS}.json"
OUT_MD="docs/generated/phase102_odoo_secrets_hardening_probe_${TS}.md"

SECRETS_DIR_OK=false
ENV_FILE_OK=false
GITIGNORE_OK=false
LOADER_OK=false
AUDIT_WRAPPER_OK=false
SNAPSHOT_WRAPPER_OK=false

[ -d .secrets ] && SECRETS_DIR_OK=true || true
[ -f .secrets/odoo_watchdog.env ] && ENV_FILE_OK=true || true
grep -qxF '.secrets/' .gitignore && GITIGNORE_OK=true || true
[ -x scripts/load_odoo_env.sh ] && LOADER_OK=true || true
[ -x scripts/run_odoo_weekly_audit_secure.sh ] && AUDIT_WRAPPER_OK=true || true
[ -x scripts/run_odoo_exec_snapshot_secure.sh ] && SNAPSHOT_WRAPPER_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson secrets_dir_ok "${SECRETS_DIR_OK}" \
  --argjson env_file_ok "${ENV_FILE_OK}" \
  --argjson gitignore_ok "${GITIGNORE_OK}" \
  --argjson loader_ok "${LOADER_OK}" \
  --argjson audit_wrapper_ok "${AUDIT_WRAPPER_OK}" \
  --argjson snapshot_wrapper_ok "${SNAPSHOT_WRAPPER_OK}" \
  '{
    created_at: $created_at,
    secrets_hardening_probe: {
      secrets_dir_ok: $secrets_dir_ok,
      env_file_ok: $env_file_ok,
      gitignore_ok: $gitignore_ok,
      loader_ok: $loader_ok,
      audit_wrapper_ok: $audit_wrapper_ok,
      snapshot_wrapper_ok: $snapshot_wrapper_ok,
      overall_ok: (
        $secrets_dir_ok and
        $env_file_ok and
        $gitignore_ok and
        $loader_ok and
        $audit_wrapper_ok and
        $snapshot_wrapper_ok
      )
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 102 — ODOO Secrets Hardening Probe

## Probe
- secrets_dir_ok: ${SECRETS_DIR_OK}
- env_file_ok: ${ENV_FILE_OK}
- gitignore_ok: ${GITIGNORE_OK}
- loader_ok: ${LOADER_OK}
- audit_wrapper_ok: ${AUDIT_WRAPPER_OK}
- snapshot_wrapper_ok: ${SNAPSHOT_WRAPPER_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase102 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
