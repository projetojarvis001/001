# SERVICE MAP

## Servicos principais
- jarvis-core -> porta 3000 -> API principal e roteamento
- grafana -> porta 3001 -> observabilidade
- postgres -> porta 5432 -> persistencia de logs e decisoes
- redis -> porta 6379 -> suporte operacional e mensageria

## Caminhos principais
- repositorio local -> ~/jarvis
- core -> ~/jarvis/core
- arquivo de compose -> ~/jarvis/docker-compose.yml

## Dependencias
- jarvis-core depende de postgres e redis
- vision depende de conectividade com core

## Validacoes operacionais
- API core: http://localhost:3000
- Grafana: http://localhost:3001
- Postgres: localhost:5432
- Redis: localhost:6379

## Observacoes
- push so com working tree limpo
- branch main protegida contra delete e force push
