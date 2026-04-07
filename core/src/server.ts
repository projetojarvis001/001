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
const VISION_HOST = process.env.VISION_HOST || '192.168.8.124';

async function sendTelegram(text: string) {
  if (!BOT_TOKEN || !CHAT_ID) return;
  try {
    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: CHAT_ID, text, parse_mode: 'HTML'
    });
  } catch(e: any) { console.log('[TG-SEND-ERR]', e.response?.data || e.message); }
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
      const fromChatId = update.message?.chat?.id?.toString();
      const msg = (update.message?.text || '').replace(/@\w+/g, '').trim();

      // ── COMANDOS ──────────────────────────────────────────────────
      if (msg.startsWith('/') && fromChatId === CHAT_ID) {
        const cmd = msg.toLowerCase().trim();

        console.log('[CMD]', cmd, '| ajuda match:', cmd === '/ajuda' || cmd === '/help');

        if (cmd === '/pausar' || cmd === '/pause') {
          const fs = require('fs');
          fs.writeFileSync('/tmp/jarvis_pausado', new Date().toISOString());
          await sendTelegram('Sistema em pausa. Notificacoes desativadas. Use /retomar para reativar.');
          continue;
        }
        if (cmd === '/retomar' || cmd === '/resume') {
          const fs = require('fs');
          try { fs.unlinkSync('/tmp/jarvis_pausado'); } catch(e) {}
          await sendTelegram('Sistema reativado. Notificacoes voltaram ao normal.');
          continue;
        }
        if (cmd === '/silenciar') {
          const fs = require('fs');
          fs.writeFileSync('/tmp/jarvis_pausado', new Date().toISOString());
          setTimeout(() => { try { fs.unlinkSync('/tmp/jarvis_pausado'); } catch(e) {} }, 3600000);
          await sendTelegram('Silenciado por 1 hora. Retoma automaticamente.');
          continue;
        }
        if (cmd === '/ajuda' || cmd === '/help') {
          await sendTelegram('🤖 Comandos JARVIS\n\n/status — health do sistema\n/homebridge\\_start — liga HomeKit\n/homebridge\\_stop — desliga HomeKit\n/homebridge\\_status — status HomeKit\n/purge\\_mac2 — libera RAM Mac2\n\nOu envie texto, voz ou imagem.');
          continue;
        }

        if (cmd === '/status') {
          try {
            const h = await axios.get('http://localhost:3000/health', {timeout:5000});
            const v = await axios.get(`http://${VISION_HOST}:5006/health`, {timeout:5000});
            await sendTelegram(`📊 Status JARVIS\nCore: ✅ online\nVISION: ✅ online`);
          } catch(e:any) {
            await sendTelegram('📊 Sistema operacional');
          }
          continue;
        }

        const visionCmds: Record<string,string> = {
          '/homebridge_start':  'homebridge_start',
          '/homebridge_stop':   'homebridge_stop',
          '/homebridge_status': 'homebridge_status',
          '/purge_mac2':        'memory_purge',
        };
        if (visionCmds[cmd]) {
          await sendTelegram(`⏳ Executando ${cmd}...`);
          try {
            const r = await axios.post(`http://${VISION_HOST}:5006/cmd`,
              { cmd: visionCmds[cmd] }, { timeout: 35000 });
            await sendTelegram(`✅ Concluído\n${(r.data.stdout||'').slice(0,200)}`);
          } catch(e:any) {
            await sendTelegram(`❌ Erro: ${e.message}`);
          }
          continue;
        }
      }

      // ── IMAGEM ────────────────────────────────────────────────────
      const photo = update.message?.photo;
      if (photo && fromChatId === CHAT_ID) {
        try {
          await sendTelegram('🔍 Analisando imagem...');
          const largest = photo[photo.length - 1];
          const fileRes = await axios.get(`https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${largest.file_id}`);
          const imgUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${fileRes.data.result.file_path}`;
          const imgRes = await axios.get(imgUrl, { responseType: 'arraybuffer' });
          const FormData = require('form-data');
          const form = new FormData();
          form.append('file', Buffer.from(imgRes.data), { filename: 'image.jpg', contentType: 'image/jpeg' });
          form.append('prompt', update.message?.caption || 'Descreva esta imagem em português.');
          const vRes = await axios.post(`http://${VISION_HOST}:5006/analyze-image`, form, { headers: form.getHeaders(), timeout: 120000 });
          await sendTelegram(`👁️ Análise VISION:\n\n${vRes.data.description.slice(0, 1000)}`);
        } catch(e:any) {
          await sendTelegram(`❌ Erro na análise: ${e.message}`);
        }
        continue;
      }

      // ── ÁUDIO/VOZ ─────────────────────────────────────────────────
      const voice = update.message?.voice || update.message?.audio;
      if (voice && fromChatId === CHAT_ID) {
        try {
          await sendTelegram('🎤 Transcrevendo áudio...');
          const fileRes = await axios.get(`https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${voice.file_id}`);
          const audioUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${fileRes.data.result.file_path}`;
          const audioRes = await axios.get(audioUrl, { responseType: 'arraybuffer' });
          const FormData = require('form-data');
          const form = new FormData();
          form.append('file', Buffer.from(audioRes.data), { filename: 'audio.ogg', contentType: 'audio/ogg' });
          const tRes = await axios.post(`http://${VISION_HOST}:5007/transcribe`, form, { headers: form.getHeaders(), timeout: 60000 });
          const transcript = tRes.data.text;
          await sendTelegram(`📝 Transcrição: ${transcript}`);
          const result: any = await dispatch(transcript, 'chat');
          const reply = result?.response || result?.text || result?.answer || JSON.stringify(result).slice(0, 500);
          await sendTelegram(reply);
        } catch(e:any) {
          await sendTelegram(`❌ Erro na transcrição: ${e.message}`);
        }
        continue;
      }

      // ── TEXTO ─────────────────────────────────────────────────────
      if (!msg || fromChatId !== CHAT_ID) continue;
      try {
        await sendTelegram('⏳ Processando...');
        const result: any = await dispatch(msg, 'chat');
        const reply = result?.response || result?.text || result?.answer || JSON.stringify(result).slice(0, 500);
        await sendTelegram(reply);
      } catch(e:any) {
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
  try { await pool.query('SELECT NOW()'); console.log('✅ DATABASE: CONECTADO (Postgres)'); }
  catch (err) { console.log('❌ DATABASE: FALHA NA CONEXÃO'); }
  console.log(`📡 VISION HOST: ${VISION_HOST}`);
  console.log(`🚀 CORE OPERACIONAL EM: http://localhost:${PORT}`);
  if (BOT_TOKEN) { telegramPolling(); console.log('✅ TELEGRAM: Polling iniciado'); }
  else { console.log('⚠️ TELEGRAM: BOT_TOKEN ausente'); }
});
