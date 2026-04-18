#!/bin/bash
echo "=== JARVIS LoRA Monitor ==="
while true; do
    clear
    echo "=== LORA — $(date '+%H:%M:%S') ==="
    sshpass -p "04475475" ssh -o StrictHostKeyChecking=no wagner@192.168.8.36 \
        'export PATH=/home/wagner/.local/bin:$PATH
         pid=$(cat /tmp/finetune_pid.txt 2>/dev/null)
         if ps -p $pid > /dev/null 2>&1; then
             echo "STATUS: RODANDO (PID $pid)"
             cpu=$(ps -p $pid -o %cpu= 2>/dev/null)
             echo "CPU: $cpu%"
         else
             echo "STATUS: CONCLUIDO ou PARADO"
         fi
         echo ""
         tail -20 /home/wagner/jarvis/logs/finetune_lora.log 2>/dev/null
         echo ""
         echo "--- Modelos ---"
         ollama list | grep jarvis' 2>/dev/null
    echo ""
    echo "Ctrl+C para sair | atualiza em 30s"
    sleep 30
done
