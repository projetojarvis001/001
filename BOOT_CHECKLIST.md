# BOOT CHECKLIST

## Subida local
1. conferir variaveis em .env
2. iniciar stack com docker compose up -d
3. validar containers com docker compose ps
4. testar API do core em http://localhost:3000
5. validar postgres e redis
6. validar Grafana em http://localhost:3001

## Git e repositório
1. conferir git status
2. conferir branch atual
3. conferir remote origin

## Vision e malha
1. validar Vision online
2. validar comunicacao Core -> Vision
3. validar logs recentes

## Encerramento
1. registrar incidente se houver falha
2. nao executar push com working tree sujo
