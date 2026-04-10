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

def has_any(text: str, terms: list[str]) -> bool:
    return any(term in text for term in terms)

def classify(text: str) -> tuple[str, float, str]:
    t = (text or "").lower()

    negated_rollback = has_any(t, [
        "nao houve rollback",
        "não houve rollback",
        "sem rollback"
    ])
    executed_rollback = has_any(t, [
        "rollback executado",
        "rollback falhou",
        "houve rollback"
    ])
    healthy_signals = has_any(t, [
        "healthy",
        "operacao estavel",
        "operação estável",
        "sem incidentes",
        "respondeu normalmente"
    ])
    risk_controlled = has_any(t, [
        "risco controlado",
        "risco atual controlado"
    ])
    critical_signals = has_any(t, [
        "falha critica",
        "falha crítica",
        "instavel",
        "instável"
    ])

    if executed_rollback or critical_signals:
        if negated_rollback and not has_any(t, ["rollback executado", "rollback falhou", "houve rollback"]):
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

def redis_rpop(queue_name: str) -> str:
    password = os.getenv("REDIS_PASSWORD", "").strip()
    cmd = ["docker", "exec", "redis", "redis-cli"]
    if password:
        cmd.extend(["-a", password])
    cmd.extend(["RPOP", queue_name])

    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return (result.stdout or "").strip()

def main() -> int:
    OUTBOX.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    payload = redis_rpop(QUEUE_NAME)
    if not payload:
        print("[OK] nenhuma task nova na fila redis")
        return 0

    if payload.startswith("NOAUTH") or payload.startswith("(error)") or payload.startswith("WRONGPASS"):
        print(f"[ERRO] redis respondeu erro: {payload}")
        return 1

    task = json.loads(payload)
    text = task.get("input", {}).get("text", "")
    classification, confidence, summary = classify(text)

    output = {
        "task_id": task.get("task_id", ""),
        "processed_at": utc_now(),
        "status": "processed",
        "summary": summary,
        "classification": classification,
        "confidence": confidence,
        "source": "phase73_redis_listener",
        "queue_name": QUEUE_NAME
    }

    out_file = OUTBOX / f"redis_result_{task.get('task_id', 'unknown')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    ledger_file = STATE / "redis_processed_tasks.txt"
    with ledger_file.open("a", encoding="utf-8") as f:
        f.write(task.get("task_id", "") + "\n")

    print(f"[OK] redis task processada: {task.get('task_id', '')}")
    print(f"[OK] output gerado: {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
