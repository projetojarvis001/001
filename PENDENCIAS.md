
## SerpAPI
1. Cadastre em https://serpapi.com/users/sign_up
2. echo 'SERPAPI_KEY=SUA_CHAVE' >> /Users/jarvis001/jarvis/.env
3. Execute: curl -X POST http://localhost:7795/buscar?query=portaria+virtual

## Google Calendar OAuth
1. console.cloud.google.com
2. APIs > Google Calendar API > Ativar
3. Credenciais > OAuth 2.0 > Desktop App
4. echo 'GOOGLE_CLIENT_ID=xxx' >> .env
5. echo 'GOOGLE_CLIENT_SECRET=xxx' >> .env
6. curl http://localhost:7788/oauth/url
7. Autorize e cole: curl -X POST 'http://localhost:7788/oauth/token?code=CODIGO'
