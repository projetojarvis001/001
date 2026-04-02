# MESH HEARTBEAT

## Objetivo
Definir a verificacao basica de presenca entre Core e Vision.

## Fluxo atual
1. o Core consulta o endpoint /health do Vision
2. o Vision responde com ok=true e service=vision
3. o DevOps registra o resultado em log

## Sinais atuais da malha
- core health -> http://localhost:3000/health
- vision health -> http://VISION_HOST:5005/health
- comando devops -> vision health
- comando devops -> stack health

## Resultado esperado
- Core operacional
- Vision operacional
- conectividade entre Core e Vision validada

## Proximo nivel
- registrar last_seen do Vision
- classificar estados online/degraded/offline
- compor mesh status consolidado
