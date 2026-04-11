# FASE 118D — Lease/Lock and Stuck Job Recovery Init

## Objetivo
Inicializar a camada de lease/lock por job e recuperação de stuck jobs sem alterar produção,
preparando ownership, TTL e prevenção de execução duplicada.

## Escopo deste bloco
- criar job_leases
- criar estado inicial de stuck_recovery
- declarar inputs oficiais da fase
- manter operação em analysis_only

## Política inicial
- analysis_only: true
- lease_enforced: false
- auto_recover_enabled: false
- lease_break_enabled: false
- duplicate_execution_blocking: false

## Próximo passo
Simular leases por job e validar regras de ownership e TTL sem tocar na fila real.
