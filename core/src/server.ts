import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import axios from 'axios';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { dispatch } from './dispatcher';
import { pool } from './logger';
import './agents/sentinel';

const app = express();
const upload = multer({ storage: multer.memoryStorage() });
app.use(express.json());

app.use('/dashboard', express.static('/app/dashboard'));

function requireInternalKey(req: any, res: any, next: any) {
  const expected = process.env.INTERNAL_API_KEY;
  if (!expected) {
    return res.status(500).json({ ok: false, error: 'INTERNAL_API_KEY nao configurada' });
  }

  const received = req.headers['x-internal-key'];
  if (received !== expected) {
    return res.status(401).json({ ok: false, error: 'unauthorized' });
  }

  next();
}

app.get('/stack/metrics', async (_req, res) => {
  try {
    const metricsCandidates = [
      '/host_jarvis/logs/state/stack_metrics.json',
      path.resolve('logs/state/stack_metrics.json')
    ];

    const autoHealCandidates = [
      '/host_jarvis/logs/state/auto_heal_state.json',
      path.resolve('logs/state/auto_heal_state.json')
    ];

    const metricsPath = metricsCandidates.find(p => fs.existsSync(p));
    const autoHealPath = autoHealCandidates.find(p => fs.existsSync(p));

    const metrics = metricsPath
      ? JSON.parse(fs.readFileSync(metricsPath, 'utf8'))
      : null;

    const autoHeal = autoHealPath
      ? JSON.parse(fs.readFileSync(autoHealPath, 'utf8'))
      : null;

    return res.json({
      ok: true,
      service: 'jarvis-stack-metrics',
      timestamp: new Date().toISOString(),
      metrics,
      autoHeal
    });
  } catch (e: any) {
    return res.status(500).json({
      ok: false,
      error: e?.message || 'erro ao ler stack metrics'
    });
  }
});

app.get('/stack/slo', async (_req, res) => {
  try {
    const metricsCandidates = [
      '/host_jarvis/logs/state/stack_metrics.json',
      path.resolve('logs/state/stack_metrics.json')
    ];

    const metricsPath = metricsCandidates.find(p => fs.existsSync(p));
    const metrics = metricsPath
      ? JSON.parse(fs.readFileSync(metricsPath, 'utf8'))
      : null;

    const totalWindowSeconds = 86400;
    const downtimeSeconds = Number(metrics?.total_downtime_seconds || 0);
    const uptimeSeconds = Math.max(totalWindowSeconds - downtimeSeconds, 0);
    const availability = Number(((uptimeSeconds / totalWindowSeconds) * 100).toFixed(5));

    let status = 'green';
    if (availability < 99.0) status = 'red';
    else if (availability < 99.9) status = 'yellow';

    return res.json({
      ok: true,
      service: 'jarvis-stack-slo',
      timestamp: new Date().toISOString(),
      date: metrics?.date || null,
      total_window_seconds: totalWindowSeconds,
      downtime_seconds: downtimeSeconds,
      uptime_seconds: uptimeSeconds,
      availability_percent: availability,
      target_percent: 99.9,
      status
    });
  } catch (e: any) {
    return res.status(500).json({
      ok: false,
      error: e?.message || 'erro ao calcular stack slo'
    });
  }
});

app.get('/stack/health', async (_req, res) => {
  const visionHost = process.env.VISION_HOST;
  const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (visionHost ? `http://${visionHost}:5006` : undefined);
  const whisperBaseUrl = process.env.VISION_WHISPER_URL || (visionHost ? `http://${visionHost}:5007` : undefined);
  const bridgeUrl = process.env.VISION_BRIDGE_URL || (visionHost ? `http://${visionHost}:5005/process` : undefined);

  const result: any = {
    ok: true,
    service: 'jarvis-stack',
    timestamp: new Date().toISOString(),
    checks: {
      core: { ok: true }
    }
  };

  try {
    if (!semanticBaseUrl) throw new Error('semantic nao configurado');
    const r = await axios.get(`${semanticBaseUrl}/health`, { timeout: 5000 });
    result.checks.semantic = { ok: true, data: r.data };
  } catch (e: any) {
    result.ok = false;
    result.checks.semantic = { ok: false, error: e?.message || 'erro semantic' };
  }

  try {
    if (!whisperBaseUrl) throw new Error('whisper nao configurado');
    const r = await axios.get(`${whisperBaseUrl}/health`, { timeout: 5000 });
    result.checks.whisper = { ok: true, data: r.data };
  } catch (e: any) {
    result.ok = false;
    result.checks.whisper = { ok: false, error: e?.message || 'erro whisper' };
  }

  try {
    if (!bridgeUrl) throw new Error('bridge nao configurado');
    const r = await axios.post(
      bridgeUrl,
      { prompt: 'Responda apenas OK_STACK_HEALTH', model: 'qwen2.5:7b' },
      { timeout: 15000 }
    );
    result.checks.bridge = { ok: true, data: r.data };
  } catch (e: any) {
    result.ok = false;
    result.checks.bridge = { ok: false, error: e?.message || 'erro bridge' };
  }

  return res.status(result.ok ? 200 : 503).json(result);
});

app.get('/semantic-proxy/health', async (_req, res) => {
  try {
    const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
    if (!semanticBaseUrl) {
      return res.status(500).json({ ok: false, error: 'VISION_SEMANTIC_URL/VISION_HOST nao configurado' });
    }

    const r = await axios.get(`${semanticBaseUrl}/health`, { timeout: 5000 });
    return res.status(r.status).json(r.data);
  } catch (e: any) {
    return res.status(502).json({ ok: false, error: e?.message || 'semantic proxy failed' });
  }
});

app.post('/semantic-proxy/cmd', requireInternalKey, async (req, res) => {
  try {
    const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
    if (!semanticBaseUrl) {
      return res.status(500).json({ ok: false, error: 'VISION_SEMANTIC_URL/VISION_HOST nao configurado' });
    }

    const r = await axios.post(`${semanticBaseUrl}/cmd`, req.body, { timeout: 120000 });
    return res.status(r.status).json(r.data);
  } catch (e: any) {
    return res.status(502).json({ ok: false, error: e?.message || 'semantic cmd proxy failed' });
  }
});

app.post('/semantic-proxy/analyze-image', requireInternalKey, upload.single('image'), async (req, res) => {
  try {
    const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
    if (!semanticBaseUrl) {
      return res.status(500).json({ ok: false, error: 'VISION_SEMANTIC_URL/VISION_HOST nao configurado' });
    }
    const file = (req as any).file;
    if (!file) {
      return res.status(400).json({ ok: false, error: 'arquivo image ausente' });
    }

    const FormData = require('form-data');
    const form = new FormData();
    form.append('image', file.buffer, {
      filename: file.originalname || 'image.jpg',
      contentType: file.mimetype || 'application/octet-stream'
    });

    if (req.body?.prompt) form.append('prompt', req.body.prompt);
    if (req.body?.model) form.append('model', req.body.model);

    const r = await axios.post(`${semanticBaseUrl}/analyze-image`, form, {
      headers: form.getHeaders(),
      timeout: 120000
    });

    return res.status(r.status).json(r.data);
  } catch (e: any) {
    return res.status(502).json({ ok: false, error: e?.message || 'semantic analyze-image proxy failed' });
  }
});

app.post('/whisper-proxy/transcribe', requireInternalKey, upload.single('audio'), async (req, res) => {
  try {
    const whisperBaseUrl = process.env.VISION_WHISPER_URL || (VISION_HOST ? `http://${VISION_HOST}:5007` : undefined);
    if (!whisperBaseUrl) {
      return res.status(500).json({ ok: false, error: 'VISION_WHISPER_URL/VISION_HOST nao configurado' });
    }
    const file = (req as any).file;
    if (!file) {
      return res.status(400).json({ ok: false, error: 'arquivo audio ausente' });
    }

    const FormData = require('form-data');
    const form = new FormData();
    form.append('audio', file.buffer, {
      filename: file.originalname || 'audio.wav',
      contentType: file.mimetype || 'application/octet-stream'
    });

    const r = await axios.post(`${whisperBaseUrl}/transcribe`, form, {
      headers: form.getHeaders(),
      timeout: 120000
    });

    return res.status(r.status).json(r.data);
  } catch (e: any) {
    return res.status(502).json({ ok: false, error: e?.message || 'whisper proxy failed' });
  }
});


const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const CHAT_ID = process.env.TELEGRAM_CHAT_ID || '';
const VISION_HOST = process.env.VISION_HOST;

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
            const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
            const v = await axios.get(`${semanticBaseUrl}/health`, {timeout:5000});
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
            const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
            if (!semanticBaseUrl) throw new Error('VISION_SEMANTIC_URL/VISION_HOST nao configurado');
            const r = await axios.post(`${semanticBaseUrl}/cmd`,
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
          const visionAnalyzeBaseUrl = process.env.VISION_SEMANTIC_URL || (VISION_HOST ? `http://${VISION_HOST}:5006` : undefined);
          if (!visionAnalyzeBaseUrl) throw new Error('VISION_SEMANTIC_URL/VISION_HOST nao configurado');
          const vRes = await axios.post(`${visionAnalyzeBaseUrl}/analyze-image`, form, { headers: form.getHeaders(), timeout: 120000 });
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
          const whisperBaseUrl = process.env.VISION_WHISPER_URL || (VISION_HOST ? `http://${VISION_HOST}:5007` : undefined);
          if (!whisperBaseUrl) throw new Error('VISION_WHISPER_URL/VISION_HOST nao configurado');
          const tRes = await axios.post(`${whisperBaseUrl}/transcribe`, form, { headers: form.getHeaders(), timeout: 60000 });
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
