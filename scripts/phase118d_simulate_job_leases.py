#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone, timedelta

BASE = Path("/Users/jarvis001/jarvis")

JOB_QUEUE = BASE / "scheduler/job_queue.json"
JOB_LEASES = BASE / "scheduler/job_leases.json"
STUCK_JOBS = BASE / "scheduler/stuck_jobs.json"
RECOVERY_STATE = BASE / "scheduler/stuck_recovery_state.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT_DT = datetime.now(timezone.utc)
CREATED_AT = CREATED_AT_DT.strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118d_job_lease_simulation_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118d_job_lease_simulation_packet_{REPORT_TS}.json"


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


def owner_for_node(node: str) -> str:
    return f"scheduler-{node}"


def main():
    queue_data = load_json(JOB_QUEUE)
    leases_data = load_json(JOB_LEASES)
    stuck_data = load_json(STUCK_JOBS)
    recovery_state = load_json(RECOVERY_STATE)

    jobs = normalize_jobs(queue_data)
    suspected_jobs = stuck_data.get("suspected_jobs", []) if isinstance(stuck_data, dict) else []
    suspected_ids = {j.get("id") for j in suspected_jobs if isinstance(j, dict) and j.get("id")}

    ttl_seconds = 300
    max_heartbeat_age = 120

    leases = []
    summary = {
        "leases_total": 0,
        "active_leases": 0,
        "expired_leases": 0,
        "ownership_valid_count": 0,
        "jobs_flagged_for_recovery": 0
    }

    for job in jobs:
        if not isinstance(job, dict):
            continue

        job_id = job.get("id")
        node = job.get("node")
        current_status = job.get("status")
        owner = owner_for_node(node)
        acquired_at = CREATED_AT_DT
        heartbeat_at = CREATED_AT_DT
        expires_at = CREATED_AT_DT + timedelta(seconds=ttl_seconds)

        flagged_for_recovery = job_id in suspected_ids
        lease_status = "active"
        ownership_valid = True

        leases.append({
            "job_id": job_id,
            "node": node,
            "owner": owner,
            "current_status": current_status,
            "lease_status": lease_status,
            "ownership_valid": ownership_valid,
            "ttl_seconds": ttl_seconds,
            "max_owner_heartbeat_age_seconds": max_heartbeat_age,
            "acquired_at": acquired_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "heartbeat_at": heartbeat_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "expires_at": expires_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "flagged_for_recovery": flagged_for_recovery,
            "simulation_only": True
        })

        summary["leases_total"] += 1
        summary["active_leases"] += 1
        summary["ownership_valid_count"] += 1
        if flagged_for_recovery:
            summary["jobs_flagged_for_recovery"] += 1

    leases_data["created_at"] = CREATED_AT
    leases_data["mode"] = "lease_simulation_only"
    leases_data["lease_policy"] = {
        "analysis_only": True,
        "lease_enforced": False,
        "ttl_seconds_default": ttl_seconds,
        "max_owner_heartbeat_age_seconds": max_heartbeat_age,
        "stuck_recovery_enabled": False
    }
    leases_data["leases"] = leases
    leases_data["governance"] = {
        "deploy_executed": False,
        "production_changed": False
    }

    with JOB_LEASES.open("w", encoding="utf-8") as f:
        json.dump(leases_data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if isinstance(recovery_state, dict):
        recovery_state["created_at"] = CREATED_AT
        recovery_state["status"] = "lease_simulation_completed"
        recovery_state["mode"] = "analysis_only"
        recovery_state["last_lease_summary"] = summary
        recovery_state["governance"] = {
            "deploy_executed": False,
            "production_changed": False
        }

        with RECOVERY_STATE.open("w", encoding="utf-8") as f:
            json.dump(recovery_state, f, indent=2, ensure_ascii=False)
            f.write("\n")

    lines = [
        "# FASE 118D — Job Lease Simulation",
        "",
        "## Summary",
        f"- leases_total: {summary['leases_total']}",
        f"- active_leases: {summary['active_leases']}",
        f"- expired_leases: {summary['expired_leases']}",
        f"- ownership_valid_count: {summary['ownership_valid_count']}",
        f"- jobs_flagged_for_recovery: {summary['jobs_flagged_for_recovery']}",
        "",
        "## Leases"
    ]

    if leases:
        for item in leases:
            lines.append(
                f"- {item['job_id']} | node={item.get('node')} | owner={item.get('owner')} | lease_status={item.get('lease_status')} | ownership_valid={str(item.get('ownership_valid')).lower()} | flagged_for_recovery={str(item.get('flagged_for_recovery')).lower()}"
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
        "status": "job_lease_simulation_completed",
        "artifacts_created": [
            "scheduler/job_leases.json",
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

    print("[OK] job lease simulation completed")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
