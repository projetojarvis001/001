#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

INBOX = Path("runtime/vision/inbox")
OUTBOX = Path("runtime/vision/outbox")

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def classify(text: str) -> tuple[str, float, str]:
    t = (text or "").lower()

    if "rollback" in t and ("houve" in t or "executado" in t or "falhou" in t):
        return "attention", 0.84, "Evento com indicio de rollback ou instabilidade."
    if "healthy" in t and "controlado" in t and "nao houve rollback" in t:
        return "healthy_controlled", 0.93, "Estado operacional controlado e sem rollback."
    if "risco" in t:
        return "risk_controlled", 0.78, "Evento com risco controlado identificado."
    return "unknown", 0.51, "Nao foi possivel classificar com alta confianca."

def main() -> int:
    INBOX.mkdir(parents=True, exist_ok=True)
    OUTBOX.mkdir(parents=True, exist_ok=True)

    tasks = sorted(INBOX.glob("task_*.json"))
    if not tasks:
        print("[ERRO] nenhuma task encontrada no inbox")
        return 1

    task_file = tasks[-1]
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
        "source_task_file": str(task_file)
    }

    out_file = OUTBOX / f"result_{task_file.stem.replace('task_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))
    print(f"[OK] output gerado em {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
