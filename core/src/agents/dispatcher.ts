import { pool, log, updateAgentStats } from '../logger.js';

interface ModelInfo {
  id: string;
  provider: string;
  tier: string;
  categories: string[];
  max_context: number;
  cost_per_1k_input: number;
  cost_per_1k_output: number;
  avg_latency_ms: number;
  success_rate: number;
  config: Record<string, unknown>;
}

type TaskCategory = 'TRIAGE' | 'CODE' | 'REASON' | 'VISION' | 'LONG_CTX';

function classifyTask(prompt: string): TaskCategory {
  const lower = prompt.toLowerCase();
  if (lower.match(/imagem|foto|pdf|screenshot|print|visual/)) return 'VISION';
  if (lower.match(/contrato|relatório completo|documento inteiro|todas as páginas/)) return 'LONG_CTX';
  if (lower.match(/código|bug|function|api|typescript|python|sql|debug|deploy/)) return 'CODE';
  if (lower.match(/calcul|matem|estatíst|probabilid|anal[iy]s|estratég|investim|margem|lu[kc]ro/)) return 'REASON';
  return 'TRIAGE';
}

async function getBestModel(category: TaskCategory, excludeIds: string[] = []): Promise<ModelInfo | null> {
  const excludeClause = excludeIds.length ? `AND id NOT IN (${excludeIds.map((_,i) => `$${i+2}`).join(',')})` : '';
  const result = await pool.query(
    `SELECT id, provider, tier, categories, max_context, cost_per_1k_input, cost_per_1k_output, avg_latency_ms, success_rate, config
     FROM model_registry
     WHERE status = 'ACTIVE' AND $1 = ANY(categories) ${excludeClause}
     ORDER BY CASE tier WHEN 'FREE' THEN 0 WHEN 'LOW' THEN 1 WHEN 'PREMIUM' THEN 2 END, success_rate DESC, avg_latency_ms ASC LIMIT 1`,
    [category, ...excludeIds]
  );
  return result.rows[0] || null;
}

export async function dispatch(prompt: string, options?: { systemPrompt?: string; forceCategory?: TaskCategory; }) {
  const start = Date.now();
  const category = options?.forceCategory || classifyTask(prompt);
  const model = await getBestModel(category);
  
  if (!model) throw new Error(`Nenhum modelo ativo para a categoria ${category}`);

  // Lógica de chamada simplificada para validação de Bootstrap
  console.log(`[Dispatcher] Roteando para: ${model.id} (Categoria: ${category})`);
  return { text: "Cérebro Ativo: Roteamento Funcional", model_used: model.id, category };
}
