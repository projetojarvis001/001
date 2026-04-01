const { Dispatcher } = require('../services/dispatcher');
// ... (código anterior de conexão) ...

async function analyzeSystemStatus(statusReport) {
  const analysis = await Dispatcher.route(
    `Analise este status de servidor e resuma em uma frase para um gestor de 9 empresas: ${statusReport}`,
    'low'
  );
  return analysis;
}

// O Sentinel agora enviará uma análise inteligente para o Telegram
