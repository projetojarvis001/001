#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

JOB_QUEUE = BASE / "scheduler/job_queue.json"
DLQ = BASE / "scheduler/dead_letter_queue.json"
JOB_RESULTS = BASE / "scheduler/job_run_results.json"
SCHED_STATE = BASE / "scheduler/mesh_scheduler_state.json"
STUCK_JOBS = BASE / "scheduler/stuck_jobs.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118b_reconciliation_analysis_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118b_reconciliation_analysis_packet_{REPORT_TS}.json"


def load_json(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"arquivo nao encontrado: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalize_jobs_from_queue(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ["jobs", "queue", "items"]:
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def normalize_jobs_from_results(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ["results", "jobs", "items"]:
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def normalize_jobs_from_dlq(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ["jobs", "dead_jobs", "items", "queue"]:
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def index_by_id(items):
    indexed = {}
    for item in items:
        if isinstance(item, dict):
            job_id = item.get("id") or item.get("job_id")
            if job_id:
                indexed[job_id] = item
    return indexed


def get_scheduler_state_block(data):
    if not isinstance(data, dict):
        return {}
    nested = data.get("mesh_scheduler_state")
    if isinstance(nested, dict):
        return nested
    return data


def md_value(value):
    return "null" if value is None else str(value)


def main():
    queue_data = load_json(JOB_QUEUE)
    dlq_data = load_json(DLQ)
    results_data = load_json(JOB_RESULTS)
    sched_state_data = load_json(SCHED_STATE)

    queue_jobs = normalize_jobs_from_queue(queue_data)
    dlq_jobs = normalize_jobs_from_dlq(dlq_data)
    result_jobs = normalize_jobs_from_results(results_data)
    sched_state = get_scheduler_state_block(sched_state_data)

    queue_idx = index_by_id(queue_jobs)
    dlq_idx = index_by_id(dlq_jobs)
    result_idx = index_by_id(result_jobs)

    suspected = []
    confirmed = []
    findings = []

    for job_id, job in queue_idx.items():
        status = str(job.get("status", "")).strip().lower()
        retry_count = int(job.get("retry_count", 0) or 0)
        max_retries = int(job.get("max_retries", 0) or 0)
        result = result_idx.get(job_id)
        in_dlq = job_id in dlq_idx

        reasons = []

        if status == "pending":
            reasons.append("pending_without_progress")

        if status == "retry" and retry_count >= max_retries:
            reasons.append("retry_loop_suspected")

        if status == "done" and result is None:
            reasons.append("done_without_evidence")

        if status == "dead" and not in_dlq:
            reasons.append("dead_without_dlq_record")

        if result is not None:
            result_node = result.get("node") or result.get("target_node")
            queue_node = job.get("node")
            if result_node and queue_node and result_node != queue_node:
                reasons.append("node_mismatch_suspected")

        if reasons:
            suspected.append({
                "id": job_id,
                "node": job.get("node"),
                "status": status,
                "reasons": reasons
            })

    summary_state = sched_state.get("status") if isinstance(sched_state, dict) else None
    done_count = sched_state.get("done_count") if isinstance(sched_state, dict) else None
    retry_count_state = sched_state.get("retry_count") if isinstance(sched_state, dict) else None
    dead_count = sched_state.get("dead_count") if isinstance(sched_state, dict) else None
    run_ok = sched_state.get("run_ok") if isinstance(sched_state, dict) else None
    overall_ok = sched_state.get("overall_ok") if isinstance(sched_state, dict) else None

    findings.append({
        "scheduler_state_status": summary_state,
        "done_count": done_count,
        "retry_count": retry_count_state,
        "dead_count": dead_count,
        "run_ok": run_ok,
        "overall_ok": overall_ok,
        "queue_jobs_total": len(queue_jobs),
        "result_jobs_total": len(result_jobs),
        "dlq_jobs_total": len(dlq_jobs)
    })

    stuck_payload = {
        "phase": "118B",
        "created_at": CREATED_AT,
        "analysis_mode": True,
        "summary": {
            "suspected_total": len(suspected),
            "confirmed_total": len(confirmed)
        },
        "suspected_jobs": suspected,
        "confirmed_jobs": confirmed,
        "classification_rules": [
            "pending_without_progress",
            "retry_loop_suspected",
            "done_without_evidence",
            "dead_without_dlq_record",
            "node_mismatch_suspected"
        ],
        "analysis_findings": findings,
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    with STUCK_JOBS.open("w", encoding="utf-8") as f:
        json.dump(stuck_payload, f, indent=2, ensure_ascii=False)
        f.write("\n")

    report_lines = [
        "# FASE 118B — Reconciliation Analysis",
        "",
        "## Summary",
        f"- suspected_total: {len(suspected)}",
        f"- confirmed_total: {len(confirmed)}",
        f"- scheduler_state_status: {md_value(summary_state)}",
        f"- done_count: {md_value(done_count)}",
        f"- retry_count: {md_value(retry_count_state)}",
        f"- dead_count: {md_value(dead_count)}",
        f"- run_ok: {md_value(run_ok)}",
        f"- overall_ok: {md_value(overall_ok)}",
        f"- queue_jobs_total: {len(queue_jobs)}",
        f"- result_jobs_total: {len(result_jobs)}",
        f"- dlq_jobs_total: {len(dlq_jobs)}",
        "",
        "## Suspected Jobs"
    ]

    if suspected:
        for item in suspected:
            report_lines.append(
                f"- {item['id']} | node={item.get('node')} | status={item.get('status')} | reasons={','.join(item.get('reasons', []))}"
            )
    else:
        report_lines.append("- none")

    report_lines.extend([
        "",
        "## Governance",
        "- deploy_executed: false",
        "- production_changed: false",
        ""
    ])

    DOC_OUT.write_text("\n".join(report_lines), encoding="utf-8")

    packet = {
        "created_at": CREATED_AT,
        "phase": "118B",
        "status": "reconciliation_analysis_completed",
        "artifacts_created": [
            "scheduler/stuck_jobs.json",
            str(DOC_OUT.relative_to(BASE))
        ],
        "summary": {
            "suspected_total": len(suspected),
            "confirmed_total": len(confirmed),
            "scheduler_state_status": summary_state,
            "done_count": done_count,
            "retry_count": retry_count_state,
            "dead_count": dead_count,
            "run_ok": run_ok,
            "overall_ok": overall_ok,
            "queue_jobs_total": len(queue_jobs),
            "result_jobs_total": len(result_jobs),
            "dlq_jobs_total": len(dlq_jobs)
        },
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    PACKET_OUT.parent.mkdir(parents=True, exist_ok=True)
    with PACKET_OUT.open("w", encoding="utf-8") as f:
        json.dump(packet, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("[OK] reconciliation analysis completed")
    print(json.dumps(packet["summary"], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
