# ODOO Watchdog — Esteira Fases 91 a 100

## Resumo executivo
A esteira consolidou o watchdog remoto do Odoo com cron real, retention, alertas, drift control, restore operacional, fallback e handoff executivo.

Baseline final:
- commit fase 100: 487a344
- tag final: baseline-fase100-ok-20260410

## Escopo entregue
- watchdog remoto em produção
- cron operacional
- retention e housekeeping
- alerta real via Slack webhook
- drift control
- restore operacional
- fallback de alerta com fila local
- checklist operacional
- handoff executivo

## Comandos principais

Validar watchdog remoto:
    ./scripts/phase93_odoo_remote_watchdog_probe.sh

Validar retention:
    ./scripts/phase94_odoo_watchdog_retention_probe.sh

Validar alerta:
    ./scripts/phase95_odoo_alert_delivery_probe.sh

Validar drift:
    ./scripts/phase97_odoo_watchdog_drift_probe.sh

Validar restore:
    ./scripts/phase98_odoo_watchdog_restore_probe.sh

Validar fallback:
    ./scripts/phase99_odoo_alert_fallback_probe.sh

Validar fechamento executivo:
    ./scripts/validate_fase100.sh

## Estrutura remota esperada
Base:
- /home/wps/odoo_watchdog

Arquivos principais:
- /home/wps/odoo_watchdog/watchdog_run.sh
- /home/wps/odoo_watchdog/.env
- /home/wps/odoo_watchdog/send_alert.sh
- /home/wps/odoo_watchdog/alert.env

Logs:
- /home/wps/odoo_watchdog/logs/last_run.json
- /home/wps/odoo_watchdog/logs/last_run.ok
- /home/wps/odoo_watchdog/logs/alert_delivery_*.json
- /home/wps/odoo_watchdog/logs/failed_queue/alert_failed_*.json

## Governança
- usar baseline/tag antes de mudanças estruturais
- validar webhook antes de trocar produção
- revalidar fallback após ajustes em send_alert.sh
- preservar trilha em logs/executive e docs/generated

## Veredito
A esteira 91–100 deixou o Odoo com uma camada operacional auditável, recuperável e transferível.
