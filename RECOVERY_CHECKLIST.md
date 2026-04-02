# RECOVERY CHECKLIST

## Diagnostico inicial
1. validar docker compose ps
2. validar logs do core
3. validar logs do postgres
4. validar logs do redis
5. validar conectividade com Vision

## Recuperacao basica
1. reiniciar jarvis-core
2. validar health do core
3. validar acesso ao banco
4. validar redis
5. reexecutar boot checklist

## Git e seguranca operacional
1. nao fazer push com working tree sujo
2. validar branch atual antes de acao critica
3. validar remote origin antes de push

## Escalada
1. registrar incidente
2. registrar causa aparente
3. registrar acao tomada
4. registrar resultado da recuperacao
