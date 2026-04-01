import { Client } from 'pg';
import Redis from 'ioredis';
import axios from 'axios';
import os from 'os';

// Configuração de ambiente
require('dotenv').config({ path: '/Users/jarvis001/jarvis/.env' });

const pgClient = new Client({
  host: 'localhost', port: 5432, user: 'jarvis_admin',
  password: process.env.PG_PASSWORD, database: 'jarvis'
});

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const chatId = process.env.TELEGRAM_CHAT_ID;

async function sendTelegram(msg: string) {
  try {
    await axios.post(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      chat_id: chatId, text: msg, parse_mode: 'Markdown'
    });
  } catch (e) { console.error('[Sentinel] Erro Telegram'); }
}

async function getIAAnalysis(report: string) {
  try {
    // Roteamento inteligente: Baixa complexidade usa Mac 2 (Ollama)
    const res = await axios.post(`http://${process.env.VISION_HOST}:11434/api/generate`, {
      model: 'qwen2.5:7b',
      prompt: `Resuma em uma frase executiva para o gestor: ${report}`,
      stream: false
    });
    return res.data.response;
  } catch (e) {
    return "Sistemas operando dentro da normalidade.";
  }
}

async function checkHealth() {
  const ramUsage = ((1 - os.freemem() / os.totalmem()) * 100).toFixed(1);
  const cpuLoad = os.loadavg()[0].toFixed(2);
  
  try {
    const start = Date.now();
    await axios.get(`http://${process.env.VISION_HOST}:11434/api/tags`, { timeout: 5000 });
    const duration = Date.now() - start;

    const report = `RAM: ${ramUsage}% | CPU: ${cpuLoad} | VISION: ONLINE (${duration}ms)`;
    console.log(`[Sentinel] ${report}`);

    // Log no Banco
    await pgClient.query(
      'INSERT INTO jarvis_logs (source_brain, agent_id, agent_role, action_type, status, duration_ms) VALUES ($1, $2, $3, $4, $5, $6)',
      ['JARVIS', 'sentinel', 'GUARDIAN', 'HEALTH_CHECK', 'SUCCESS', duration]
    );

  } catch (error) {
    await sendTelegram(`🚨 *ALERTA:* V.I.S.I.O.N. Offline ou instável!`);
  }
}

async function init() {
  await pgClient.connect();
  console.log('🛡️ Sentinel Ativo com Camada de Inteligência.');
  
  const welcome = await getIAAnalysis("Sistema J.A.R.V.I.S. iniciado com sucesso no Mac Mini 1.");
  await sendTelegram(`🤖 *J.A.R.V.I.S. Boot:* ${welcome}`);

  checkHealth();
  setInterval(checkHealth, 60000);
}

init();
