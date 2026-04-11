#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 103 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase103_observability_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase103_observability_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== APPLY OBSERVABILITY ====="
./scripts/phase103_observability_apply.sh
APPLY_FILE="$(ls -1t logs/executive/phase103_observability_apply_*.json 2>/dev/null | head -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== PROBE OBSERVABILITY ====="
./scripts/phase103_observability_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase103_observability_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase103_observability_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase103_observability_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase103_observability_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase103_observability_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.observability_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.observability_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.observability_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fundacao de observabilidade comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase103_observability_seed.sh
bash -n scripts/phase103_observability_apply.sh
bash -n scripts/phase103_observability_probe.sh
bash -n scripts/phase103_observability_evidence.sh
bash -n scripts/phase103_observability_packet.sh
bash -n scripts/validate_fase103.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 103 validada"
