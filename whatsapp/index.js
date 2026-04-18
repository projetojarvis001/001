/**
 * JARVIS WhatsApp Bridge :3005
 * Baileys + anti-bloqueio + integração JARVIS
 * Número: +5519995968004
 */
require('dotenv').config({ path: '/Users/jarvis001/jarvis/.env' });
const { default: makeWASocket, DisconnectReason, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const pino = require('pino');
const qrcode = require('qrcode-terminal');
const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// Config
const PORT = 3006;
const JARVIS_URL   = 'http://localhost:7777';
const SHADOW_URL   = 'http://192.168.8.124:5009';
const TELEGRAM_BOT = process.env.TELEGRAM_BOT_TOKEN || '';
const TELEGRAM_CHAT = '170323936';
const AUTH_DIR     = '/Users/jarvis001/jarvis/data/whatsapp_auth';
const LOG_FILE     = '/tmp/whatsapp_bridge.log';
const MEU_NUMERO   = '5519995968004';

// Anti-bloqueio — rate limiting por contato
const rateLimiter = {};
const MAX_MSGS_POR_HORA = 20;
const DELAY_MIN_MS = 1500;  // 1.5s minimo entre msgs
let ultimaResposta = 0;

// Estado
let sock = null;
let conectado = false;
let qrAtual = '';
let totalMensagens = 0;
let totalRespostas = 0;

function log(msg) {
    const linha = `[${new Date().toISOString()}] ${msg}`;
    console.log(linha);
    fs.appendFileSync(LOG_FILE, linha + '\n');
}

function podeMensagem(numero) {
    const agora = Date.now();
    const hora = Math.floor(agora / 3600000);
    const chave = `${numero}_${hora}`;
    
    rateLimiter[chave] = (rateLimiter[chave] || 0) + 1;
    
    // Limpa entradas antigas
    Object.keys(rateLimiter).forEach(k => {
        if (!k.endsWith(`_${hora}`)) delete rateLimiter[k];
    });
    
    return rateLimiter[chave] <= MAX_MSGS_POR_HORA;
}

async function aguardarDelay() {
    const agora = Date.now();
    const diff = agora - ultimaResposta;
    if (diff < DELAY_MIN_MS) {
        await new Promise(r => setTimeout(r, DELAY_MIN_MS - diff));
    }
    ultimaResposta = Date.now();
}

async function consultarJarvis(mensagem, numero, nome) {
    try {
        // Tenta JARVIS core
        const resp = await axios.post(`${JARVIS_URL}/chat`, {
            message: mensagem,
            user_id: numero,
            user_name: nome,
            canal: 'whatsapp'
        }, { timeout: 15000 });
        return resp.data?.response || resp.data?.message || null;
    } catch {
        try {
            // Fallback: Shadow VISION
            const resp2 = await axios.post(`${SHADOW_URL}/chat`, {
                message: mensagem,
                context: `Usuario WhatsApp: ${nome} (${numero})`
            }, { timeout: 15000 });
            return resp2.data?.response || null;
        } catch {
            return null;
        }
    }
}

function formatarResposta(texto) {
    if (!texto) return null;
    // Remove markdown pesado para WhatsApp
    return texto
        .replace(/#{1,6}\s/g, '*')
        .replace(/\*\*(.*?)\*\*/g, '*$1*')
        .replace(/`{3}[\s\S]*?`{3}/g, '')
        .slice(0, 1500);  // Limite seguro WhatsApp
}

async function processarMensagem(msg) {
    if (!msg.message) return;
    
    const jid = msg.key.remoteJid;
    const fromMe = msg.key.fromMe;
    if (fromMe) return;  // Ignora mensagens proprias
    
    // Extrai texto
    const texto = msg.message?.conversation ||
                  msg.message?.extendedTextMessage?.text ||
                  msg.message?.imageMessage?.caption || '';
    
    if (!texto) return;
    
    // Extrai numero limpo
    const numero = jid.replace('@s.whatsapp.net','').replace('@g.us','');
    const nome = msg.pushName || numero;
    const isGrupo = jid.endsWith('@g.us');
    
    // Grupos: responde apenas se mencionar o bot
    if (isGrupo && !texto.toLowerCase().includes('jarvis')) return;
    
    totalMensagens++;
    log(`MSG de ${nome} (${numero}): ${texto.slice(0,80)}`);
    
    // Anti-bloqueio
    if (!podeMensagem(numero)) {
        log(`RATE LIMIT atingido para ${numero}`);
        return;
    }
    
    // Comandos especiais
    if (texto.startsWith('/')) {
        await processarComando(texto, jid, numero, nome);
        return;
    }
    
    // Consulta JARVIS
    const respostaRaw = await consultarJarvis(texto, numero, nome);
    if (!respostaRaw) return;
    
    const resposta = formatarResposta(respostaRaw);
    if (!resposta) return;
    
    await aguardarDelay();
    
    try {
        await sock.sendMessage(jid, { text: resposta });
        totalRespostas++;
        log(`RESP para ${nome}: ${resposta.slice(0,60)}...`);
    } catch (e) {
        log(`ERRO ao enviar: ${e.message}`);
    }
}

async function processarComando(texto, jid, numero, nome) {
    const cmd = texto.split(' ')[0].toLowerCase();
    
    const respostas = {
        '/oi':    `Olá ${nome}! 👋 Sou o JARVIS, assistente da WPS Digital. Como posso ajudar?`,
        '/ajuda': `*Comandos disponíveis:*\n/oi - Saudação\n/status - Status do sistema\n/contato - Falar com humano`,
        '/status': `✅ JARVIS Online\n🕐 ${new Date().toLocaleString('pt-BR')}\nMsgs hoje: ${totalMensagens}`,
        '/contato': `Para falar com nossa equipe:\n📧 contato@wps.com.br\n📞 +55 19 99596-8004`,
    };
    
    const resp = respostas[cmd];
    if (resp) {
        await aguardarDelay();
        await sock.sendMessage(jid, { text: resp });
        totalRespostas++;
    }
}

async function conectarWhatsApp() {
    fs.mkdirSync(AUTH_DIR, { recursive: true });
    
    const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
    
    sock = makeWASocket({
        auth: state,
        printQRInTerminal: false,
        logger: pino({ level: 'silent' }),
        browser: ['JARVIS', 'Chrome', '1.0.0'],
        connectTimeoutMs: 60000,
        defaultQueryTimeoutMs: 30000,
        keepAliveIntervalMs: 25000,
        retryRequestDelayMs: 2000,
        markOnlineOnConnect: false,  // Anti-bloqueio: nao aparece online
    });
    
    // QR Code
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;
        
        if (qr) {
            qrAtual = qr;
            qrcode.generate(qr, { small: true });
            log('QR CODE gerado — escaneie com WhatsApp');
            
            // Envia QR no Telegram
            if (TELEGRAM_BOT) {
                try {
                    await axios.post(
                        `https://api.telegram.org/bot${TELEGRAM_BOT}/sendMessage`,
                        { chat_id: TELEGRAM_CHAT,
                          text: `📱 JARVIS WhatsApp\nQR Code gerado!\nAcesse: http://localhost:3005/qr\nOu veja no terminal do JARVIS` }
                    );
                } catch {}
            }
        }
        
        if (connection === 'open') {
            conectado = true;
            qrAtual = '';
            log(`WhatsApp conectado: ${MEU_NUMERO}`);
            
            if (TELEGRAM_BOT) {
                try {
                    await axios.post(
                        `https://api.telegram.org/bot${TELEGRAM_BOT}/sendMessage`,
                        { chat_id: TELEGRAM_CHAT,
                          text: `✅ WhatsApp Conectado\nNúmero: +${MEU_NUMERO}\nJARVIS pronto para atender` }
                    );
                } catch {}
            }
        }
        
        if (connection === 'close') {
            conectado = false;
            const codigo = lastDisconnect?.error?.output?.statusCode;
            log(`Desconectado — codigo: ${codigo}`);
            
            // Reconecta automaticamente exceto logout
            if (codigo !== DisconnectReason.loggedOut) {
                log('Reconectando em 5s...');
                setTimeout(conectarWhatsApp, 5000);
            } else {
                log('LOGOUT detectado — limpa sessao');
                fs.rmSync(AUTH_DIR, { recursive: true, force: true });
            }
        }
    });
    
    sock.ev.on('creds.update', saveCreds);
    
    // Mensagens
    sock.ev.on('messages.upsert', async ({ messages, type }) => {
        if (type !== 'notify') return;
        for (const msg of messages) {
            try {
                await processarMensagem(msg);
            } catch (e) {
                log(`Erro processando msg: ${e.message}`);
            }
        }
    });
}

// API REST
app.get('/', (req, res) => {
    res.json({
        ok: true,
        service: 'jarvis-whatsapp',
        numero: MEU_NUMERO,
        conectado,
        total_mensagens: totalMensagens,
        total_respostas: totalRespostas,
        rate_limit: `${MAX_MSGS_POR_HORA} msgs/hora por contato`,
        anti_bloqueio: 'ativo'
    });
});

app.get('/qr', (req, res) => {
    if (conectado) {
        res.send('<h2>✅ WhatsApp já conectado!</h2>');
    } else if (qrAtual) {
        res.send(`
            <html><body style="text-align:center;font-family:sans-serif">
            <h2>Escaneie o QR Code</h2>
            <p>Abra WhatsApp → Dispositivos conectados → Conectar dispositivo</p>
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(qrAtual)}" />
            <p><small>Atualiza automaticamente em 30s</small></p>
            <script>setTimeout(()=>location.reload(),30000)</script>
            </body></html>
        `);
    } else {
        res.send('<h2>Aguardando QR Code...</h2><script>setTimeout(()=>location.reload(),3000)</script>');
    }
});

app.post('/enviar', async (req, res) => {
    const { numero, mensagem } = req.body;
    if (!conectado) return res.json({ ok: false, error: 'nao conectado' });
    if (!numero || !mensagem) return res.json({ ok: false, error: 'numero e mensagem obrigatorios' });
    
    if (!podeMensagem(numero)) {
        return res.json({ ok: false, error: 'rate limit atingido' });
    }
    
    try {
        const jid = numero.includes('@') ? numero : `${numero}@s.whatsapp.net`;
        await aguardarDelay();
        await sock.sendMessage(jid, { text: mensagem });
        res.json({ ok: true, enviado: true });
    } catch (e) {
        res.json({ ok: false, error: e.message });
    }
});

app.get('/status', (req, res) => {
    res.json({
        conectado,
        numero: MEU_NUMERO,
        msgs_recebidas: totalMensagens,
        msgs_respondidas: totalRespostas,
        rate_limits_ativos: Object.keys(rateLimiter).length
    });
});

app.listen(PORT, () => {
    log(`JARVIS WhatsApp Bridge rodando em :${PORT}`);
    log(`QR Code: http://localhost:${PORT}/qr`);
});

conectarWhatsApp();
