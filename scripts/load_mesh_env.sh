#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".secrets/mesh_nodes.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERRO] arquivo ${ENV_FILE} nao encontrado"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

echo "[OK] ambiente da malha carregado"
env | grep -E '^(VISION|FRIDAY|TADASH)_' | sed \
  -e 's/_SSH_PASS=.*/_SSH_PASS=[REDACTED]/'
