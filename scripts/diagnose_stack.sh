#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STACK_JSON="$(curl -s --max-time 15 http://127.0.0.1:3000/stack/health || true)"
CORE_JSON="$(curl -s --max-time 10 http://127.0.0.1:3000/health || true)"

DOCKER_PS="$(docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null || true)"

has_container_running() {
  local name="$1"
  printf "%s\n" "$DOCKER_PS" | grep -q "^${name} Up"
}

core_ok="$(printf "%s" "$CORE_JSON" | jq -r '.ok // false' 2>/dev/null || echo false)"
stack_ok="$(printf "%s" "$STACK_JSON" | jq -r '.ok // false' 2>/dev/null || echo false)"
semantic_ok="$(printf "%s" "$STACK_JSON" | jq -r '.checks.semantic.ok // false' 2>/dev/null || echo false)"
whisper_ok="$(printf "%s" "$STACK_JSON" | jq -r '.checks.whisper.ok // false' 2>/dev/null || echo false)"
bridge_ok="$(printf "%s" "$STACK_JSON" | jq -r '.checks.bridge.ok // false' 2>/dev/null || echo false)"

if [ "$stack_ok" = "true" ]; then
  jq -n \
    --arg kind "healthy" \
    --arg detail "stack saudável" \
    '{ok:true,kind:$kind,detail:$detail}'
  exit 0
fi

if [ "$core_ok" != "true" ]; then
  if has_container_running "jarvis-jarvis-core-1"; then
    jq -n \
      --arg kind "core_local" \
      --arg detail "jarvis-core em execução mas /health falhou" \
      '{ok:false,kind:$kind,detail:$detail}'
    exit 0
  else
    jq -n \
      --arg kind "core_local" \
      --arg detail "jarvis-core parado" \
      '{ok:false,kind:$kind,detail:$detail}'
    exit 0
  fi
fi

if ! has_container_running "redis"; then
  jq -n \
    --arg kind "redis_local" \
    --arg detail "redis parado" \
    '{ok:false,kind:$kind,detail:$detail}'
  exit 0
fi

if ! has_container_running "jarvis-postgres-1"; then
  jq -n \
    --arg kind "postgres_local" \
    --arg detail "postgres parado" \
    '{ok:false,kind:$kind,detail:$detail}'
  exit 0
fi

if [ "$semantic_ok" != "true" ]; then
  jq -n \
    --arg kind "vision_remote_semantic" \
    --arg detail "vision semantic indisponível" \
    '{ok:false,kind:$kind,detail:$detail}'
  exit 0
fi

if [ "$whisper_ok" != "true" ]; then
  jq -n \
    --arg kind "vision_remote_whisper" \
    --arg detail "vision whisper indisponível" \
    '{ok:false,kind:$kind,detail:$detail}'
  exit 0
fi

if [ "$bridge_ok" != "true" ]; then
  jq -n \
    --arg kind "vision_remote_bridge" \
    --arg detail "vision bridge indisponível" \
    '{ok:false,kind:$kind,detail:$detail}'
  exit 0
fi

jq -n \
  --arg kind "unknown" \
  --arg detail "falha não classificada" \
  '{ok:false,kind:$kind,detail:$detail}'
