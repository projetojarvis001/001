#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

JOB_QUEUE = BASE / "scheduler/job_queue.json"
STUCK_JOBS = BASE / "scheduler/stuck_jobs.json"
JOB_LEASES = BASE / "scheduler/job_leases.json"
RECOVERY_STATE = BASE / "scheduler/stuck_recovery_state.json"
OUT_JSON = BASE / "scheduler/stuck_recovery_results.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118d_stuck_recovery_simulation_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118d_stuck_recovery_simulation_packet_{REPORT_TS}.json"


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


def index_leases(data):
    leases = data.get("leases", []) if isinstance(data, dict) else []
    idx = {}
    for item in leases:
        if isinstance(item, dict) and item.get("job_id"):
            idx[item["job_id"]] = item
    return idx


def main():
    queue_data = load_json(JOB_QUEUE)
    stuck_data = load_json(STUCK_JOBS)
    lease_data = load_json(JOB_LEASES)
    recovery_state = load_json(RECOVERY_STATE)

    jobs = normalize_jobs(queue_data)
    suspected_jobs = stuck_data.get("suspected_jobs", []) if isinstance(stuck_data, dict) else []
    suspected_ids = {j.get("id") for j in suspected_jobs if isinstance(j, dict) and j.get("id")}
    lease_idx = index_leases(lease_data)

    results = []
    summary = {
        "recovery_candidates_total": 0,
        "recover_now_total": 0,
        "blocked_by_active_lease_total": 0,
        "observe_only_total": 0,
        "jobs_total": 0
    }

    for job in jobs:
        if not isinstance(job, dict):
            continue

        job_id = job.get("id")
        node = job.get("node")
        status = job.get("status")
        lease = lease_idx.get(job_id)
        lease_status = lease.get("lease_status") if isinstance(lease, dict) else "missing"
        ownership_valid = lease.get("ownership_valid") if isinstance(lease, dict) else False

        if job_id in suspected_ids:
            summary["recovery_candidates_total"] += 1
            if lease_status == "active" and ownership_valid is True:
                decision = "block_recovery"
                reason = "active_valid_lease"
                summary["blocked_by_active_lease_total"] += 1
            else:
                decision = "recover_now"
                reason = "no_valid_active_lease"
                summary["recover_now_total"] += 1
        else:
            decision = "observe_only"
            reason = "job_not_flagged"
            summary["observe_only_total"] += 1

        results.append({
            "job_id": job_id,
            "node": node,
            "current_status": status,
            "lease_status": lease_status,
            "ownership_valid": ownership_valid,
            "decision": decision,
            "reason": reason,
            "simulation_only": True
        })

        summary["jobs_total"] += 1

    payload = {
        "phase": "118D",
        "created_at": CREATED_AT,
        "mode": "safe_stuck_recovery_simulation_only",
        "summary": summary,
        "results": results,
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with OUT_JSON.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if isinstance(recovery_state, dict):
        recovery_state["created_at"] = CREATED_AT
        recovery_state["status"] = "stuck_recovery_simulation_completed"
        recovery_state["mode"] = "analysis_only"
        recovery_state["last_recovery_summary"] = summary
        recovery_state["governance"] = {
            "deploy_executed": False,
            "production_changed": False
        }
        with RECOVERY_STATE.open("w", encoding="utf-8") as f:
            json.dump(recovery_state, f, indent=2, ensure_ascii=False)
            f.write("\n")

    lines = [
        "# FASE 118D — Safe Stuck Recovery Simulation",
        "",
        "## Summary",
        f"- recovery_candidates_total: {summary['recovery_candidates_total']}",
        f"- recover_now_total: {summary['recover_now_total']}",
        f"- blocked_by_active_lease_total: {summary['blocked_by_active_lease_total']}",
        f"- observe_only_total: {summary['observe_only_total']}",
        f"- jobs_total: {summary['jobs_total']}",
        "",
        "## Decisions"
    ]

    if results:
        for item in results:
            lines.append(
                f"- {item['job_id']} | node={item.get('node')} | status={item.get('current_status')} | lease_status={item.get('lease_status')} | ownership_valid={str(item.get('ownership_valid')).lower()} | decision={item.get('decision')} | reason={item.get('reason')}"
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
        "phase": "118D",
        "status": "stuck_recovery_simulation_completed",
        "artifacts_created": [
            "scheduler/stuck_recovery_results.json",
            "scheduler/stuck_recovery_state.json",
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

    print("[OK] stuck recovery simulation completed")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
