#!/bin/bash
LOG="/tmp/boot_jarvis.log"
echo "[$(date)] Boot iniciando..." >> $LOG

sleep 15

open -a OrbStack >> $LOG 2>&1
sleep 20

cd /Users/jarvis001/jarvis && docker compose up -d >> $LOG 2>&1
echo "[$(date)] Docker compose up executado" >> $LOG

sleep 5
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:3000/health)
if [ "$HTTP" = "200" ]; then
  echo "[$(date)] Core OK" >> $LOG
else
  echo "[$(date)] Core falhou — retentando" >> $LOG
  docker compose up -d >> $LOG 2>&1
fi
echo "[$(date)] Boot concluído" >> $LOG
