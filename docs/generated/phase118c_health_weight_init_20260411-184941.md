# FASE 118C — Health-Weighted Scheduling Init

## Objetivo
Inicializar a camada de health-weighted scheduling sem alterar produção,
preparando pesos por nó, política de roteamento e futura prevenção de dispatch
para nós degradados.

## Escopo deste bloco
- criar health_weights
- criar estado inicial do scheduler ponderado por saúde
- declarar inputs oficiais da fase
- manter operação em analysis_only

## Política inicial
- analysis_only: true
- routing_enforced: false
- block_degraded_nodes: false
- prefer_high_weight_nodes: false

## Próximo passo
Ler estados reais de health e registry para calcular pesos efetivos por nó.
