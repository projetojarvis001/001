#!/bin/bash
cd /Users/jarvis001/jarvis
export PYTHONPATH=/Users/jarvis001/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH
python3 agents/hunter_agent.py report >> /tmp/hunter_agent.log 2>&1
echo "[$(date)] Hunter report enviado"
