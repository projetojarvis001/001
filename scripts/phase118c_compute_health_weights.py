#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

HEALTH_WEIGHTS = BASE / "scheduler/health_weights.json"
REGISTRY_STATE = BASE / "registry/mesh_registry_state.json"
HTTP_BOOTSTRAP_STATE = BASE / "control_plane/mesh_http_bootstrap_state.json"
SCHEDULER_STATE = BASE / "scheduler/mesh_scheduler_state.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118c_health_weight_analysis_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118c_health_weight_analysis_packet_{REPORT_TS}.json"


def load_json(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"arquivo nao encontrado: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def get_nested_block(data, key):
    if isinstance(data, dict):
        nested = data.get(key)
        if isinstance(nested, dict):
            return nested
    return data if isinstance(data, dict) else {}


def classify_weight(score: int):
    if score >= 3:
        return "healthy", 1.0, "strong_evidence"
    if score >= 2:
        return "degraded", 0.5, "partial_evidence"
    return "down_or_unknown", 0.0, "insufficient_evidence"


def main():
    health_weights = load_json(HEALTH_WEIGHTS)
    registry_state_raw = load_json(REGISTRY_STATE)
    http_state_raw = load_json(HTTP_BOOTSTRAP_STATE)
    scheduler_state_raw = load_json(SCHEDULER_STATE)

    registry_state = get_nested_block(registry_state_raw, "mesh_registry_state")
    http_state = get_nested_block(http_state_raw, "mesh_http_bootstrap_state")
    scheduler_state = get_nested_block(scheduler_state_raw, "mesh_scheduler_state")

    registry_ok = (
        registry_state.get("overall_ok") is True and
        registry_state.get("ready_count") == 3 and
        registry_state.get("status") == "registry_operational"
    )

    http_ok = (
        http_state.get("overall_ok") is True and
        http_state.get("ready_count") == 3 and
        http_state.get("status") == "fully_operational"
    )

    scheduler_ok = (
        scheduler_state.get("overall_ok") is True and
        scheduler_state.get("status") == "scheduler_operational"
    )

    for node in ["vision", "friday", "tadash"]:
        score = 0
        signals = []

        if registry_ok:
            score += 1
            signals.append("registry_operational_global")

        if http_ok:
            score += 1
            signals.append("http_bootstrap_global")

        if scheduler_ok:
            score += 1
            signals.append("scheduler_operational_global")

        health_status, effective_weight, reason = classify_weight(score)

        health_weights["nodes"][node] = {
            "base_weight": 1.0,
            "health_status": health_status,
            "effective_weight": effective_weight,
            "reason": reason,
            "signals": signals,
            "signal_score": score
        }

    health_weights["created_at"] = CREATED_AT
    health_weights["mode"] = "analysis_computed"
    health_weights["policy"] = {
        "analysis_only": True,
        "routing_enforced": False,
        "block_degraded_nodes": False,
        "prefer_high_weight_nodes": False
    }
    health_weights["governance"] = {
        "deploy_executed": False,
        "production_changed": False
    }

    with HEALTH_WEIGHTS.open("w", encoding="utf-8") as f:
        json.dump(health_weights, f, indent=2, ensure_ascii=False)
        f.write("\n")

    report_lines = [
        "# FASE 118C — Health Weight Analysis",
        "",
        "## Summary"
    ]

    for node in ["vision", "friday", "tadash"]:
        info = health_weights["nodes"][node]
        report_lines.append(
            f"- {node}: health_status={info['health_status']}, effective_weight={info['effective_weight']}, signal_score={info['signal_score']}, reason={info['reason']}, signals={','.join(info['signals'])}"
        )

    report_lines.extend([
        "",
        "## Global Evidence",
        f"- registry_ok: {str(registry_ok).lower()}",
        f"- http_ok: {str(http_ok).lower()}",
        f"- scheduler_ok: {str(scheduler_ok).lower()}",
        "",
        "## Governance",
        "- deploy_executed: false",
        "- production_changed: false",
        ""
    ])

    DOC_OUT.write_text("\n".join(report_lines), encoding="utf-8")

    packet = {
        "created_at": CREATED_AT,
        "phase": "118C",
        "status": "health_weight_analysis_completed",
        "artifacts_created": [
            "scheduler/health_weights.json",
            str(DOC_OUT.relative_to(BASE))
        ],
        "summary": {
            "vision_effective_weight": health_weights["nodes"]["vision"]["effective_weight"],
            "friday_effective_weight": health_weights["nodes"]["friday"]["effective_weight"],
            "tadash_effective_weight": health_weights["nodes"]["tadash"]["effective_weight"],
            "registry_ok": registry_ok,
            "http_ok": http_ok,
            "scheduler_ok": scheduler_ok
        },
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with PACKET_OUT.open("w", encoding="utf-8") as f:
        json.dump(packet, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("[OK] health weight analysis completed")
    print(json.dumps(packet["summary"], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
