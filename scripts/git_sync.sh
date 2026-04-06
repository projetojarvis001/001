#!/bin/bash
cd /Users/jarvis001/jarvis
git add .
git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null
git push origin main 2>/dev/null || git push origin master 2>/dev/null
