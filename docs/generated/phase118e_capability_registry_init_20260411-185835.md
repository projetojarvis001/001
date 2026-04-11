# FASE 118E — Capability Registry + Service Registry Init

## Objetivo
Inicializar a camada de capability registry e service registry sem alterar produção,
preparando elegibilidade por nó, capacidades declaradas e futuros bindings por serviço.

## Escopo deste bloco
- criar capability_registry
- criar service_registry
- criar estado inicial do registry unificado
- declarar inputs oficiais da fase
- manter operação em analysis_only

## Política inicial
- analysis_only: true
- eligibility_resolution_enabled: false
- service_binding_enabled: false
- capability_routing_enabled: false

## Próximo passo
Cruzar capacidades declaradas com saúde real da malha e resolver elegibilidade efetiva por serviço.
