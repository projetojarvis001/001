'use strict';
const express = require('express');
const axios = require('axios');
const app = express();
app.use(express.json());

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const CHAT_ID = process.env.TELEGRAM_CHAT_ID || '170323936';
const VISION_HOST = process.env.VISION_HOST || '192.168.8.124';

async function sendTelegram(msg) {
  if (!BOT_TOKEN) return;
  try {
    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: CHAT_ID, text: msg
    });
  } catch(e) {}
}

let lastUpdateId = 0;
async function telegramPolling() {
  try {
    const r = await axios.get(`https://api.telegram.org/bot${BOT_TOKEN}/getUpdates`, {
      params: { offset: lastUpdateId + 1, timeout: 30 }, timeout: 35000
    });
    for (const update of r.data.result || []) {
      lastUpdateId = update.update_id;
      const fromChatId = update.message?.chat?.id?.toString();
      const msg = (update.message?.text || '').replace(/@\w+/g, '').trim();
      if (!msg || fromChatId !== CHAT_ID) continue;
      if (!msg.startsWith('/')) {
        // texto livre — dispatcher
        try {
          await sendTelegram('⏳ Processando...');
          const { dispatch } = require('./dispatcher');
          const result = await dispatch(msg, 'chat');
          const reply = result?.response || result?.text || result?.answer || JSON.stringify(result);
          await sendTelegram(reply);
        } catch(e) { await sendTelegram('Erro: ' + e.message); }
        continue;
      }
      const cmd = msg.toLowerCase().trim();
      console.log('[CMD]', cmd);

      if (cmd === '/cripto') {
        try {
          const h  = await axios.get('http://192.168.8.121:7799/').then(r=>r.data).catch(()=>({}));
          const ex = await axios.get('http://192.168.8.121:7810/').then(r=>r.data).catch(()=>({}));
          const po = await axios.get('http://192.168.8.121:7812/').then(r=>r.data).catch(()=>({}));
          await sendTelegram(
            'JARVIS CRIPTO\n\n' +
            'Hunter: ' + (h.ciclos||0) + ' ciclos\n' +
            'Airdrops: ' + (ex.sucessos||0) + ' ativos\n' +
            'Capital: $' + (po.capital_usd||'20.00') + '\n' +
            'Win rate: ' + (po.win_rate||'0%') + '\n\n' +
            'Meta: 1 BTC'
          );
        } catch(e) { await sendTelegram('Erro cripto: ' + e.message); }
        continue;
      }
      if (cmd === '/kill' || cmd === '/emergencia') {
        try { await axios.post('http://192.168.8.121:7813/pausar'); } catch(e) {}
        await sendTelegram('EMERGENCIA — AGENTES PAUSADOS\nUse /retomar');
        continue;
      }
      if (cmd === '/sim') { await sendTelegram('Aprovado'); continue; }
      if (cmd === '/nao') { await sendTelegram('Rejeitado'); continue; }
      if (cmd === '/pausar' || cmd === '/pause') {
        require('fs').writeFileSync('/tmp/jarvis_pausado', new Date().toISOString());
        await sendTelegram('Pausado. Use /retomar.');
        continue;
      }
      if (cmd === '/retomar' || cmd === '/resume') {
        try { require('fs').unlinkSync('/tmp/jarvis_pausado'); } catch(e) {}
        await sendTelegram('Reativado.');
        continue;
      }
      if (cmd === '/status') {
        try {
          const { execSync } = require('child_process');
          const mem = execSync('vm_stat 2>/dev/null | head -3 || free -h 2>/dev/null | head -2').toString().slice(0,200);
          await sendTelegram('JARVIS STATUS\nSistemas operando.\n' + mem.slice(0,200));
        } catch(e) { await sendTelegram('JARVIS STATUS\nSistemas operando.'); }
        continue;
      }
      if (cmd === '/ajuda' || cmd === '/help') {
        await sendTelegram(
          'JARVIS COMANDOS\n\n' +
          '/cripto — portfolio e meta BTC\n' +
          '/status — estado do sistema\n' +
          '/kill — emergencia para tudo\n' +
          '/sim — aprova operacao\n' +
          '/nao — rejeita operacao\n' +
          '/pausar — pausa notificacoes\n' +
          '/retomar — retoma notificacoes\n' +
          '/ajuda — esta mensagem'
        );
        continue;
      }
      // comando nao reconhecido — ignora
    }
  } catch(e) {}
  setTimeout(telegramPolling, 1000);
}

app.get('/health', (_req, res) => res.json({ ok: true, service: 'jarvis-core' }));
app.post('/ask', async (req, res) => {
  try {
    const { dispatch } = require('./dispatcher');
    const result = await dispatch(req.body.prompt || req.body.message, req.body.category);
    res.json(result);
  } catch(e) { res.status(500).json({ error: e.message }); }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log('🚀 CORE OPERACIONAL EM: http://localhost:' + PORT);
  if (BOT_TOKEN) { telegramPolling(); console.log('✅ TELEGRAM: Polling iniciado'); }
});
