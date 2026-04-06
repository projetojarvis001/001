#!/bin/bash
LOG="/Volumes/JARVIS-COLD/logs-warm/watchdog.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

check_and_restart() {
  local name=$1
  local dir=$2
  
  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "[$TIMESTAMP] DEAD: $name — ressuscitando..." >> $LOG
    cd $dir && docker compose up -d >> $LOG 2>&1
    echo "[$TIMESTAMP] REVIVED: $name" >> $LOG
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}&text=⚠️ J.A.R.V.I.S. ressuscitou: ${name}" > /dev/null 2>&1
  fi
}

source /Users/jarvis001/jarvis/.env

check_and_restart "jarvis-jarvis-core-1" "/Users/jarvis001/jarvis"
check_and_restart "redis" "/Users/jarvis001/jarvis"
check_and_restart "jarvis-postgres-1" "/Users/jarvis001/jarvis"
check_and_restart "jarvis-grafana-1" "/Users/jarvis001/jarvis"
check_and_restart "jarvin-universal-core-1" "/Users/jarvis001/jarvin-universal"
check_and_restart "jarvin-universal-vision-1" "/Users/jarvis001/jarvin-universal"
check_and_restart "jarvin-universal-postgres-1" "/Users/jarvis001/jarvin-universal"
