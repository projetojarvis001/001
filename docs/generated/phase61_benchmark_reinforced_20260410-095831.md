# FASE 61 — Benchmark Reforçado

## Objetivo
Reduzir falso positivo, flap e regressão silenciosa.

## Casos
- ops_flap_001: Oscilação curta do VISION -> log interno apenas
- ops_flap_002: Mensagem repetida -> cooldown
- ops_recovery_003: Recuperação -> mensagem única
- ops_timeout_004: Timeout curto -> degradado antes de crítico
- ops_gate_005: Benchmark abaixo do gate -> bloqueio
- ops_gate_006: Smoke sem verde -> bloqueio
- ops_release_007: Promoção saudável -> não herdar rollback antigo
- ops_exec_008: Packet diário -> refletir estado atual

## Gate policy
- benchmark_required: true
- smoke_required: true
- release_reliability_min_score: 70
- operational_score_min_score: 80
