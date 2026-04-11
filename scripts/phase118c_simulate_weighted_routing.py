#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

HEALTH_WEIGHTS = BASE / "scheduler/health_weights.json"
JOB_QUEUE = BASE / "scheduler/job_queue.json"
STATE_FILE = BASE / "scheduler/health_weighted_scheduler_state.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

OUT_JSON = BASE / "scheduler/weighted_routing_decisions.json"
DOC_OUT = BASE / f"docs/generated/phase118c_weighted_routing_simulation_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118c_weighted_routing_simulation_packet_{REPORT_TS}.json"


def load_json(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"arquivo nao encontrado: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalize_jobs(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ["jobs", "queue", "items"]:
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def decide(weight_info):
    effective_weight = float(weight_info.get("effective_weight", 0.0) or 0.0)
    status = str(weight_info.get("health_status", "unknown"))

    if effective_weight >= 1.0 and status == "healthy":
        return "allow", "healthy_node"
    if effective_weight > 0.0:
        return "observe", "partial_weight"
    return "block", "node_unhealthy_or_unknown"


def main():
    weights = load_json(HEALTH_WEIGHTS)
    queue_data = load_json(JOB_QUEUE)
    state_data = load_json(STATE_FILE)

    jobs = normalize_jobs(queue_data)
    nodes = weights.get("nodes", {}) if isinstance(weights, dict) else {}

    decisions = []
    summary = {
        "allow_count": 0,
        "observe_count": 0,
        "block_count": 0,
        "jobs_total": 0
    }

    for job in jobs:
        if not isinstance(job, dict):
            continue

        job_id = job.get("id")
        node = job.get("node")
        current_status = job.get("status")

        weight_info = nodes.get(node, {
            "health_status": "unknown",
            "effective_weight": 0.0,
            "reason": "missing_node_weight"
        })

        decision, reason = decide(weight_info)

        decisions.append({
            "id": job_id,
            "node": node,
            "current_status": current_status,
            "decision": decision,
            "reason": reason,
            "effective_weight": weight_info.get("effective_weight"),
            "health_status": weight_info.get("health_status"),
            "simulation_only": True
        })

        if decision == "allow":
            summary["allow_count"] += 1
        elif decision == "observe":
            summary["observe_count"] += 1
        else:
            summary["block_count"] += 1

        summary["jobs_total"] += 1

    payload = {
        "phase": "118C",
        "created_at": CREATED_AT,
        "mode": "weighted_routing_simulation_only",
        "summary": summary,
        "decisions": decisions,
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with OUT_JSON.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if isinstance(state_data, dict):
        state_data["created_at"] = CREATED_AT
        state_data["status"] = "weighted_routing_simulated"
        state_data["mode"] = "analysis_only"
        state_data["routing_policy"] = {
            "allow_equal_weights": True,
            "allow_unknown_health": True,
            "degraded_node_action": "observe_only",
            "down_node_action": "block_in_future_not_now"
        }
        state_data["last_weighted_routing_summary"] = summary
        state_data["governance"] = {
            "deploy_executed": False,
            "production_changed": False
        }

        with STATE_FILE.open("w", encoding="utf-8") as f:
            json.dump(state_data, f, indent=2, ensure_ascii=False)
            f.write("\n")

    lines = [
        "# FASE 118C — Weighted Routing Simulation",
        "",
        "## Summary",
        f"- allow_count: {summary['allow_count']}",
        f"- observe_count: {summary['observe_count']}",
        f"- block_count: {summary['block_count']}",
        f"- jobs_total: {summary['jobs_total']}",
        "",
        "## Decisions"
    ]

    if decisions:
        for item in decisions:
            lines.append(
                f"- {item['id']} | node={item.get('node')} | status={item.get('current_status')} | decision={item.get('decision')} | reason={item.get('reason')} | weight={item.get('effective_weight')} | health={item.get('health_status')}"
            )
    else:
        lines.append("- none")

    lines.extend([
        "",
        "## Governance",
        "- deploy_executed: false",
        "- production_changed: false",
        ""
    ])

    DOC_OUT.write_text("\n".join(lines), encoding="utf-8")

    packet = {
        "created_at": CREATED_AT,
        "phase": "118C",
        "status": "weighted_routing_simulation_completed",
        "artifacts_created": [
            "scheduler/weighted_routing_decisions.json",
            "scheduler/health_weighted_scheduler_state.json",
            str(DOC_OUT.relative_to(BASE))
        ],
        "summary": summary,
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with PACKET_OUT.open("w", encoding="utf-8") as f:
        json.dump(packet, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("[OK] weighted routing simulation completed")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
