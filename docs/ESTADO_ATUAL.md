# ESTADO ATUAL JARVIS — 15/04/2026

## PROXIMA ACAO IMEDIATA
pgvector OK no Docker postgres:pgvector:pg16
Tabela documents criada com 0 registros
PRECISA: reingerir os 495 vetores via semantic_api do VISION
PRECISA: reiniciar semantic_api do VISION para reconectar ao banco novo

## PROBLEMA EM RESOLUCAO
- semantic_api.py no VISION usava docker exec vision-postgres-vision-1 que nao existe
- Banco migrado para pgvector/pgvector:pg16 no JARVIS docker
- semantic_api.py precisa ser reescrito para usar psycopg2 direto

## ESTADO SISTEMA
- 15 agentes :7777-7791 operacionais
- 495 vetores NO BANCO ANTIGO (precisam ser reingeridos)
- pgvector novo banco VAZIO esperando reingestao
- SYSTEM_PROMPT cirurgico aplicado
- Cost Router 6 providers OK
- Grafana com dados reais OK

## CREDENCIAIS BANCO
host: localhost (do JARVIS) ou 192.168.8.121 (do VISION)
port: 5432
dbname: jarvis_db
user: jarvis_admin
password: ver PG_PASSWORD no .env

## VISION SEMANTIC_API
arquivo: /Users/vision/jarvis-vision/semantic_api.py
problema: usa docker exec que nao existe
solucao: substituir por psycopg2 direto apontando para 192.168.8.121:5432
