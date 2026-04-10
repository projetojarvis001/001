#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -z "${REDIS_PASSWORD:-}" ]; then
  echo "[ERRO] REDIS_PASSWORD nao exportada"
  exit 1
fi

echo "===== VALIDATE FASE 73A ====="

echo
echo "===== RESET REDIS TEST AREA ====="
find runtime/vision/outbox -maxdepth 1 -type f -name 'redis_result_*.json' -delete
rm -f runtime/vision/state/redis_processed_tasks.txt
docker exec redis redis-cli -a "${REDIS_PASSWORD}" DEL vision_tasks >/dev/null
echo "[OK] area redis limpa"

echo
echo "===== BUILD REDIS PROBE ====="
./scripts/phase73_redis_queue_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase73_redis_queue_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== PUBLISH TASK ====="
./scripts/phase73_vision_redis_publish.sh
PUBLISH_FILE="$(ls -1t logs/executive/phase73_vision_redis_publish_*.json 2>/dev/null | head -n 1 || true)"
echo "PUBLISH_FILE=${PUBLISH_FILE}"

echo
echo "===== RUN REDIS LISTENER ====="
python3 scripts/phase73_vision_redis_listener.py

echo
echo "===== BUILD REDIS EVIDENCE ====="
./scripts/phase73_vision_redis_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase73_vision_redis_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD REDIS PACKET ====="
./scripts/phase73_vision_redis_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase73_vision_redis_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.redis_probe.redis_ping_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.redis_flow.redis_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.queue_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] fila redis real do vision comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase73_redis_queue_probe.sh
bash -n scripts/phase73_vision_redis_publish.sh
python3 -m py_compile scripts/phase73_vision_redis_listener.py
bash -n scripts/phase73_vision_redis_evidence.sh
bash -n scripts/phase73_vision_redis_packet.sh
bash -n scripts/validate_fase73a.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 73A validada"
