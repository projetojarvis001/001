#!/bin/bash
sleep 30
open -a OrbStack
sleep 20
cd /Users/jarvis001/jarvis && docker compose up -d
cd /Users/jarvis001/jarvin-universal && docker compose up -d
