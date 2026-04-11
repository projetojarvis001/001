#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

QUEUE_FILE="scheduler/job_queue.json"
DLQ_FILE="scheduler/dead_letter_queue.json"
OUT_JSON="logs/executive/phase117_mesh_scheduler_queue_${TS}.json"
OUT_MD="docs/generated/phase117_mesh_scheduler_queue_${TS}.md"

cat > "${QUEUE_FILE}" <<JSON
{
  "created_at": "${CREATED_AT}",
  "jobs": [
    {
      "id": "sched_vision_health_001",
      "node": "vision",
      "host": "192.168.8.124",
      "ssh_port": 22,
      "user": "vision",
      "password_env": "VISION_SSH_PASS",
      "command": "echo sched_vision_ok; hostname; whoami",
      "max_retries": 2,
      "retry_count": 0,
      "status": "pending"
    },
    {
      "id": "sched_friday_health_001",
      "node": "friday",
      "host": "192.168.8.36",
      "ssh_port": 22,
      "user": "wagner",
      "password_env": "FRIDAY_SSH_PASS",
      "command": "echo sched_friday_ok; hostname; whoami",
      "max_retries": 2,
      "retry_count": 0,
      "status": "pending"
    },
    {
      "id": "sched_tadash_health_001",
      "node": "tadash",
      "host": "177.104.176.69",
      "ssh_port": 61022,
      "user": "wps",
      "password_env": "TADASH_SSH_PASS",
      "command": "echo sched_tadash_ok; hostname; whoami",
      "max_retries": 2,
      "retry_count": 0,
      "status": "pending"
    }
  ]
}
JSON

cat > "${DLQ_FILE}" <<JSON
{
  "created_at": "${CREATED_AT}",
  "jobs": []
}
JSON

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg queue_file "${QUEUE_FILE}" \
  --arg dlq_file "${DLQ_FILE}" \
  '{
    created_at: $created_at,
    scheduler_queue: {
      queue_file: $queue_file,
      dlq_file: $dlq_file,
      jobs_total: 3,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 117 — Mesh Scheduler Queue

## Queue
- queue_file: ${QUEUE_FILE}
- dlq_file: ${DLQ_FILE}
- jobs_total: 3

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase117 queue gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
cat "${QUEUE_FILE}" | jq .
echo
cat "${DLQ_FILE}" | jq .
