const imap = require('imap-simple');
const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: '/Users/jarvis001/jarvis/.env' });

const config = {
    imap: {
        user: process.env.GMAIL_USER,
        password: process.env.GMAIL_APP_PASSWORD,
        host: 'imap.gmail.com',
        port: 993,
        tls: true,
        tlsOptions: { rejectUnauthorized: false }, // Ignora erro de certificado auto-assinado
        authTimeout: 5000
    }
};

async function classifyEmail(subject) {
    const prompt = `Classifique este e-mail para um gestor de 9 empresas. Responda APENAS: URGENTE, IMPORTANTE ou ROTINA. Assunto: ${subject}`;
    try {
        const response = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
            model: "llama3-8b-8192",
            messages: [{ role: "user", content: prompt }]
        }, {
            headers: { 'Authorization': `Bearer ${process.env.GROQ_API_KEY}` }
        });
        return response.data.choices[0].message.content.trim().toUpperCase();
    } catch (e) { 
        return 'ROTINA'; 
    }
}

async function runFilter() {
    try {
        console.log(`[Filter] ${new Date().toLocaleTimeString()} - Conectando ao Gmail...`);
        const connection = await imap.connect(config);
        await connection.openBox('INBOX');
        
        const searchCriteria = ['UNSEEN'];
        const fetchOptions = { bodies: ['HEADER'], struct: true };
        const messages = await connection.search(searchCriteria, fetchOptions);

        if (messages.length === 0) {
            console.log(`[Filter] ✅ Sem e-mails novos.`);
        }

        for (const msg of messages) {
            const subject = msg.parts[0].body.subject[0];
            const priority = await classifyEmail(subject);
            console.log(`[Filter] 📩 Novo e-mail: ${subject} | Prioridade: ${priority}`);
            
            if (priority.includes('URGENTE')) {
                await axios.post(`https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
                    chat_id: process.env.TELEGRAM_CHAT_ID,
                    text: `🚨 *URGENTE (Filter):* ${subject}\n_Verifique seu Gmail, Comandante._`,
                    parse_mode: 'Markdown'
                });
            }
        }
        connection.end();
    } catch (e) {
        console.error('[Filter] ❌ Erro:', e.message);
    }
}

console.log('[Agente Filter] 🕵️ Ativado: ' + process.env.GMAIL_USER);
runFilter();
setInterval(runFilter, 300000);
