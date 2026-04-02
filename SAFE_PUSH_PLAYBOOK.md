# SAFE PUSH PLAYBOOK

## Objetivo
Definir o fluxo seguro antes de qualquer push no repositorio.

## Comandos envolvidos
- devops: prepare repo
- devops: repo commit plan
- devops: repo commit message
- devops: repo ready
- devops: safe push plan

## Fluxo atual
1. preparar o estado do repositorio
2. validar se existe diff e arquivos pendentes
3. sugerir mensagem de commit
4. validar se o repositorio esta pronto para push
5. so entao aprovar e executar push

## Regras operacionais
- nao fazer push com working tree sujo
- nao fazer push sem upstream
- nao fazer push sem origin
- revisar diff antes de commit

## Resultado esperado
- push apenas quando ready_for_push = true
- qualquer pendencia gera bloqueio e proximo passo objetivo

## Proximo nivel
- executar git add por playbook
- executar git commit por playbook
- revalidar repo ready automaticamente antes do push
