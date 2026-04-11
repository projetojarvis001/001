#!/usr/bin/env bash
set -euo pipefail

mkdir -p decision_engine runtime/decision_engine logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_ENGINE="decision_engine/engine_state.json"
OUT_PHASE_JSON="logs/executive/phase108_decision_engine_build_${TS}.json"
OUT_MD="docs/generated/phase108_decision_engine_build_${TS}.md"

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_snapshot_*.json' | sort | tail -n 1)"
RULES_FILE="decision_engine/rules.json"

python3 - <<PY > "${OUT_ENGINE}"
import json
from pathlib import Path

snap = json.loads(Path("${SNAP_FILE}").read_text())
rules_data = json.loads(Path("${RULES_FILE}").read_text())

ctx = snap["decision_snapshot"]

def normalize_condition(cond: str) -> str:
    return (
        cond.replace(" true", " True")
            .replace(" false", " False")
            .replace("== true", "== True")
            .replace("== false", "== False")
            .replace("!= true", "!= True")
            .replace("!= false", "!= False")
    )

def eval_condition(cond: str, context: dict) -> bool:
    expr = normalize_condition(cond)
    return bool(eval(expr, {"__builtins__": {}}, context))

decisions = []
for rule in rules_data["rules"]:
    matched = eval_condition(rule["condition"], ctx)
    decisions.append({
        "id": rule["id"],
        "description": rule["description"],
        "condition": rule["condition"],
        "severity": rule["severity"],
        "action": rule["action"],
        "mode": rule["mode"],
        "matched": matched
    })

triggered = [d for d in decisions if d["matched"]]

out = {
    "created_at": snap["created_at"],
    "decision_engine": {
        "rules_file": "${RULES_FILE}",
        "snapshot_file": "${SNAP_FILE}",
        "rules_total": len(decisions),
        "triggered_total": len(triggered),
        "triggered_ids": [d["id"] for d in triggered],
        "highest_severity": (
            "critical" if any(d["severity"] == "critical" for d in triggered) else
            "high" if any(d["severity"] == "high" for d in triggered) else
            "medium" if any(d["severity"] == "medium" for d in triggered) else
            "none"
        ),
        "auto_actions_possible": [d["action"] for d in triggered if d["mode"] == "safe_auto"],
        "advisories": [d["action"] for d in triggered if d["mode"] == "advisory"],
        "decisions": decisions,
        "overall_ok": True
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

RULES_TOTAL="$(jq -r '.decision_engine.rules_total' "${OUT_ENGINE}")"
TRIGGERED_TOTAL="$(jq -r '.decision_engine.triggered_total' "${OUT_ENGINE}")"
HIGHEST_SEVERITY="$(jq -r '.decision_engine.highest_severity' "${OUT_ENGINE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg engine_file "${OUT_ENGINE}" \
  --argjson rules_total "${RULES_TOTAL}" \
  --argjson triggered_total "${TRIGGERED_TOTAL}" \
  --arg highest_severity "${HIGHEST_SEVERITY}" \
  '{
    created_at: $created_at,
    decision_engine_build: {
      engine_file: $engine_file,
      rules_total: $rules_total,
      triggered_total: $triggered_total,
      highest_severity: $highest_severity,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_PHASE_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 108 — Decision Engine Build

## Engine
- engine_file: ${OUT_ENGINE}
- rules_total: ${RULES_TOTAL}
- triggered_total: ${TRIGGERED_TOTAL}
- highest_severity: ${HIGHEST_SEVERITY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase108 build gerado em ${OUT_PHASE_JSON}"
cat "${OUT_PHASE_JSON}" | jq .
echo
echo "[OK] engine em ${OUT_ENGINE}"
cat "${OUT_ENGINE}" | jq .
