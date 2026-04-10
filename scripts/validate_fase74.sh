#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -z "${REDIS_PASSWORD:-}" ]; then
  echo "[ERRO] REDIS_PASSWORD nao exportada"
  exit 1
fi

echo "===== VALIDATE FASE 74 ====="

echo
echo "===== RESET REDIS BATCH AREA ====="
find runtime/vision/outbox -maxdepth 1 -type f -name 'redis_result_vision-batch-task-*.json' -delete
rm -f runtime/vision/state/redis_processed_tasks.txt
docker exec redis redis-cli -a "${REDIS_PASSWORD}" DEL vision_tasks >/dev/null
echo "[OK] area batch limpa"

echo
echo "===== BUILD BATCH SEED ====="
./scripts/phase74_vision_batch_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase74_vision_batch_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN BATCH LISTENER ====="
python3 scripts/phase74_vision_batch_listener.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase74_vision_batch_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase74_vision_batch_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase74_vision_batch_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase74_vision_batch_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.batch_seed.task_count == 3' "${SEED_FILE}" >/dev/null
jq -e '.batch_flow.batch_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.batch_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] consumo em lote do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase74_vision_batch_seed.sh
python3 -m py_compile scripts/phase74_vision_batch_listener.py
bash -n scripts/phase74_vision_batch_evidence.sh
bash -n scripts/phase74_vision_batch_packet.sh
bash -n scripts/validate_fase74.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 74 validada"
