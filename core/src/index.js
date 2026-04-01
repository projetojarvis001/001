const { Telegraf } = require('telegraf');
require('dotenv').config();
const { exec } = require('child_process');

const bot = new Telegraf(process.env.TELEGRAM_BOT_TOKEN);

// Inicializa o Sentinel (Vigilância)
require('./agents/sentinel.js');

bot.start((ctx) => ctx.reply('🚀 hubOS Online. Use /learn [texto] para me ensinar algo ou /info [termo] para consultar.'));

// --- COMANDO PARA ENSINAR O JARVIS ---
bot.command('learn', async (ctx) => {
    const info = ctx.payload;
    if (!info) return ctx.reply('❓ O que você quer que eu aprenda? Ex: /learn A WPS Digital fatura X por mês.');

    ctx.reply('🧠 Processando e salvando na minha memória de longo prazo...');

    // Chama o ingestor de forma dinâmica (passando o texto direto)
    exec(`node src/agents/butler.js --learn "${info}"`, (error, stdout, stderr) => {
        if (error) return ctx.reply(`❌ Erro ao aprender: ${error.message}`);
        ctx.reply('✅ Entendido, Comandante. Informação registrada com sucesso.');
    });
});

// --- COMANDO PARA CONSULTAR ---
bot.command('info', (ctx) => {
    const query = ctx.payload;
    if (!query) return ctx.reply('❓ O que deseja consultar?');

    exec(`node src/agents/butler.js "${query}"`, (error, stdout, stderr) => {
        if (error) return ctx.reply(`❌ Erro na consulta: ${error.message}`);
        const response = stdout.split('🤖 BUTLER:')[1] || stdout;
        ctx.reply(`🤖 *Butler informa:*\n\n${response.trim()}`, { parse_mode: 'Markdown' });
    });
});

// bot.launch(); // Desativado para Bootstrap

// Para isso:
try {
  if (process.env.TELEGRAM_BOT_TOKEN) {
    // bot.launch(); // Desativado para Bootstrap
    console.log("✅ Telegram Bot ativo.");
  } else {
    console.log("⚠️ Telegram Bot ignorado (Token ausente).");
  }
} catch (e) {
  console.log("❌ Falha ao iniciar Telegram:", e.message);
}
