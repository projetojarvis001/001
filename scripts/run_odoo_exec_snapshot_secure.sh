#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

./scripts/load_odoo_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/odoo_watchdog.env

./scripts/odoo_weekly_executive_snapshot.sh
