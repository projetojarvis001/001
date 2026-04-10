#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("runtime/vision/registry")
OUT = BASE / "out"
STATE = BASE / "state"

def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def route_score(route: dict) -> float:
    accuracy = float(route.get("accuracy_percent", 0.0))
    latency = float(route.get("avg_latency_ms", 9999.0))
    stability = float(route.get("stability_score", 0.0))
    latency_factor = max(0.0, 100.0 - latency) / 100.0
    return round((accuracy * 0.6) + (stability * 4.0) + (latency_factor * 10.0), 2)

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)

    registry_files = sorted(BASE.glob("route_registry_*.json"))
    if not registry_files:
        print("[ERRO] nenhum registry encontrado")
        return 1

    registry_file = registry_files[-1]
    data = json.loads(registry_file.read_text())
    routes = data.get("routes", [])

    if not routes:
        print("[ERRO] registry sem rotas")
        return 1

    ranked = []
    for r in routes:
        score = route_score(r)
        item = dict(r)
        item["recruiter_score"] = score
        ranked.append(item)

    ranked.sort(key=lambda x: x["recruiter_score"], reverse=True)

    promoted = ranked[0]["route"]
    demoted = ranked[-1]["route"]

    for r in ranked:
        if r["route"] == promoted:
            r["registry_decision"] = "promoted_primary"
        elif r["route"] == demoted:
            r["registry_decision"] = "demoted_secondary"
        else:
            r["registry_decision"] = "kept_candidate"

    output = {
        "processed_at": utc_now(),
        "source_registry_file": str(registry_file),
        "ranked_routes": ranked,
        "decision": {
            "promoted_route": promoted,
            "demoted_route": demoted,
            "registry_live": True
        }
    }

    out_file = OUT / f"registry_result_{registry_file.stem.replace('route_registry_', '')}.json"
    out_file.write_text(json.dumps(output, ensure_ascii=False, indent=2))

    ledger = STATE / "registry_processed.txt"
    with ledger.open("a", encoding="utf-8") as f:
        f.write(promoted + "\n")

    print(f"[OK] recruiter result gerado em {out_file}")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
