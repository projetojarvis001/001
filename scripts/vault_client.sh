#!/bin/bash
# Busca segredo do Vault via tunel SSH :18200
# Uso: bash scripts/vault_client.sh GROQ_API_KEY
# Token lido do .env — nunca hardcoded
VAULT_URL="http://localhost:18200/v1/jarvis/data/api-keys"
VAULT_TOKEN="${VAULT_TOKEN:-$(grep ^VAULT_TOKEN /Users/jarvis001/jarvis/.env 2>/dev/null | cut -d= -f2)}"
KEY="${1:-}"
[ -z "$VAULT_TOKEN" ] && echo "VAULT_TOKEN nao definido" && exit 1
RESULT=$(curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_URL" 2>/dev/null)
[ -z "$RESULT" ] && echo "VAULT_OFFLINE" && exit 1
python3 -c "
import json,sys
data=json.loads(sys.argv[1])['data']['data']
key=sys.argv[2]
if key:
    print(data.get(key,'NOT_FOUND'))
else:
    for k,v in data.items():
        print(f'export {k}=\"{v}\"')
" "$RESULT" "$KEY" 2>/dev/null
