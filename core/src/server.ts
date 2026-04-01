import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import { dispatch } from './dispatcher';
import { pool } from './logger';
import http from 'http';

const app = express();
app.use(express.json());

app.post('/ask', async (req, res) => {
  const { prompt, category } = req.body;
  try {
    const result = await dispatch(prompt, category);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  console.log('--- J.A.R.V.I.S. RELATÓRIO DE BOOT ---');
  
  // 1. Teste de Banco de Dados
  try {
    await pool.query('SELECT NOW()');
    console.log('✅ DATABASE: CONECTADO (Postgres)');
  } catch (err) {
    console.log('❌ DATABASE: FALHA NA CONEXÃO');
  }

  // 2. Teste de Conexão com Vision (Mac 2)
  console.log(`📡 VISION HOST: ${process.env.VISION_HOST}`);
  
  console.log(`🚀 CORE OPERACIONAL EM: http://localhost:${PORT}`);
});
