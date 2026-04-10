#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("runtime/vision/memory")
OUT = BASE / "out"
STATE = BASE / "state"

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def classify_with_context(text: str, history: list[dict]):
    t = (text or "").lower()

    had_attention = any((e.get("classification") == "attention") for e in history)
    had_risk = any((e.get("classification") == "risk_controlled") for e in history)

    if "novo rollback" in t or "falha critica" in t or "falha crítica" in t:
        return "attention", 0.91, "Novo evento critico identificado no contexto atual."

    if ("sem novo rollback" in t or "segue estavel" in t or "segue estável" in t) and had_attention:
        return "risk_controlled", 0.89, "Contexto indica recuperacao monitorada apos incidente anterior."

    if ("estavel" in t or "estável" in t) and had_risk:
        return "healthy_controlled", 0.86, "Historico recente mostra reducao de risco e operacao estabilizada."

    return "unknown", 0.50, "Contexto insuficiente para decisao robusta."

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    tasks = sorted(BASE.glob("context_task_*.json"))
    if not tasks:
        print("[ERRO] nenhuma context task encontrada")
        return 1

    task_file = tasks[-1]
    task = json.loads(task_file.read_text())

    memory_file = Path(task.get("memory_file", "")).expanduser()
    if not memory_file.exists():
        print("[ERRO] memory_file nao encontrado")
        return 1

    history = []
    with memory_file.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                history.append(json.loads(line))

    text = task.get("input", {}).get("text", "")
    classification, confidence, summary = classify_with_context(text, history)

    output = {
        "task_id": task.get("task_id", ""),
        "processed_at": utc_now(),
        "status": "processed",
        "classification": classification,
        "confidence": confidence,
        "summary": summary,
        "memory_events_used": len(history),
        "memory_file": str(memory_file),
        "source_task_file": str(task_file)
    }

    out_file = OUT / f"memory_result_{task_file.stem.replace('context_task_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    ledger = STATE / "memory_processed.txt"
    with ledger.open("a", encoding="utf-8") as f:
        f.write(task.get("task_id", "") + "\n")

    print(f"[OK] memory output gerado em {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
