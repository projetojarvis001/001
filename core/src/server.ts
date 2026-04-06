import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import axios from 'axios';
import { dispatch } from './dispatcher';
import { pool } from './logger';
import './agents/sentinel';

const app = express();
app.use(express.json());
app.use('/dashboard', express.static('/app/dashboard'));

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const CHAT_ID = process.env.TELEGRAM_CHAT_ID || '';

async function sendTelegram(text: string) {
  if (!BOT_TOKEN || !CHAT_ID) return;
  try {
    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: CHAT_ID, text, parse_mode: 'Markdown'
    });
  } catch(e) {}
}

let lastUpdateId = 0;

async function telegramPolling(): Promise<void> {
  if (!BOT_TOKEN) return;
  try {
    const res = await axios.get(
      `https://api.telegram.org/bot${BOT_TOKEN}/getUpdates`,
      { params: { offset: lastUpdateId + 1, timeout: 30 }, timeout: 35000 }
    );
    const updates = res.data.result || [];
    for (const update of updates) {
      lastUpdateId = update.update_id;
      const msg = update.message?.text || '';
      const fromChatId = update.message?.chat?.id?.toString();
      if (!msg || fromChatId !== CHAT_ID) continue;
      try {
        await sendTelegram('⏳ Processando...');
        const result: any = await dispatch(msg, 'chat');
        const reply = result?.response || result?.text || result?.answer || JSON.stringify(result).slice(0, 500);
        await sendTelegram(reply);
      } catch(e: any) {
        await sendTelegram(`❌ Erro: ${e.message}`);
      }
    }
  } catch(e) {}
  setTimeout(telegramPolling, 1000);
}

app.get('/health', async (_req, res) => {
  res.json({ ok: true, service: 'jarvis-core', timestamp: new Date().toISOString() });
});

app.post('/ask', async (req, res) => {
  const { prompt, category } = req.body;
  try {
    const result = await dispatch(prompt, category);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  console.log('--- J.A.R.V.I.S. RELATÓRIO DE BOOT ---');
  try {
    await pool.query('SELECT NOW()');
    console.log('✅ DATABASE: CONECTADO (Postgres)');
  } catch (err) {
    console.log('❌ DATABASE: FALHA NA CONEXÃO');
  }
  console.log(`📡 VISION HOST: ${process.env.VISION_HOST}`);
  console.log(`🚀 CORE OPERACIONAL EM: http://localhost:${PORT}`);
  if (BOT_TOKEN) {
    telegramPolling();
    console.log('✅ TELEGRAM: Polling iniciado');
  } else {
    console.log('⚠️ TELEGRAM: BOT_TOKEN ausente');
  }
});
