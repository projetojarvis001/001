import { loadSkills } from './skills';
import { log, queryLogs } from './logger';
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
          content: 'Você é o J.A.R.V.I.S., assistente executivo em português do Brasil, direto, prático e objetivo.' + loadSkills()
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


async function routeTask(prompt: string): Promise<DispatchResult> {
  const raw = String(prompt || '').trim();
  const normalized = raw.toLowerCase();

  const result: DispatchResult = {
    ok: true,
    command: 'route task',
    current_phase: 'Fase 20',
    dispatcher_status: 'ACTIVE',
    routing_basis: 'ruleset_v1',
    input_received: raw
  };

  if (
    normalized.includes('imagem') ||
    normalized.includes('foto') ||
    normalized.includes('ocr') ||
    normalized.includes('extracao') ||
    normalized.includes('extração') ||
    normalized.includes('vision')
  ) {
    result.task_type = 'multimodal_or_extraction';
    result.selected_engine = 'specialist';
    result.fallback_engine = 'premium';
    result.executor_agent = 'vision';
    result.risk_level = 'LOW';
    result.estimated_cost_usd = 0;
  } else if (
    normalized.includes('estrateg') ||
    normalized.includes('analise') ||
    normalized.includes('análise') ||
    normalized.includes('planejamento') ||
    normalized.includes('negocio') ||
    normalized.includes('negócio')
  ) {
    result.task_type = 'strategic_reasoning';
    result.selected_engine = 'premium';
    result.fallback_engine = 'local';
    result.executor_agent = 'dispatcher';
    result.risk_level = 'MEDIUM';
    result.estimated_cost_usd = 0;
  } else {
    result.task_type = 'simple_ops';
    result.selected_engine = 'local';
    result.fallback_engine = 'premium';
    result.executor_agent = 'devops';
    result.risk_level = 'LOW';
    result.estimated_cost_usd = 0;
  }

  result.routing_status = 'READY';
  result.next_step = 'executar tarefa com motor e agente recomendados';

  await log(`Route task decidido para prompt: ${raw}`, 'SUCCESS', {
    agent_id: 'dispatcher',
    agent_role: 'ROUTER',
    action_type: 'DISPATCH_ROUTE_TASK',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(result).slice(0, 500)
  });

  return result;
}



async function executeRouteTask(prompt: string): Promise<DispatchResult> {
  const routed = await routeTask(prompt);

  if (!routed?.ok) {
    return routed;
  }

  const executor = routed.executor_agent;
  const engine = routed.selected_engine;
  const raw = String(prompt || '').trim();
  const fallbackEngine = routed.fallback_engine || null;
  const estimatedCost = routed.estimated_cost_usd ?? 0;
  const budgetLimit = 5;
  const policyVersion = 'routing_policy_v1';

  try {
    const execResult = await executeWithFallback(raw, routed);

    if (!execResult?.ok) {
      return {
        ok: false,
        command: 'execute route task',
        executor_agent: execResult.executor_agent || executor,
        selected_engine: execResult.selected_engine || engine,
        fallback_engine: fallbackEngine,
        estimated_cost_usd: estimatedCost,
        budget_limit_usd: budgetLimit,
        execution_status: 'ERROR',
        execution_mode: 'failed_dispatch',
        policy_version: policyVersion,
        initial_engine: execResult.initial_engine || engine,
        final_engine: execResult.final_engine || engine,
        fallback_activated: execResult.fallback_activated || false,
        fallback_reason: execResult.fallback_reason || execResult.error || null,
        route: routed,
        error: execResult.error || 'Falha na execucao'
      };
    }

    const executionModeMap: Record<string, string> = {
      devops: 'delegated_devops',
      vision: 'delegated_vision',
      dispatcher: 'direct_dispatcher'
    };

    const finalResult = {
      ok: true,
      command: 'execute route task',
      routed_by: 'dispatcher',
      executor_agent: execResult.executor_agent || executor,
      selected_engine: execResult.selected_engine || engine,
      fallback_engine: fallbackEngine,
      estimated_cost_usd: estimatedCost,
      budget_limit_usd: budgetLimit,
      execution_status: 'SUCCESS',
      execution_mode: executionModeMap[execResult.executor_agent || executor] || 'direct_dispatcher',
      policy_version: policyVersion,
      initial_engine: execResult.initial_engine || engine,
      final_engine: execResult.final_engine || execResult.selected_engine || engine,
      fallback_activated: execResult.fallback_activated || false,
      fallback_reason: execResult.fallback_reason || null,
      route: routed,
      execution: execResult.execution
    };

    const logSummary = {
      ok: true,
      command: 'execute route task',
      routed_by: 'dispatcher',
      executor_agent: finalResult.executor_agent,
      selected_engine: finalResult.selected_engine,
      fallback_engine: finalResult.fallback_engine,
      estimated_cost_usd: finalResult.estimated_cost_usd,
      budget_limit_usd: finalResult.budget_limit_usd,
      execution_status: finalResult.execution_status,
      execution_mode: finalResult.execution_mode,
      policy_version: finalResult.policy_version,
      initial_engine: finalResult.initial_engine,
      final_engine: finalResult.final_engine,
      fallback_activated: finalResult.fallback_activated,
      fallback_reason: finalResult.fallback_reason,
      task_type: routed?.task_type || null,
      input_received: routed?.input_received || raw
    };

    await log(`Execute route task consolidado: ${raw}`, 'SUCCESS', {
      agent_id: 'dispatcher',
      agent_role: 'ROUTER',
      action_type: 'DISPATCH_EXECUTE_ROUTE_TASK',
      autonomy: 'N1',
      status: 'SUCCESS',
      output_summary: JSON.stringify(logSummary)
    });

    return finalResult;
  } catch (err: any) {
    await log(`Falha em execute route task: ${err.message}`, 'ERROR', {
      agent_id: 'dispatcher',
      agent_role: 'ROUTER',
      action_type: 'DISPATCH_EXECUTE_ROUTE_TASK',
      autonomy: 'N1',
      status: 'ERROR'
    });

    return {
      ok: false,
      command: 'execute route task',
      executor_agent: executor,
      selected_engine: engine,
      fallback_engine: fallbackEngine,
      estimated_cost_usd: estimatedCost,
      budget_limit_usd: budgetLimit,
      execution_status: 'ERROR',
      execution_mode: 'failed_dispatch',
      policy_version: policyVersion,
      initial_engine: engine,
      final_engine: engine,
      fallback_activated: false,
      fallback_reason: err.message,
      route: routed,
      error: err.message
    };
  }
}




async function executeWithFallback(raw: string, routed: any): Promise<any> {
  const executor = routed?.executor_agent;
  const engine = routed?.selected_engine;
  const taskType = routed?.task_type;
  const visionUrl = process.env.VISION_BRIDGE_URL || `http://${process.env.VISION_HOST}:5005/process`;

  const baseMeta = {
    initial_engine: engine,
    final_engine: engine,
    fallback_engine: routed?.fallback_engine || null,
    fallback_activated: false,
    fallback_reason: null
  };

  try {
    if (executor === 'devops') {
      const response = await runDevOpsCommand(raw);
      return {
        ok: true,
        executor_agent: 'devops',
        selected_engine: 'local',
        ...baseMeta,
        execution: response
      };
    }

    if (executor === 'vision') {
      const response = await axios.post(visionUrl, { prompt: raw }, { timeout: 60000 });
      return {
        ok: true,
        executor_agent: 'vision',
        selected_engine: 'specialist',
        ...baseMeta,
        execution: {
          provider: 'vision',
          target: visionUrl,
          response: response.data
        }
      };
    }

    const response = await callGroq(raw);
    return {
      ok: true,
      executor_agent: 'dispatcher',
      selected_engine: 'premium',
      ...baseMeta,
      execution: response
    };
  } catch (err: any) {
    if (engine === 'local' && routed?.fallback_engine === 'premium') {
      const fallbackResponse = await callGroq(raw);
      return {
        ok: true,
        executor_agent: 'dispatcher',
        selected_engine: 'premium',
        initial_engine: 'local',
        final_engine: 'premium',
        fallback_engine: 'premium',
        fallback_activated: true,
        fallback_reason: err.message,
        execution: fallbackResponse
      };
    }

    if (engine === 'specialist' && routed?.fallback_engine === 'premium') {
      const fallbackResponse = await callGroq(raw);
      return {
        ok: true,
        executor_agent: 'dispatcher',
        selected_engine: 'premium',
        initial_engine: 'specialist',
        final_engine: 'premium',
        fallback_engine: 'premium',
        fallback_activated: true,
        fallback_reason: err.message,
        execution: fallbackResponse
      };
    }

    if (engine === 'premium' && routed?.fallback_engine === 'local' && taskType === 'simple_ops') {
      const fallbackResponse = await runDevOpsCommand(raw);
      return {
        ok: true,
        executor_agent: 'devops',
        selected_engine: 'local',
        initial_engine: 'premium',
        final_engine: 'local',
        fallback_engine: 'local',
        fallback_activated: true,
        fallback_reason: err.message,
        execution: fallbackResponse
      };
    }

    return {
      ok: false,
      executor_agent: executor,
      selected_engine: engine,
      initial_engine: engine,
      final_engine: engine,
      fallback_engine: routed?.fallback_engine || null,
      fallback_activated: false,
      fallback_reason: err.message,
      error: err.message
    };
  }
}


async function runRoutingBoard(): Promise<DispatchResult> {
  const result: DispatchResult = {
    ok: true,
    command: 'routing board',
    current_phase: 'Fase 20',
    dispatcher_status: 'ACTIVE',
    policy_version: 'routing_policy_v1',
    budget_limit_usd: 5
  };

  try {
    const rows = await queryLogs(
      `SELECT created_at, action_type, status, output_summary
       FROM jarvis_logs
       WHERE agent_id = 'dispatcher'
         AND action_type IN ('DISPATCH_ROUTE_TASK', 'DISPATCH_EXECUTE_ROUTE_TASK')
       ORDER BY created_at DESC
       LIMIT 20`
    );

    const parsed = (rows || []).map((row: any) => {
      let payload: any = null;
      try {
        payload = row.output_summary ? JSON.parse(row.output_summary) : null;
      } catch {
        payload = null;
      }
      return { ...row, payload };
    });

    result.last_events = parsed.slice(0, 10);

    const routeOnly = parsed
      .map((r: any) => r.payload)
      .filter((p: any) => p && p.command === 'route task');

    const executeOnly = parsed
      .map((r: any) => r.payload)
      .filter((p: any) => p && p.command === 'execute route task');

    const engineCount: Record<string, number> = {};
    const agentCount: Record<string, number> = {};
    const taskTypeCount: Record<string, number> = {};

    for (const item of routeOnly) {
      const engine = item.selected_engine || 'unknown';
      const agent = item.executor_agent || 'unknown';
      const taskType = item.task_type || 'unknown';

      engineCount[engine] = (engineCount[engine] || 0) + 1;
      agentCount[agent] = (agentCount[agent] || 0) + 1;
      taskTypeCount[taskType] = (taskTypeCount[taskType] || 0) + 1;
    }

    result.route_volume = {
      total_routes: routeOnly.length,
      total_executions: executeOnly.length
    };

    result.engine_distribution = engineCount;
    result.executor_distribution = agentCount;
    result.task_type_distribution = taskTypeCount;

    result.last_route = routeOnly[0] || null;
    result.last_execution = executeOnly[0] || null;
    result.last_fallback_engine = routeOnly[0]?.fallback_engine || null;

    result.routing_status = 'READY';
    result.next_step = 'consolidar fallback, custo acumulado e priorizacao por task';
  } catch (err: any) {
    result.routing_status = 'ERROR';
    result.error = err.message;
    result.next_step = 'corrigir leitura do board de roteamento';
  }

  await log('Routing board consolidado com sucesso', 'SUCCESS', {
    agent_id: 'dispatcher',
    agent_role: 'ROUTER',
    action_type: 'DISPATCH_ROUTING_BOARD',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(result).slice(0, 500)
  });

  return result;
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
  const visionUrl = process.env.VISION_BRIDGE_URL || `http://${process.env.VISION_HOST}:5005/process`;

  if (lower.startsWith('devops:')) {
    const command = prompt.replace(/^devops:/i, '').trim();
    return await runDevOpsCommand(command);
  }

  if (lower.startsWith('dispatcher: routing board')) {
    return await runRoutingBoard();
  }

  if (lower.startsWith('dispatcher: execute route task')) {
    const payload = prompt.replace(/^dispatcher:\s*execute route task/i, '').trim();
    return await executeRouteTask(payload);
  }

  if (lower.startsWith('dispatcher: route task')) {
    const payload = prompt.replace(/^dispatcher:\s*route task/i, '').trim();
    return await routeTask(payload);
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
