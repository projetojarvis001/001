# HEALTHCHECK STACK

## Core
- curl http://localhost:3000/health

## Postgres
- docker compose exec -T postgres pg_isready -U jarvis_admin -d jarvis_db

## Redis
- docker compose exec -T redis redis-cli -a 'W!@#wps@2026' ping

## Resultado esperado
- Core responde JSON com ok=true
- Postgres responde accepting connections
- Redis responde PONG

## Observacao
- em fase futura, trocar teste manual do Redis por rotina sem segredo exposto em comando
