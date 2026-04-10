#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("runtime/vision/fallback")
OUTBOX = BASE / "out"
STATE = BASE / "state"

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def has_any(text: str, terms):
    return any(term in text for term in terms)

def classify_secondary(text: str):
    t = (text or "").lower()

    negated_rollback = has_any(t, ["nao houve rollback", "não houve rollback", "sem rollback"])
    executed_rollback = has_any(t, ["rollback executado", "rollback falhou", "houve rollback"])
    risk_controlled = has_any(t, ["risco controlado", "operacao monitorada", "operação monitorada"])
    healthy = has_any(t, ["healthy", "sem incidentes", "operacao estavel", "operação estável"])
    critical = has_any(t, ["instavel", "instável", "falha critica", "falha crítica"])

    if executed_rollback or critical:
        return "attention", 0.91, "Evento com rollback real ou instabilidade critica."

    if risk_controlled and not executed_rollback:
        return "risk_controlled", 0.87, "Risco controlado identificado com fallback funcional."

    if negated_rollback and healthy:
        return "healthy_controlled", 0.94, "Estado saudavel e controlado sem rollback."

    return "unknown", 0.55, "Classificacao inconclusiva no fallback."

def run_primary(task: dict):
    routing = task.get("routing", {})
    if routing.get("force_primary_fail", False):
        raise RuntimeError("primary_route_simulated_failure")
    return {
        "classification": "healthy_controlled",
        "confidence": 0.70,
        "summary": "Primario respondeu."
    }

def run_fallback(task: dict):
    text = task.get("input", {}).get("text", "")
    classification, confidence, summary = classify_secondary(text)
    return {
        "classification": classification,
        "confidence": confidence,
        "summary": summary
    }

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUTBOX.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    tasks = sorted(BASE.glob("fallback_task_*.json"))
    if not tasks:
        print("[ERRO] nenhuma fallback task encontrada")
        return 1

    task_file = tasks[-1]
    task = json.loads(task_file.read_text())

    primary_ok = True
    primary_error = ""
    used_model = task.get("routing", {}).get("primary_model", "unknown")

    try:
        result = run_primary(task)
    except Exception as e:
        primary_ok = False
        primary_error = str(e)
        used_model = task.get("routing", {}).get("fallback_model", "unknown")
        result = run_fallback(task)

    output = {
        "task_id": task.get("task_id", ""),
        "processed_at": utc_now(),
        "status": "processed",
        "classification": result["classification"],
        "confidence": result["confidence"],
        "summary": result["summary"],
        "routing_result": {
            "primary_ok": primary_ok,
            "primary_error": primary_error,
            "used_model": used_model,
            "fallback_used": (not primary_ok)
        },
        "source_task_file": str(task_file)
    }

    out_file = OUTBOX / f"fallback_result_{task_file.stem.replace('fallback_task_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    ledger = STATE / "fallback_processed.txt"
    with ledger.open("a", encoding="utf-8") as f:
        f.write(task.get("task_id", "") + "\n")

    print(f"[OK] fallback output gerado em {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
