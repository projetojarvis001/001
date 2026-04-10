#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

source /Users/jarvis001/jarvis/.env
DATE=$(date '+%Y-%m-%d_%H-%M')
BACKUP_DIR="/Volumes/JARVIS-COLD/backups/${DATE}"
mkdir -p $BACKUP_DIR

echo "[${DATE}] Iniciando backup..." 

cp -r /Users/jarvis001/jarvis/.env $BACKUP_DIR/jarvis.env.bak
cp -r /Users/jarvis001/jarvis/docker-compose.yml $BACKUP_DIR/
cp -r /Users/jarvis001/jarvis/.env $BACKUP_DIR/jarvis.env.bak
cp -r /Users/jarvis001/jarvis/docker-compose.yml $BACKUP_DIR/jarvis-compose.bak

docker exec jarvis-postgres-1 pg_dump -U jarvis_admin jarvis_db > $BACKUP_DIR/jarvis_db.sql 2>/dev/null
docker exec jarvis-postgres-1 pg_dump -U jarvin jarvin > $BACKUP_DIR/jarvin_db.sql 2>/dev/null

cp -r /Users/jarvis001/jarvis/core/data $BACKUP_DIR/knowledge_data
cp -r /Users/jarvis001/jarvis/core/src $BACKUP_DIR/src_code

find /Volumes/JARVIS-COLD/backups -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null

SIZE=$(du -sh $BACKUP_DIR | cut -f1)
echo "[${DATE}] Backup completo: $BACKUP_DIR ($SIZE)"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}&text=✅ Backup J.A.R.V.I.S.: ${DATE} (${SIZE})" > /dev/null 2>&1
