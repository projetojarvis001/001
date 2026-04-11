#!/usr/bin/env bash
set -euo pipefail

mkdir -p capability docs/generated logs/executive runtime/capability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_REPORT="capability/system_capability_matrix_report.md"
OUT_JSON="logs/executive/phase107_capability_matrix_report_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_report_${TS}.md"

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("capability/system_capability_matrix.json").read_text())
m = data["capability_matrix"]

lines = []
lines.append("# Capability Matrix Report")
lines.append("")
lines.append(f"- overall_score: {m['overall_score']}")
lines.append(f"- classification: {m['classification']}")
lines.append("")
lines.append("## Capacidades")
for item in m["capabilities"]:
    lines.append(f"- {item['name']}: {item['score']}/100 | status={item['status']} | evidence={item['evidence']} | gap={item['gap']}")
lines.append("")
lines.append("## Forças")
for x in m["top_strengths"]:
    lines.append(f"- {x}")
lines.append("")
lines.append("## Gaps")
for x in m["top_gaps"]:
    lines.append(f"- {x}")
lines.append("")
lines.append("## Veredito")
lines.append("O sistema tem base operacional séria, mas ainda está longe de qualquer leitura honesta de 100% em autonomia, inteligência, ubiquidade ou ML.")

Path("capability/system_capability_matrix_report.md").write_text("\n".join(lines), encoding="utf-8")
print("\n".join(lines))
PY

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg report_file "${OUT_REPORT}" \
  '{
    created_at: $created_at,
    capability_report: {
      report_file: $report_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 107 — Capability Matrix Report

## Report
- report_file: ${OUT_REPORT}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 report gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
sed -n '1,260p' "${OUT_REPORT}"
