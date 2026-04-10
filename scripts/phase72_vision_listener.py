#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime, timezone

INBOX = Path("runtime/vision/inbox")
OUTBOX = Path("runtime/vision/outbox")
STATE_DIR = Path("runtime/vision/state")
PROCESSED_LEDGER = STATE_DIR / "processed_tasks.txt"

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

def load_processed() -> set[str]:
    if not PROCESSED_LEDGER.exists():
        return set()
    return {line.strip() for line in PROCESSED_LEDGER.read_text().splitlines() if line.strip()}

def mark_processed(task_file: Path) -> None:
    with PROCESSED_LEDGER.open("a", encoding="utf-8") as f:
        f.write(str(task_file) + "\n")

def process_task(task_file: Path) -> Path:
    task = json.loads(task_file.read_text())
    text = task.get("input", {}).get("text", "")
    classification, confidence, summary = classify(text)

    output = {
        "task_id": task.get("task_id", ""),
        "processed_at": utc_now(),
        "status": "processed",
        "summary": summary,
        "classification": classification,
        "confidence": confidence,
        "source_task_file": str(task_file),
        "listener_mode": "phase72_minimal_listener"
    }

    out_file = OUTBOX / f"result_{task_file.stem.replace('task_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))
    return out_file

def main() -> int:
    INBOX.mkdir(parents=True, exist_ok=True)
    OUTBOX.mkdir(parents=True, exist_ok=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_LEDGER.touch(exist_ok=True)

    processed = load_processed()
    tasks = sorted(INBOX.glob("task_*.json"))

    for task_file in tasks:
        if str(task_file) in processed:
            continue
        out_file = process_task(task_file)
        mark_processed(task_file)
        print(f"[OK] task processada: {task_file}")
        print(f"[OK] output gerado: {out_file}")
        return 0

    print("[OK] nenhuma task nova para processar")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
