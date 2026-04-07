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


      // Handler de imagem/foto
      const photo = update.message?.photo;
      if (photo && fromChatId === CHAT_ID) {
        try {
          await sendTelegram('🔍 Analisando imagem...');
          const largest = photo[photo.length - 1];
          const fileRes = await axios.get(
            `https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${largest.file_id}`
          );
          const filePath = fileRes.data.result.file_path;
          const imgUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${filePath}`;
          const imgRes = await axios.get(imgUrl, { responseType: 'arraybuffer' });
          const FormData = require('form-data');
          const form = new FormData();
          const caption = update.message?.caption || 'Descreva esta imagem detalhadamente em português.';
          form.append('file', Buffer.from(imgRes.data), { filename: 'image.jpg', contentType: 'image/jpeg' });
          form.append('prompt', caption);
          const visionRes = await axios.post(
            `http://${process.env.VISION_HOST}:5006/analyze-image`,
            form, { headers: form.getHeaders(), timeout: 120000 }
          );
          const description = visionRes.data.description;
          await sendTelegram(`👁️ *Análise VISION:*\n\n${description.slice(0, 1000)}`);
        } catch(e: any) {
          await sendTelegram(`❌ Erro na análise: ${e.message}`);
        }
        continue;
      }

      // Handler de áudio/voz
      const voice = update.message?.voice || update.message?.audio;
      if (voice && fromChatId === CHAT_ID) {
        try {
          await sendTelegram('🎤 Transcrevendo áudio...');
          const fileRes = await axios.get(
            `https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${voice.file_id}`
          );
          const filePath = fileRes.data.result.file_path;
          const audioUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${filePath}`;
          const audioRes = await axios.get(audioUrl, { responseType: 'arraybuffer' });
          const FormData = require('form-data');
          const form = new FormData();
          form.append('file', Buffer.from(audioRes.data), { filename: 'audio.ogg', contentType: 'audio/ogg' });
          const transcribeRes = await axios.post(
            `http://${process.env.VISION_HOST}:5007/transcribe`,
            form, { headers: form.getHeaders(), timeout: 60000 }
          );
          const transcript = transcribeRes.data.text;
          await sendTelegram(`📝 *Transcrição:* ${transcript}`);
          const result: any = await dispatch(transcript, 'chat');
          const reply = result?.response || result?.text || result?.answer || JSON.stringify(result).slice(0, 500);
          await sendTelegram(reply);
        } catch(e: any) {
          await sendTelegram(`❌ Erro na transcrição: ${e.message}`);
        }
        continue;
      }


      if (msg.startsWith('/') && fromChatId === CHAT_ID) {
        const cmd = msg.toLowerCase().trim();
        const visionCmd: Record<string,string> = {
          '/homebridge_start':  'homebridge_start',
          '/homebridge_stop':   'homebridge_stop',
          '/homebridge_status': 'homebridge_status',
          '/purge_mac2':        'memory_purge',
        };
        if (visionCmd[cmd]) {
          await sendTelegram('⏳ Executando ' + cmd + '...');
          try {
            const r = await axios.post(`http://${process.env.VISION_HOST}:5006/cmd`,
              { cmd: visionCmd[cmd] }, { timeout: 35000 });
            await sendTelegram('✅ ' + cmd + ' executado\n' + (r.data.stdout||'').slice(0,200));
          } catch(e:any) { await sendTelegram('❌ Erro: '+e.message); }
          continue;
        }
        if (cmd === '/status') {
          try {
            const h = await axios.get('http://localhost:3000/health');
            const v = await axios.get(`http://${process.env.VISION_HOST}:5006/health`);
            await sendTelegram(`📊 *Status JARVIS*\nCore: ✅ online\nVISION: ✅ online\nTunnel: ${process.env.ZEROCLAW_URL||'ativo'}`);
          } catch(e:any) { await sendTelegram('📊 Sistema operacional'); }
          continue;
        }
        if (cmd === '/ajuda' || cmd === '/help') {
          await sendTelegram('🤖 *Comandos JARVIS*\n\n/status — health do sistema\n/homebridge_start — liga HomeKit\n/homebridge_stop — desliga HomeKit\n/homebridge_status — status HomeKit\n/purge_mac2 — libera RAM Mac2\n\nOu envie texto, voz ou imagem.');
          continue;
        }
      }

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
