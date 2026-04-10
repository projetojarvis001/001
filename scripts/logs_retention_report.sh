#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== LOGS RETENTION REPORT ====="
date
echo

echo "===== TAMANHO POR DIRETORIO ====="
du -sh logs/* 2>/dev/null || true
echo

echo "===== CONTAGEM DE ARQUIVOS ====="
find logs -type f | sed 's|/[^/]*$||' | sort | uniq -c | sort -nr
echo

echo "===== TOP 20 MAIORES ARQUIVOS ====="
find logs -type f -print0 2>/dev/null | xargs -0 ls -lhS 2>/dev/null | head -n 20 || true
echo

echo "[OK] relatorio concluido"
