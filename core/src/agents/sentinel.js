// SENTINEL.JS — stub que delega para Python SENTINEL :7792
const http = require('http');

function checkSentinel() {
    http.get('http://localhost:7792/health', (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => console.log('[Sentinel] Python SENTINEL ativo :7792'));
    }).on('error', () => {
        console.log('[Sentinel] Python SENTINEL offline — verificar :7792');
    });
}

checkSentinel();
setInterval(checkSentinel, 60000);
module.exports = { checkSentinel };
