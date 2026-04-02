# FONTES DE MEMORIA OPERACIONAL

## Objetivo
Mapear de onde o ecossistema extrai memoria curta operacional nesta fase.

## Fontes atuais
- jarvis_logs -> eventos operacionais recentes
- pending_decisions -> decisoes pendentes e aprovadas
- health endpoints -> estado atual do core e vision
- comandos devops estruturados -> leitura resumida do estado recente

## Comandos atuais
- devops: recent logs
- devops: last mission
- devops: recent decisions
- devops: stack health
- devops: vision health
- devops: mesh status

## Limites atuais
- memoria ainda curta e operacional
- nao ha resumo consolidado automatico
- nao ha last_seen persistido do Vision
- nao ha memoria semantica por missao

## Proximo nivel
- resumo recente consolidado
- status persistido da malha
- memoria por missao
- memoria compartilhada core vision
