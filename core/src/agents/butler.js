const { Client } = require('pg');
require('dotenv').config();
const axios = require('axios');

const pgClient = new Client({
  host: process.env.POSTGRES_HOST || 'postgres',
  port: 5432,
  user: 'jarvis_admin',
  password: process.env.PG_PASSWORD,
  database: 'jarvis'
});

async function getEmbedding(text) {
  const response = await axios.post('https://api.openai.com/v1/embeddings', {
    input: text, model: "text-embedding-3-small"
  }, { headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` } });
  return response.data.data[0].embedding;
}

async function handleQuery(query) {
  await pgClient.connect();
  const queryEmbedding = await getEmbedding(query);
  
  // BUSCA VETORIAL: Encontra o conteúdo mais próximo semanticamente
  const res = await pgClient.query(
    `SELECT content FROM business_context 
     ORDER BY embedding <=> $1::vector 
     LIMIT 1`, [JSON.stringify(queryEmbedding)]
  );

  if (res.rows.length > 0) {
    const context = res.rows[0].content;
    const aiRes = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
      model: "llama-3.3-70b-versatile",
      messages: [
        { role: "system", content: `Você é o Butler. Use este contexto OFICIAL para responder: ${context}` },
        { role: "user", content: query }
      ]
    }, { headers: { 'Authorization': `Bearer ${process.env.GROQ_API_KEY}` } });
    
    console.log(`🤖 BUTLER: ${aiRes.data.choices[0].message.content}`);
  }
  await pgClient.end();
}

const args = process.argv.slice(2).join(" ");
if (args) handleQuery(args);
