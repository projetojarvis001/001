#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

TESTS_DIR = Path("runtime/vision/tests")
OUT_DIR = Path("runtime/vision/tests/out")

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
        return "attention", 0.91, "Evento com rollback real ou instabilidade critica."
    if negated_rollback and healthy_signals:
        return "healthy_controlled", 0.95, "Estado saudavel e controlado sem rollback."
    if risk_controlled and not executed_rollback:
        return "risk_controlled", 0.86, "Risco controlado identificado sem evento critico."
    if healthy_signals:
        return "healthy_controlled", 0.82, "Estado operacional saudavel."
    return "unknown", 0.55, "Classificacao ainda inconclusiva."

def main() -> int:
    TESTS_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    suites = sorted(TESTS_DIR.glob("semantic_cases_*.json"))
    if not suites:
        print("[ERRO] suite semantica nao encontrada")
        return 1

    suite_file = suites[-1]
    cases = json.loads(suite_file.read_text())

    results = []
    for case in cases:
        predicted, confidence, summary = classify(case["text"])
        results.append({
            "case_id": case["case_id"],
            "expected_classification": case["expected_classification"],
            "predicted_classification": predicted,
            "confidence": confidence,
            "summary": summary,
            "match": predicted == case["expected_classification"]
        })

    out_file = OUT_DIR / f"semantic_results_{suite_file.stem.replace('semantic_cases_', '')}.json"
    out_file.write_text(json.dumps({
        "processed_at": utc_now(),
        "source_suite": str(suite_file),
        "results": results
    }, ensure_ascii=False, indent=2))

    print(f"[OK] semantic results gerado em {out_file}")
    print(out_file.read_text())
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
