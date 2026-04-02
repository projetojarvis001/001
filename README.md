# J.A.R.V.I.S. + V.I.S.I.O.N.

Sistema operacional cognitivo distribuído para automação operacional, observabilidade, DevOps assistido e execução multimodal progressiva.

## Visão
O projeto J.A.R.V.I.S. + V.I.S.I.O.N. foi concebido para atuar como uma malha de inteligência operacional distribuída, capaz de interpretar contexto, executar ações, coordenar múltiplos nós e evoluir de forma progressiva com governança, auditoria e resiliência.

## Componentes principais
- **jarvis-core**: núcleo de roteamento, execução, contexto e governança
- **vision**: agente visual distribuído para percepção e suporte multimodal
- **postgres**: persistência de logs, decisões e trilhas operacionais
- **redis**: comunicação e suporte à malha distribuída
- **grafana**: visualização operacional e observabilidade

## Health endpoint
- `GET /health` -> status básico do `jarvis-core`
- resposta esperada:
  - `ok`
  - `service`
  - `timestamp`

## Capacidades já implementadas
- roteamento central de comandos
- integração entre Core e Vision
- approval gate para ações sensíveis
- Git host-aware no Mac principal
- comandos executivos de repositório: `repo status`, `repo last commits`, `repo pending`
- trilha de auditoria persistida em banco
- integração com GitHub via SSH

## Subida local
```bash
docker compose build
docker compose up -d
```

## Autor
Projeto operado por Wagner Silva e evoluído com suporte do ecossistema J.A.R.V.I.S. + V.I.S.I.O.N.
