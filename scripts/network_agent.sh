#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
LOG="/tmp/network_agent.log"
REPORT="/tmp/network_report.json"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "indisponível")
IP_INFO=$(curl -s --max-time 5 "https://ipinfo.io/$PUBLIC_IP/json" 2>/dev/null)
ISP=$(echo $IP_INFO | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org','?'))" 2>/dev/null)
CITY=$(echo $IP_INFO | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('city','?'))" 2>/dev/null)

LATENCY_CF=$(ping -c 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1)
LATENCY_TELEGRAM=$(ping -c 3 api.telegram.org 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1)
INTERNET=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://google.com 2>/dev/null)

BYTES_IN_BEFORE=$(netstat -ib 2>/dev/null | grep -E "^en0" | head -1 | awk '{print $7}')
sleep 5
BYTES_IN_AFTER=$(netstat -ib 2>/dev/null | grep -E "^en0" | head -1 | awk '{print $7}')
BANDWIDTH_KB=$(( (BYTES_IN_AFTER - BYTES_IN_BEFORE) / 5 / 1024 ))

CONN_COUNT=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l | tr -d ' ')
CONN_EXTERNAL=$(netstat -an 2>/dev/null | grep ESTABLISHED | grep -v "127.0.0.1\|::1\|192.168" | wc -l | tr -d ' ')

UNUSUAL=""
[ "$CONN_EXTERNAL" -gt 50 ] && UNUSUAL="⚠️ Conexões externas anômalas: $CONN_EXTERNAL"
[ -z "$LATENCY_CF" ] && UNUSUAL="$UNUSUAL\n❌ Cloudflare inacessível"
[ "$INTERNET" != "200" ] && [ "$INTERNET" != "301" ] && [ "$INTERNET" != "302" ] && UNUSUAL="$UNUSUAL\n❌ Internet offline"

cat > $REPORT << JSONEOF
{
  "ts": "$(date '+%Y-%m-%d %H:%M:%S')",
  "public_ip": "$PUBLIC_IP",
  "isp": "$ISP",
  "city": "$CITY",
  "latency_cf_ms": "${LATENCY_CF:-999}",
  "latency_telegram_ms": "${LATENCY_TELEGRAM:-999}",
  "internet": "$INTERNET",
  "bandwidth_kb": $BANDWIDTH_KB,
  "conn_total": $CONN_COUNT,
  "conn_external": $CONN_EXTERNAL,
  "unusual": "$(echo -e "$UNUSUAL" | tr '\n' '|')"
}
JSONEOF

[ -n "$UNUSUAL" ] && notify "🌐 *Network Agent Mac1*\n$(echo -e "$UNUSUAL")\nIP: $PUBLIC_IP | ISP: $ISP"

echo "[$(date)] IP: $PUBLIC_IP | Latência: ${LATENCY_CF}ms | Banda: ${BANDWIDTH_KB}KB/s | Conn: $CONN_COUNT" >> $LOG
cp /tmp/network_report.json /Users/jarvis001/jarvis/dashboard/network_report.json 2>/dev/null
