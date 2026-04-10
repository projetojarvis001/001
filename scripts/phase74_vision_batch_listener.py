#!/usr/bin/env python3
import json
import os
import subprocess
from pathlib import Path
from datetime import datetime, timezone

OUTBOX = Path("runtime/vision/outbox")
STATE = Path("runtime/vision/state")
QUEUE_NAME = "vision_tasks"

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def has_any(text: str, terms):
    return any(term in text for term in terms)

def classify(text: str):
    t = (text or "").lower()

    negated_rollback = has_any(t, ["nao houve rollback", "não houve rollback", "sem rollback"])
    executed_rollback = has_any(t, ["rollback executado", "rollback falhou", "houve rollback"])
    healthy_signals = has_any(t, ["healthy", "operacao estavel", "operação estável", "sem incidentes"])
    risk_controlled = has_any(t, ["risco controlado", "operacao monitorada", "operação monitorada"])
    critical_signals = has_any(t, ["instavel", "instável", "falha critica", "falha crítica"])

    if executed_rollback or critical_signals:
        if negated_rollback and not executed_rollback:
            pass
        else:
            return "attention", 0.91, "Evento com rollback real ou instabilidade critica."

    if negated_rollback and healthy_signals:
        return "healthy_controlled", 0.95, "Estado saudavel e controlado sem rollback."

    if risk_controlled and not executed_rollback:
        return "risk_controlled", 0.86, "Risco controlado identificado sem evento critico."

    if healthy_signals:
        return "healthy_controlled", 0.82, "Estado operacional saudavel."

    return "unknown", 0.55, "Classificacao ainda inconclusiva."

def redis_rpop():
    password = os.getenv("REDIS_PASSWORD", "").strip()
    cmd = ["docker", "exec", "redis", "redis-cli"]
    if password:
        cmd.extend(["-a", password])
    cmd.extend(["RPOP", QUEUE_NAME])
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return (result.stdout or "").strip()

def main():
    OUTBOX.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    ledger_file = STATE / "redis_processed_tasks.txt"
    processed = set()
    if ledger_file.exists():
        processed = {line.strip() for line in ledger_file.read_text().splitlines() if line.strip()}

    processed_now = 0

    while True:
        payload = redis_rpop()
        if not payload:
            break
        if payload.startswith("NOAUTH") or payload.startswith("WRONGPASS") or payload.startswith("(error)"):
            print(f"[ERRO] redis respondeu erro: {payload}")
            return 1

        task = json.loads(payload)
        task_id = task.get("task_id", "")
        if not task_id or task_id in processed:
            continue

        text = task.get("input", {}).get("text", "")
        classification, confidence, summary = classify(text)

        output = {
            "task_id": task_id,
            "processed_at": utc_now(),
            "status": "processed",
            "summary": summary,
            "classification": classification,
            "confidence": confidence,
            "source": "phase74_redis_batch_listener",
            "queue_name": QUEUE_NAME
        }

        out_file = OUTBOX / f"redis_result_{task_id}.json"
        out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

        with ledger_file.open("a", encoding="utf-8") as f:
            f.write(task_id + "\n")

        processed.add(task_id)
        processed_now += 1
        print(f"[OK] batch task processada: {task_id}")

    print(f"[OK] total processado no lote: {processed_now}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
