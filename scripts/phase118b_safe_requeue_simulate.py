#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

JOB_QUEUE = BASE / "scheduler/job_queue.json"
STUCK_JOBS = BASE / "scheduler/stuck_jobs.json"
OUT_JSON = BASE / "scheduler/requeue_results.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118b_safe_requeue_simulation_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118b_safe_requeue_simulation_packet_{REPORT_TS}.json"


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


def main():
    queue_data = load_json(JOB_QUEUE)
    stuck_data = load_json(STUCK_JOBS)

    queue_jobs = normalize_jobs(queue_data)
    suspected_jobs = stuck_data.get("suspected_jobs", []) if isinstance(stuck_data, dict) else []
    suspected_ids = {j.get("id") for j in suspected_jobs if isinstance(j, dict) and j.get("id")}

    results = []
    requeue_attempted = 0
    requeue_success = 0
    requeue_blocked = 0

    for job in queue_jobs:
        if not isinstance(job, dict):
            continue

        job_id = job.get("id")
        status = job.get("status")
        node = job.get("node")

        if job_id in suspected_ids:
            decision = "would_requeue"
            reason = "job_flagged_by_reconciliation"
            requeue_attempted += 1
            requeue_success += 1
        else:
            decision = "no_action"
            reason = "job_not_flagged"
            requeue_blocked += 1

        results.append({
            "id": job_id,
            "node": node,
            "current_status": status,
            "decision": decision,
            "reason": reason,
            "simulation_only": True
        })

    payload = {
        "phase": "118B",
        "created_at": CREATED_AT,
        "mode": "safe_requeue_simulation_only",
        "summary": {
            "requeue_attempted": requeue_attempted,
            "requeue_success": requeue_success,
            "requeue_blocked": requeue_blocked,
            "queue_jobs_total": len(queue_jobs),
            "suspected_jobs_total": len(suspected_ids)
        },
        "results": results,
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with OUT_JSON.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")

    lines = [
        "# FASE 118B — Safe Requeue Simulation",
        "",
        "## Summary",
        f"- requeue_attempted: {requeue_attempted}",
        f"- requeue_success: {requeue_success}",
        f"- requeue_blocked: {requeue_blocked}",
        f"- queue_jobs_total: {len(queue_jobs)}",
        f"- suspected_jobs_total: {len(suspected_ids)}",
        "",
        "## Decisions"
    ]

    if results:
        for item in results:
            lines.append(
                f"- {item['id']} | node={item.get('node')} | status={item.get('current_status')} | decision={item.get('decision')} | reason={item.get('reason')}"
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
        "phase": "118B",
        "status": "safe_requeue_simulation_completed",
        "artifacts_created": [
            "scheduler/requeue_results.json",
            str(DOC_OUT.relative_to(BASE))
        ],
        "summary": payload["summary"],
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with PACKET_OUT.open("w", encoding="utf-8") as f:
        json.dump(packet, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("[OK] safe requeue simulation completed")
    print(json.dumps(packet["summary"], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
