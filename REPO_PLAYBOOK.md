# REPO PLAYBOOK

## Objetivo
Consolidar os comandos operacionais atuais de repositorio disponiveis no DevOps.

## Comandos atuais
- devops: repo branch
- devops: repo remote
- devops: repo diff
- devops: repo doctor
- devops: repo status
- devops: repo last commits
- devops: repo pending

## O que cada um responde
- repo branch -> branch atual e upstream
- repo remote -> remotes fetch/push e existencia de origin
- repo diff -> diff pendente resumido
- repo doctor -> consolidado operacional do repositorio
- repo status -> estado geral atual
- repo last commits -> ultimos commits
- repo pending -> itens pendentes no working tree

## Uso pratico
- diagnosticar repositorio antes de commit ou push
- validar branch e remote
- validar se ha diff pendente
- reduzir shell manual

## Proximo nivel
- repo sync
- playbook automatico de preparo para push
- validacao automatica pre-commit e pre-push
