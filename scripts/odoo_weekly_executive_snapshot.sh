#!/usr/bin/env bash
set -euo pipefail

echo "===== ODOO EXECUTIVE SNAPSHOT ====="

LAST100="$(ls -1t logs/executive/phase100_odoo_closure_packet_*.json 2>/dev/null | head -n 1 || true)"
LAST99="$(ls -1t logs/executive/phase99_odoo_alert_fallback_packet_*.json 2>/dev/null | head -n 1 || true)"
LAST95="$(ls -1t logs/executive/phase95_odoo_alert_delivery_packet_*.json 2>/dev/null | head -n 1 || true)"

echo "PHASE100=${LAST100}"
echo "PHASE99=${LAST99}"
echo "PHASE95=${LAST95}"

echo
[ -n "${LAST100}" ] && echo "===== PHASE 100 =====" && cat "${LAST100}" | jq .
echo
[ -n "${LAST99}" ] && echo "===== PHASE 99 =====" && cat "${LAST99}" | jq .
echo
[ -n "${LAST95}" ] && echo "===== PHASE 95 =====" && cat "${LAST95}" | jq .
