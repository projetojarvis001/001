#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timezone

BASE = Path("/Users/jarvis001/jarvis")

CAPABILITY_REGISTRY = BASE / "registry/capability_registry.json"
SERVICE_REGISTRY = BASE / "registry/service_registry.json"
HEALTH_WEIGHTS = BASE / "scheduler/health_weights.json"
STATE_FILE = BASE / "registry/capability_service_registry_state.json"

OUT_JSON = BASE / "registry/service_eligibility_matrix.json"

REPORT_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
CREATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

DOC_OUT = BASE / f"docs/generated/phase118e_service_eligibility_resolution_{REPORT_TS}.md"
PACKET_OUT = BASE / f"logs/executive/phase118e_service_eligibility_resolution_packet_{REPORT_TS}.json"


def load_json(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"arquivo nao encontrado: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def node_capabilities(node_data):
    caps = node_data.get("capabilities", []) if isinstance(node_data, dict) else []
    return set(caps) if isinstance(caps, list) else set()


def node_weight(node_name, health_weights):
    nodes = health_weights.get("nodes", {}) if isinstance(health_weights, dict) else {}
    node = nodes.get(node_name, {})
    return float(node.get("effective_weight", 0.0) or 0.0), str(node.get("health_status", "unknown"))


def main():
    capability_registry = load_json(CAPABILITY_REGISTRY)
    service_registry = load_json(SERVICE_REGISTRY)
    health_weights = load_json(HEALTH_WEIGHTS)
    state_data = load_json(STATE_FILE)

    nodes = capability_registry.get("nodes", {})
    services = service_registry.get("services", {})

    matrix = {
        "phase": "118E",
        "created_at": CREATED_AT,
        "mode": "eligibility_resolution_only",
        "services": {},
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    summary = {
        "services_total": 0,
        "eligible_bindings_total": 0,
        "blocked_bindings_total": 0
    }

    for service_name, service_data in services.items():
        required = service_data.get("required_capabilities", [])
        eligible_nodes_declared = service_data.get("eligible_nodes", [])

        resolved_eligible = []
        blocked = []

        for node_name in eligible_nodes_declared:
            node_data = nodes.get(node_name, {})
            caps = node_capabilities(node_data)
            required_ok = all(cap in caps for cap in required)
            weight, health_status = node_weight(node_name, health_weights)
            health_ok = weight > 0.0 and health_status == "healthy"

            record = {
                "node": node_name,
                "required_capabilities_ok": required_ok,
                "effective_weight": weight,
                "health_status": health_status
            }

            if required_ok and health_ok:
                resolved_eligible.append(record)
                summary["eligible_bindings_total"] += 1
            else:
                blocked.append(record)
                summary["blocked_bindings_total"] += 1

        matrix["services"][service_name] = {
            "type": service_data.get("type"),
            "required_capabilities": required,
            "declared_eligible_nodes": eligible_nodes_declared,
            "resolved_eligible_nodes": resolved_eligible,
            "blocked_nodes": blocked,
            "status": "resolved"
        }

        summary["services_total"] += 1

    with OUT_JSON.open("w", encoding="utf-8") as f:
        json.dump(matrix, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if isinstance(state_data, dict):
        state_data["created_at"] = CREATED_AT
        state_data["status"] = "service_eligibility_resolved"
        state_data["mode"] = "analysis_only"
        state_data["registry_policy"] = {
            "analysis_only": True,
            "eligibility_resolution_enabled": True,
            "service_binding_enabled": False,
            "capability_routing_enabled": False
        }
        state_data["last_eligibility_summary"] = summary
        state_data["governance"] = {
            "deploy_executed": False,
            "production_changed": False
        }

        with STATE_FILE.open("w", encoding="utf-8") as f:
            json.dump(state_data, f, indent=2, ensure_ascii=False)
            f.write("\n")

    lines = [
        "# FASE 118E — Service Eligibility Resolution",
        "",
        "## Summary",
        f"- services_total: {summary['services_total']}",
        f"- eligible_bindings_total: {summary['eligible_bindings_total']}",
        f"- blocked_bindings_total: {summary['blocked_bindings_total']}",
        "",
        "## Services"
    ]

    for service_name, service_data in matrix["services"].items():
        eligible = ",".join(item["node"] for item in service_data["resolved_eligible_nodes"]) or "none"
        blocked = ",".join(item["node"] for item in service_data["blocked_nodes"]) or "none"
        lines.append(f"- {service_name} | eligible={eligible} | blocked={blocked}")

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
        "phase": "118E",
        "status": "service_eligibility_resolution_completed",
        "artifacts_created": [
            "registry/service_eligibility_matrix.json",
            "registry/capability_service_registry_state.json",
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

    print("[OK] service eligibility resolution completed")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
