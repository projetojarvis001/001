#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("runtime/vision/benchmark")
OUT = BASE / "out"

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

def run_route(route_name: str, text: str):
    start = time.perf_counter()
    if route_name == "route_primary_simulated":
        classification, confidence = classify_primary(text)
    else:
        classification, confidence = classify_secondary(text)
    elapsed_ms = round((time.perf_counter() - start) * 1000, 2)
    return classification, confidence, elapsed_ms

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    suites = sorted(BASE.glob("benchmark_suite_*.json"))
    if not suites:
        print("[ERRO] nenhuma benchmark suite encontrada")
        return 1

    suite_file = suites[-1]
    suite = json.loads(suite_file.read_text())

    routes = suite.get("routes", [])
    cases = suite.get("cases", [])

    route_results = []

    for route in routes:
        results = []
        hits = 0
        total_ms = 0.0

        for case in cases:
            predicted, confidence, elapsed_ms = run_route(route, case["text"])
            match = predicted == case["expected_classification"]
            if match:
                hits += 1
            total_ms += elapsed_ms
            results.append({
                "case_id": case["case_id"],
                "expected_classification": case["expected_classification"],
                "predicted_classification": predicted,
                "confidence": confidence,
                "elapsed_ms": elapsed_ms,
                "match": match
            })

        accuracy_percent = round((hits / len(cases)) * 100, 2) if cases else 0.0
        avg_latency_ms = round(total_ms / len(cases), 2) if cases else 0.0

        route_results.append({
            "route": route,
            "accuracy_percent": accuracy_percent,
            "avg_latency_ms": avg_latency_ms,
            "hits": hits,
            "total_cases": len(cases),
            "results": results
        })

    winner = sorted(
        route_results,
        key=lambda x: (x["accuracy_percent"], -x["avg_latency_ms"]),
        reverse=True
    )[0]

    out_file = OUT / f"benchmark_result_{suite_file.stem.replace('benchmark_suite_', '')}.json"
    out_file.write_text(json.dumps({
        "processed_at": utc_now(),
        "source_suite": str(suite_file),
        "route_results": route_results,
        "winner": {
            "route": winner["route"],
            "accuracy_percent": winner["accuracy_percent"],
            "avg_latency_ms": winner["avg_latency_ms"]
        }
    }, ensure_ascii=False, indent=2))

    print(f"[OK] benchmark result gerado em {out_file}")
    print(out_file.read_text())
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
