#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("runtime/vision/policy")
OUT = BASE / "out"
STATE = BASE / "state"

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def has_any(text: str, terms):
    return any(term in text for term in terms)

def classify_primary(text: str):
    t = (text or "").lower()
    time.sleep(0.08)

    if has_any(t, ["rollback executado", "falha critica", "falha crítica", "instavel", "instável"]):
        return "attention", 0.91
    if has_any(t, ["risco controlado", "operacao monitorada", "operação monitorada"]):
        return "risk_controlled", 0.84
    if has_any(t, ["nao houve rollback", "não houve rollback", "sem rollback", "healthy", "respondeu normalmente", "operacao estavel", "operação estável"]):
        return "healthy_controlled", 0.88
    return "unknown", 0.50

def classify_secondary(text: str):
    t = (text or "").lower()
    time.sleep(0.03)

    negated_rollback = has_any(t, ["nao houve rollback", "não houve rollback", "sem rollback"])
    executed_rollback = has_any(t, ["rollback executado", "houve rollback"])
    risk_controlled = has_any(t, ["risco controlado", "operacao monitorada", "operação monitorada"])
    healthy = has_any(t, ["healthy", "sem incidentes", "respondeu normalmente", "operacao estavel", "operação estável"])
    critical = has_any(t, ["instavel", "instável", "falha critica", "falha crítica"])

    if executed_rollback or critical:
        return "attention", 0.92
    if risk_controlled and not executed_rollback:
        return "risk_controlled", 0.87
    if negated_rollback and healthy:
        return "healthy_controlled", 0.95
    if healthy:
        return "healthy_controlled", 0.82
    return "unknown", 0.55

def choose_route(policy: str):
    policy = (policy or "").strip().lower()
    if policy == "quality_first":
        return "route_primary_simulated"
    if policy == "speed_first":
        return "route_secondary_simulated"
    return "route_primary_simulated"

def process_task(task_file: Path):
    task = json.loads(task_file.read_text())
    task_id = task.get("task_id", "")
    policy = task.get("policy", "quality_first")
    text = task.get("input", {}).get("text", "")

    chosen_route = choose_route(policy)

    started = time.perf_counter()
    if chosen_route == "route_primary_simulated":
        classification, confidence = classify_primary(text)
    else:
        classification, confidence = classify_secondary(text)
    elapsed_ms = round((time.perf_counter() - started) * 1000, 2)

    output = {
        "task_id": task_id,
        "processed_at": utc_now(),
        "status": "processed",
        "policy_used": policy,
        "chosen_route": chosen_route,
        "classification": classification,
        "confidence": confidence,
        "elapsed_ms": elapsed_ms,
        "source_task_file": str(task_file)
    }

    out_file = OUT / f"policy_result_{task_file.stem.replace('policy_task_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    ledger = STATE / "policy_processed.txt"
    with ledger.open("a", encoding="utf-8") as f:
        f.write(task_id + "\n")

    print(f"[OK] policy output gerado em {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    tasks = sorted(BASE.glob("policy_task_*.json"))
    if not tasks:
        print("[ERRO] nenhuma policy task encontrada")
        return 1

    for task_file in tasks[-2:]:
        process_task(task_file)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
