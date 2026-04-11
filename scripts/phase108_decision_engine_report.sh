#!/usr/bin/env bash
set -euo pipefail

mkdir -p decision_engine logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
ENGINE_FILE="decision_engine/engine_state.json"
OUT_REPORT="decision_engine/engine_report.md"
OUT_JSON="logs/executive/phase108_decision_engine_report_${TS}.json"
OUT_MD="docs/generated/phase108_decision_engine_report_${TS}.md"

python3 - <<PY
import json
from pathlib import Path

engine = json.loads(Path("${ENGINE_FILE}").read_text())
de = engine["decision_engine"]

lines = []
lines.append("# Decision Engine Report")
lines.append("")
lines.append(f"- rules_total: {de['rules_total']}")
lines.append(f"- triggered_total: {de['triggered_total']}")
lines.append(f"- highest_severity: {de['highest_severity']}")
lines.append("")

lines.append("## Triggered")
if de["triggered_total"] == 0:
    lines.append("- none")
else:
    for d in de["decisions"]:
        if d["matched"]:
            lines.append(
                f"- {d['id']} | severity={d['severity']} | mode={d['mode']} | action={d['action']}"
            )

lines.append("")
lines.append("## Auto Actions Possible")
if de["auto_actions_possible"]:
    for a in de["auto_actions_possible"]:
        lines.append(f"- {a}")
else:
    lines.append("- none")

lines.append("")
lines.append("## Advisories")
if de["advisories"]:
    for a in de["advisories"]:
        lines.append(f"- {a}")
else:
    lines.append("- none")

lines.append("")
lines.append("## Veredito")
if de["triggered_total"] == 0:
    lines.append("Motor de decisao sem incidentes ativos no momento.")
else:
    lines.append("Motor de decisao detectou gaps reais e priorizou auto-remediation segura e advisories.")

Path("${OUT_REPORT}").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg report_file "${OUT_REPORT}" \
  '{
    created_at: $created_at,
    decision_engine_report: {
      report_file: $report_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 108 — Decision Engine Report

## Report
- report_file: ${OUT_REPORT}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase108 report gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
sed -n '1,260p' "${OUT_REPORT}"
