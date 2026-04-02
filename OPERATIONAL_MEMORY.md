# MEMORIA OPERACIONAL CURTA

## Objetivo
Permitir consulta rapida da atividade recente do agente DevOps sem depender de SQL manual.

## Fonte atual
- tabela jarvis_logs
- agente filtrado: devops
- janela atual: ultimos 10 eventos

## Comando atual
- devops: recent logs

## O que retorna
- created_at
- action_type
- status
- input_summary

## Uso operacional
- identificar ultimo comando executado
- revisar eventos recentes do DevOps
- entender sequencia curta de acoes
- acelerar diagnostico sem abrir psql

## Proximo nivel
- ultima missao
- ultimas decisoes pendentes
- ultimo status da malha
- resumo consolidado recente
