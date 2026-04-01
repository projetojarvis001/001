const fs = require('fs');
const path = require('path');
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
  try {
    const response = await axios.post('https://api.openai.com/v1/embeddings', {
      input: text,
      model: "text-embedding-3-small"
    }, {
      headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` }
    });
    return response.data.data[0].embedding;
  } catch (e) { console.error("Erro Embedding:", e.message); return null; }
}

async function run() {
  await pgClient.connect();
  const filePath = path.join(__dirname, '../knowledge/wps_info.txt');
  const content = fs.readFileSync(filePath, 'utf8');
  
  console.log(`[Ingestor] 📖 Lendo documento: ${filePath}`);
  const embedding = await getEmbedding(content);

  if (embedding) {
    await pgClient.query(
      "INSERT INTO business_context (company_name, category, content, embedding) VALUES ($1, $2, $3, $4)",
      ['WPS Digital', 'Tecnologia', content, JSON.stringify(embedding)]
    );
    console.log("[Ingestor] ✅ Dados da WPS Digital indexados com sucesso!");
  }
  await pgClient.end();
}

run();
