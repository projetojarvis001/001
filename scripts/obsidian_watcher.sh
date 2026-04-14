#!/bin/bash
# Monitora pasta Obsidian e ingere novos arquivos no VISION
VAULT_PATH="${1:-$HOME/Documents/JARVIS_KB}"
VISION_URL="http://192.168.8.124:5006"
PROCESSED_LOG="/tmp/obsidian_processed.txt"
mkdir -p "$VAULT_PATH"
touch "$PROCESSED_LOG"

echo "[Obsidian Watcher] Monitorando: $VAULT_PATH"

process_file() {
    local file="$1"
    local filename=$(basename "$file" .md)
    local content=$(cat "$file" 2>/dev/null)
    
    if [ -z "$content" ]; then return; fi
    if grep -qF "$file" "$PROCESSED_LOG" 2>/dev/null; then return; fi
    
    # Ingere no VISION via API
    local id=$(echo "$filename" | md5)
    local payload=$(python3 -c "
import json, sys
title = sys.argv[1]
content = open(sys.argv[2]).read()[:2000]
items = [{'id': title[:12].replace(' ','_'), 'title': title, 'content': content, 'category': 'obsidian'}]
print(json.dumps({'items': items}))
" "$filename" "$file" 2>/dev/null)
    
    if [ -n "$payload" ]; then
        result=$(curl -s -X POST "$VISION_URL/ingest" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 30 2>/dev/null)
        if echo "$result" | grep -q '"ok"'; then
            echo "[$(date)] Ingerido: $filename" >> "$PROCESSED_LOG"
            echo "OK: $filename"
        fi
    fi
}

# Loop de monitoramento
while true; do
    find "$VAULT_PATH" -name "*.md" -newer "$PROCESSED_LOG" 2>/dev/null | while read file; do
        process_file "$file"
    done
    sleep 30
done
