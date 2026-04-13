#!/bin/bash
FRIDAY="wagner@192.168.8.36"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $FRIDAY "mkdir -p ~/jarvis_backup" 2>/dev/null
for f in jarvis_agent.py jarvis_context.py cost_router.py autonomous_agent.py intel_agent.py; do
    scp -o StrictHostKeyChecking=no /Users/jarvis001/jarvis/agents/$f ${FRIDAY}:~/jarvis_backup/ 2>/dev/null && echo "sync: $f" || true
done
scp -o StrictHostKeyChecking=no /Users/jarvis001/jarvis/.env ${FRIDAY}:~/jarvis_backup/ 2>/dev/null || true
echo "[$(date)] Sync RAID concluido"
