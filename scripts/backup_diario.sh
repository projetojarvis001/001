#!/bin/bash
# JARVIS Backup Diario — roda todo dia as 3h
DATE=$(date +%Y%m%d_%H%M)
BACKUP_DIR="/Users/jarvis001/jarvis/backups"
JARVIS_DIR="/Users/jarvis001/jarvis"
DOCKER="/Users/vision/.orbstack/bin/docker"

echo "[$(date)] Iniciando backup diario..."

# Shadow DB
scp -o StrictHostKeyChecking=no     vision@192.168.8.124:/Users/vision/.hermes/jarvis_memory.db     "$BACKUP_DIR/shadow_${DATE}.db" 2>/dev/null &&     echo "[$(date)] Shadow backup OK"

# pgvector
ssh -o StrictHostKeyChecking=no vision@192.168.8.124     "$DOCKER exec vision-postgres-vision-1 pg_dump -U vision_admin -d vision 2>/dev/null"     > "$BACKUP_DIR/pgvector_${DATE}.sql" 2>/dev/null &&     echo "[$(date)] pgvector backup OK"

# Remove backups com mais de 7 dias
find "$BACKUP_DIR" -name "shadow_*.db" -mtime +7 -delete 2>/dev/null
find "$BACKUP_DIR" -name "pgvector_*.sql" -mtime +7 -delete 2>/dev/null

# Git commit
cd "$JARVIS_DIR"
git add -f backups/shadow_${DATE}.db backups/pgvector_${DATE}.sql 2>/dev/null
git commit -m "backup: auto diario ${DATE}" 2>/dev/null
git push 2>/dev/null

echo "[$(date)] Backup diario concluido"
