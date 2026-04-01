import { log } from './logger';
import axios from 'axios';
import { runDevOpsCommand } from './agents/devops';

type DispatchResult = Record<string, any>;

async function callGroq(prompt: string): Promise<DispatchResult> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    await log('GROQ_API_KEY ausente', 'ERROR', {
      agent_id: 'dispatcher',
      agent_role: 'ROUTER',
      action_type: 'DISPATCH_GROQ',
      model_used: 'groq/llama-3.3-70b-versatile',
      autonomy: 'N1',
      status: 'ERROR'
    });
    return {
      ok: false,
      error: 'GROQ_API_KEY ausente',
      provider: 'groq'
    };
  }

  const model = 'llama-3.3-70b-versatile';

  const response = await axios.post(
    'https://api.groq.com/openai/v1/chat/completions',
    {
      model,
      messages: [
        {
          role: 'system',
          content: 'Você é o J.A.R.V.I.S., assistente executivo em português do Brasil, direto, prático e objetivo.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3
    },
    {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000
    }
  );

  const text = response.data?.choices?.[0]?.message?.content || '';

  await log(`Resposta gerada via Groq para prompt: ${prompt}`, 'SUCCESS', {
    agent_id: 'dispatcher',
    agent_role: 'ROUTER',
    action_type: 'DISPATCH_GROQ',
    model_used: `groq/${model}`,
    autonomy: 'N1',
    status: 'SUCCESS'
  });

  return {
    ok: true,
    provider: 'groq',
    model,
    category: 'TRIAGE',
    response: text.trim()
  };
}

export const dispatch = async (prompt: string, category?: string) => {
  await log(`Roteando prompt: ${prompt}`, 'INFO', {
    agent_id: 'dispatcher',
    agent_role: 'ROUTER',
    action_type: 'DISPATCH_START',
    autonomy: 'N1',
    status: 'STARTED'
  });

  const lower = String(prompt || '').toLowerCase();
  const visionUrl = 'http://192.168.8.124:5005/process';

  if (lower.startsWith('devops:')) {
    const command = prompt.replace(/^devops:/i, '').trim();
    return await runDevOpsCommand(command);
  }

  if (
    lower.includes('olhar') ||
    lower.includes('ver') ||
    lower.includes('imagem') ||
    lower.includes('foto')
  ) {
    try {
      const response = await axios.post(visionUrl, { prompt }, { timeout: 60000 });

      await log(`Resposta recebida do Vision para prompt: ${prompt}`, 'SUCCESS', {
        agent_id: 'dispatcher',
        agent_role: 'ROUTER',
        action_type: 'DISPATCH_VISION',
        model_used: 'vision/mac2',
        autonomy: 'N1',
        status: 'SUCCESS'
      });

      return {
        ok: true,
        provider: 'vision',
        target: visionUrl,
        response: response.data
      };
    } catch (err: any) {
      await log(`Falha ao contactar Vision: ${err.message}`, 'ERROR', {
        agent_id: 'dispatcher',
        agent_role: 'ROUTER',
        action_type: 'DISPATCH_VISION',
        model_used: 'vision/mac2',
        autonomy: 'N1',
        status: 'ERROR'
      });

      return {
        ok: false,
        error: 'Vision Offline',
        detail: 'Não foi possível falar com o Mac 2 na porta 5005',
        target: visionUrl
      };
    }
  }

  try {
    return await callGroq(prompt);
  } catch (err: any) {
    await log(`Falha no dispatcher principal: ${err.message}`, 'ERROR', {
      agent_id: 'dispatcher',
      agent_role: 'ROUTER',
      action_type: 'DISPATCH_MAIN',
      autonomy: 'N1',
      status: 'ERROR'
    });

    return {
      ok: false,
      error: 'Dispatcher falhou',
      detail: err.message
    };
  }
};
