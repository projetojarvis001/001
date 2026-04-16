#!/bin/bash
# Fine-tuning JARVIS-WPS no Friday (64GB RAM)
cd /tmp

echo "Copiando dataset..."
# Dataset sera copiado do JARVIS para o Friday

echo "Criando modelo JARVIS-WPS baseado no Gemma4..."
ollama create jarvis-wps -f /tmp/Modelfile

echo "Testando modelo..."
echo "qual o ROI da portaria virtual WPS para 100 apartamentos" | ollama run jarvis-wps

echo "Fine-tuning concluido"
