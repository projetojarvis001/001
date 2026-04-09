import axios from 'axios';
import os from 'os';
import { pool, updateAgentStats, log } from '../logger';

const botToken = process.env.TELEGRAM_BOT_TOKEN;
const chatId = process.env.TELEGRAM_CHAT_ID;

async function sendTelegram(msg: string) {
  try {
    if (!botToken || !chatId) return;
    await axios.post(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      chat_id: chatId,
      text: msg,
      parse_mode: 'Markdown'
    });
  } catch (e) {
    console.error('[Sentinel] Erro Telegram');
  }
}

async function getIAAnalysis(report: string) {
  try {
    const res = await axios.post(
      `http://${process.env.VISION_HOST}:5005/process`,
      {
        model: 'qwen2.5:7b',
        prompt: `Resuma em uma frase executiva para o gestor: ${report}`,
        stream: false
      },
      { timeout: 15000 }
    );
    return res.data.response;
  } catch (e) {
    return 'Sistemas operando dentro da normalidade.';
  }
}

async function checkHealth() {
  const ramUsage = ((1 - os.freemem() / os.totalmem()) * 100).toFixed(1);
  const cpuLoad = os.loadavg()[0].toFixed(2);

  try {
    const start = Date.now();
    await axios.get(`http://${process.env.VISION_HOST}:5006/health`, { timeout: 5000 });
    const duration = Date.now() - start;

    const report = `RAM: ${ramUsage}% | CPU: ${cpuLoad} | VISION: ONLINE (${duration}ms)`;
    console.log(`[Sentinel] ${report}`);

    await log(report, 'SUCCESS', {
      source_brain: 'JARVIS',
      agent_id: 'sentinel',
      agent_role: 'GUARDIAN',
      action_type: 'HEALTH_CHECK',
      autonomy: 'N1',
      status: 'SUCCESS',
      duration_ms: duration,
      metadata: { source: 'sentinel.ts' }
    });

    await pool.query(
      `UPDATE agent_registry
       SET last_execution = NOW(),
           total_executions = COALESCE(total_executions, 0) + 1,
           status = 'ACTIVE'
       WHERE id = $1`,
      ['sentinel']
    );

    await updateAgentStats('sentinel', 'ACTIVE');

  } catch (error: any) {
    console.error('[Sentinel] HEALTH_CHECK ERROR:', error?.message || error);

    await log('Falha no health check do Sentinel', 'ERROR', {
      source_brain: 'JARVIS',
      agent_id: 'sentinel',
      agent_role: 'GUARDIAN',
      action_type: 'HEALTH_CHECK',
      autonomy: 'N1',
      status: 'ERROR',
      error_detail: { message: error?.message || String(error) },
      metadata: { source: 'sentinel.ts' }
    });

    await sendTelegram('🚨 *ALERTA:* V.I.S.I.O.N. Offline ou instável!');
  }
}

async function init() {
  console.log('🛡️ Sentinel Ativo com Camada de Inteligência.');

  const welcome = await getIAAnalysis('Sistema J.A.R.V.I.S. iniciado com sucesso no Mac Mini 1.');
  await sendTelegram(`🤖 *J.A.R.V.I.S. Boot:* ${welcome}`);

  await checkHealth();
  setInterval(checkHealth, 60000);
}

init().catch((err) => {
  console.error('[Sentinel] Erro fatal na inicialização:', err?.message || err);
});
