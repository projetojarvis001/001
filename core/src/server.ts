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

app.get('/stack/history', async (_req, res) => {
  try {
    const historyCandidates = [
      '/host_jarvis/logs/history/stack_daily_history.json',
      path.resolve('logs/history/stack_daily_history.json')
    ];

    const historyPath = historyCandidates.find(p => fs.existsSync(p));
    const history = historyPath
      ? JSON.parse(fs.readFileSync(historyPath, 'utf8'))
      : [];

    const last7 = history.slice(-7);
    const last30 = history.slice(-30);

    const avg7 = last7.length
      ? Number((last7.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / last7.length).toFixed(5))
      : null;

    const downtime7 = last7.reduce((a: number, b: any) => a + Number(b.downtime_seconds || 0), 0);
    const incidents7 = last7.reduce((a: number, b: any) => a + Number(b.incident_count || 0), 0);

    let trend = 'STABLE';
    if (last7.length >= 6) {
      const prev3 = last7.slice(-6, -3);
      const curr3 = last7.slice(-3);

      const prevAvg = prev3.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / prev3.length;
      const currAvg = curr3.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / curr3.length;
      const diff = currAvg - prevAvg;

      if (diff > 0.05) trend = 'UP';
      else if (diff < -0.05) trend = 'DOWN';
    }

    return res.json({
      ok: true,
      service: 'jarvis-stack-history',
      timestamp: new Date().toISOString(),
      history,
      summary: {
        days_7: {
          average_availability_percent: avg7,
          total_downtime_seconds: downtime7,
          total_incidents: incidents7,
          trend
        },
        days_30: {
          total_records: last30.length
        }
      }
    });
  } catch (e: any) {
    return res.status(500).json({
      ok: false,
      error: e?.message || 'erro ao ler historico'
    });
  }
});

app.get('/stack/history/compact', async (_req, res) => {
  try {
    const historyCandidates = [
      '/host_jarvis/logs/history/stack_daily_history.json',
      path.resolve('logs/history/stack_daily_history.json')
    ];

    const historyPath = historyCandidates.find(p => fs.existsSync(p));
    const history = historyPath
      ? JSON.parse(fs.readFileSync(historyPath, 'utf8'))
      : [];

    const last7 = history.slice(-7);

    const avg7 = last7.length
      ? Number((last7.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / last7.length).toFixed(5))
      : null;

    const downtime7 = last7.reduce((a: number, b: any) => a + Number(b.downtime_seconds || 0), 0);
    const incidents7 = last7.reduce((a: number, b: any) => a + Number(b.incident_count || 0), 0);

    const worstDay = last7.length
      ? last7.reduce((worst: any, row: any) =>
          Number(row.availability_percent || 0) < Number(worst.availability_percent || 0) ? row : worst
        , last7[0])
      : null;

    const bestDay = last7.length
      ? last7.reduce((best: any, row: any) =>
          Number(row.availability_percent || 0) > Number(best.availability_percent || 0) ? row : best
        , last7[0])
      : null;

    let trend = 'STABLE';
    if (last7.length >= 6) {
      const prev3 = last7.slice(-6, -3);
      const curr3 = last7.slice(-3);

      const prevAvg = prev3.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / prev3.length;
      const currAvg = curr3.reduce((a: number, b: any) => a + Number(b.availability_percent || 0), 0) / curr3.length;
      const diff = currAvg - prevAvg;

      if (diff > 0.05) trend = 'UP';
      else if (diff < -0.05) trend = 'DOWN';
    }

    let executiveStatus = 'ESTAVEL';
    if (avg7 !== null) {
      if (avg7 >= 99.95 && incidents7 === 0) executiveStatus = 'EXCELENTE';
      else if (avg7 >= 99.9) executiveStatus = 'ESTAVEL';
      else if (avg7 >= 99.0) executiveStatus = 'ATENCAO';
      else executiveStatus = 'CRITICO';
    }

    return res.json({
      ok: true,
      service: 'jarvis-stack-history-compact',
      timestamp: new Date().toISOString(),
      summary: {
        average_availability_percent_7d: avg7,
        total_downtime_seconds_7d: downtime7,
        total_incidents_7d: incidents7,
        trend_7d: trend,
        executive_status: executiveStatus,
        best_day: bestDay,
        worst_day: worstDay
      },
      series_7d: last7
    });
  } catch (e: any) {
    return res.status(500).json({
      ok: false,
      error: e?.message || 'erro ao ler history compact'
    });
  }
});

app.get('/stack/history/export', async (_req, res) => {
  try {
    const jsonCandidates = [
      '/host_jarvis/logs/history/stack_daily_history.json',
      path.resolve('logs/history/stack_daily_history.json')
    ];

    const csvCandidates = [
      '/host_jarvis/logs/history/stack_daily_history.csv',
      path.resolve('logs/history/stack_daily_history.csv')
    ];

    const jsonPath = jsonCandidates.find(p => fs.existsSync(p)) || jsonCandidates[0];
    const csvPath = csvCandidates.find(p => fs.existsSync(p)) || csvCandidates[0];

    const history = fs.existsSync(jsonPath)
      ? JSON.parse(fs.readFileSync(jsonPath, 'utf8'))
      : [];

    return res.json({
      ok: true,
      service: 'jarvis-stack-history-export',
      timestamp: new Date().toISOString(),
      json_path: jsonPath,
      csv_path: csvPath,
      records: history.length
    });
  } catch (e: any) {
    return res.status(500).json({
      ok: false,
      error: e?.message || 'erro ao ler export history'
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
          await sendTelegram(
            '🤖 *J.A.R.V.I.S. — Comandos*\n\n' +
            '*Sistema*\n' +
            '/status — saúde completa do sistema\n' +
            '/prometheus — métricas dos 4 nós\n' +
            '/logs — últimos logs do core\n\n' +
            '*Controle*\n' +
            '/pausar — para notificações automáticas\n' +
            '/retomar — retoma notificações\n' +
            '/silenciar — silencia por 1 hora\n\n' +
            '*Ações*\n' +
            '/purge\\_mac2 — libera RAM do VISION\n' +
            '/guardian — força verificação agora\n' +
            '/watcher — força watcher preditivo\n' +
            '/relatorio — relatório executivo diário\n\n' +
            '*IA*\n' +
            'Texto livre → JARVIS responde via Groq\n' +
            'Voz → transcreve + responde\n' +
            'Imagem → analisa via VISION (llava)\n\n' +
            'Ex: "qual o status do Odoo?" ou "analise vendas desta semana"'
          );
          continue;
        }

        if (cmd === '/status') {
          try {
            const os = require('os');
            const { execSync } = require('child_process');
            // Core
            let coreStatus = '❌';
            try { await axios.get('http://localhost:3000/health', {timeout:3000}); coreStatus = '✅'; } catch(e) {}
            // VISION
            const semanticBaseUrl = process.env.VISION_SEMANTIC_URL || `http://${VISION_HOST}:5006`;
            let visionStatus = '❌';
            try { await axios.get(`${semanticBaseUrl}/health`, {timeout:3000}); visionStatus = '✅'; } catch(e) {}
            // Whisper
            const whisperUrl = process.env.VISION_WHISPER_URL || `http://${VISION_HOST}:5007`;
            let whisperStatus = '❌';
            try { await axios.get(`${whisperUrl}/health`, {timeout:3000}); whisperStatus = '✅'; } catch(e) {}
            // Odoo
            let odooStatus = '❌';
            try { await axios.get('http://177.104.176.69:58069/web/health', {timeout:4000}); odooStatus = '✅'; } catch(e) {}
            // Prometheus
            let promStatus = '❌';
            try { await axios.get('http://localhost:9090/-/healthy', {timeout:3000}); promStatus = '✅'; } catch(e) {}
            // RAM
            const ramPct = (1 - os.freemem()/os.totalmem()) * 100;
            // Disk
            let diskUsage = '?';
            try { diskUsage = execSync("df -h / | tail -1 | awk '{print $5}'").toString().trim(); } catch(e) {}
            // Tunnel
            let tunnelUrl = '❌';
            try { const fs = require('fs'); tunnelUrl = fs.readFileSync('/tmp/current_tunnel_mac1.txt','utf8').trim().replace('https://','').slice(0,35); } catch(e) {}
            // DB
            let dbStatus = '❌';
            try { await pool.query('SELECT 1'); dbStatus = '✅'; } catch(e) {}
            // Containers
            let containers = '?';
            try { containers = execSync("docker ps --format '{{.Names}}' | wc -l | tr -d ' '").toString().trim(); } catch(e) {}

            const msg = [
              '📊 *J.A.R.V.I.S. Status* — ' + new Date().toLocaleTimeString('pt-BR'),
              '',
              '*Serviços*',
              `Core: ${coreStatus}  VISION: ${visionStatus}  Whisper: ${whisperStatus}`,
              `Odoo: ${odooStatus}  Prometheus: ${promStatus}  DB: ${dbStatus}`,
              `Containers: ${containers} ativos`,
              '',
              '*Recursos JARVIS*',
              `RAM: ${ramPct.toFixed(0)}% usada  |  Disco: ${diskUsage}`,
              '',
              '*Rede*',
              `Tunnel: ${tunnelUrl}`,
            ].join('\n');
            await sendTelegram(msg);
          } catch(e:any) {
            await sendTelegram('📊 JARVIS operacional');
          }
          continue;
        }

        if (cmd === '/prometheus') {
          try {
            const r = await axios.get('http://localhost:9090/api/v1/targets', {timeout:5000});
            const targets = r.data?.data?.activeTargets || [];
            const ok = targets.filter((t:any) => t.health === 'up');
            const fail = targets.filter((t:any) => t.health !== 'up');
            let msg = `📡 *Prometheus — ${ok.length}/${targets.length} targets up*\n\n`;
            ok.forEach((t:any) => { msg += `✅ ${t.labels?.job} — ${t.labels?.instance}\n`; });
            if (fail.length > 0) {
              msg += '\n';
              fail.forEach((t:any) => { msg += `❌ ${t.labels?.job} — ${t.labels?.instance}\n`; });
            }
            await sendTelegram(msg);
          } catch(e:any) {
            await sendTelegram('❌ Prometheus indisponível: ' + e.message);
          }
          continue;
        }

        if (cmd === '/logs') {
          try {
            const { execSync } = require('child_process');
            const logs = execSync('docker logs jarvis-jarvis-core-1 --tail 15 2>&1').toString();
            const clean = logs.replace(/[\x00-\x1F\x7F]/g, '').slice(0, 3000);
            await sendTelegram('📋 *Logs recentes*\n\`\`\`\n' + clean + '\n\`\`\`');
          } catch(e:any) {
            await sendTelegram('❌ Erro ao buscar logs: ' + e.message);
          }
          continue;
        }

        if (cmd === '/guardian') {
          await sendTelegram('🛡️ Executando Guardian...');
          try {
            const { execSync } = require('child_process');
            execSync('cd /Users/jarvis001/jarvis && bash scripts/guardian.sh >> /tmp/guardian.log 2>&1 &');
            await sendTelegram('✅ Guardian executado — verifique /logs para resultado');
          } catch(e:any) {
            await sendTelegram('❌ Erro: ' + e.message);
          }
          continue;
        }

        if (cmd === '/watcher') {
          await sendTelegram('🔍 Executando Watcher Preditivo...');
          try {
            const { execSync } = require('child_process');
            const result = execSync('cd /Users/jarvis001/jarvis && bash scripts/watcher_preditivo.sh 2>&1').toString();
            await sendTelegram('✅ Watcher executado:\n' + result.slice(0, 300));
          } catch(e:any) {
            await sendTelegram('❌ Erro: ' + e.message);
          }
          continue;
        }

        if (cmd === '/relatorio') {
          await sendTelegram('📊 Gerando relatório...');
          try {
            const { execSync } = require('child_process');
            execSync('cd /Users/jarvis001/jarvis && bash scripts/relatorio_diario.sh 2>&1 &');
            await sendTelegram('✅ Relatório enviado');
          } catch(e:any) {
            await sendTelegram('❌ Erro: ' + e.message);
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

      // ── LANGGRAPH !jarvis ─────────────────────────────────────────
      if (msg && msg.toLowerCase().startsWith('!jarvis') && fromChatId === CHAT_ID) {
        const task = msg.slice(7).trim() || 'qual o status do sistema?';
        await sendTelegram('🧠 Agente LangGraph processando...');
        try {
          const r = await axios.post('http://localhost:3000/agent', { task }, { timeout: 65000 });
          await sendTelegram(r.data.response?.slice(0, 3000) || 'sem resposta');
        } catch(e: any) {
          await sendTelegram('❌ Erro no agente: ' + e.message);
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
  const { prompt, message, category } = req.body; const finalPrompt = prompt || message;
  try {
    const result = await dispatch(finalPrompt, category);
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

// ── ALERTMANAGER WEBHOOK ──────────────────────────────────────────
app.post('/alerts/webhook', async (req, res) => {
  try {
    const alerts = req.body?.alerts || [];
    for (const alert of alerts) {
      const status = alert.status === 'firing' ? '🔴' : '✅';
      const name = alert.labels?.alertname || 'Alerta';
      const node = alert.labels?.node || alert.labels?.instance || '';
      const summary = alert.annotations?.summary || '';
      const desc = alert.annotations?.description || '';
      const msg = `${status} *${name}*${node ? ` — ${node}` : ''}\n${summary}${desc ? '\n' + desc : ''}`;
      await sendTelegram(msg);
    }
    res.json({ ok: true, processed: alerts.length });
  } catch(e: any) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── LANGGRAPH AGENT — comando !jarvis ────────────────────────
app.post('/agent', async (req, res) => {
  const { task } = req.body;
  if (!task) return res.status(400).json({ ok: false, error: 'task required' });
  try {
    const r = await axios.post('http://host.docker.internal:7777', { task }, { timeout: 65000 });
    res.json({ ok: true, response: r.data.response });
  } catch(e: any) {
    // fallback: tenta localhost
    try {
      const r2 = await axios.post('http://localhost:7777', { task }, { timeout: 65000 });
      res.json({ ok: true, response: r2.data.response });
    } catch(e2: any) {
      res.status(500).json({ ok: false, error: 'Agent server offline — inicie com: nohup python3 agents/agent_server.py &' });
    }
  }
});
