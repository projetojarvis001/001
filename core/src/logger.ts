import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export const log = async (
  msg: string,
  level: string = 'INFO',
  meta?: {
    source_brain?: 'JARVIS' | 'VISION';
    agent_id?: string;
    agent_role?: string;
    action_type?: string;
    model_used?: string | null;
    autonomy?: 'N1' | 'N2' | 'N3' | 'N4';
    status?: string;
    output_summary?: string | null;
    duration_ms?: number;
    error_detail?: Record<string, any> | null;
    metadata?: Record<string, any> | null;
  }
) => {
  console.log(`[${level}]: ${msg}`);

  try {
    await pool.query(
      `INSERT INTO jarvis_logs
      (
        source_brain,
        agent_id,
        agent_role,
        model_used,
        action_type,
        autonomy,
        input_summary,
        output_summary,
        duration_ms,
        status,
        error_detail,
        metadata
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [
        meta?.source_brain || 'JARVIS',
        meta?.agent_id || 'dispatcher',
        meta?.agent_role || 'ROUTER',
        meta?.model_used || null,
        meta?.action_type || 'LOG',
        meta?.autonomy || 'N1',
        msg.slice(0, 500),
        meta?.output_summary || null,
        meta?.duration_ms || 0,
        meta?.status || level,
        meta?.error_detail ? JSON.stringify(meta.error_detail) : null,
        JSON.stringify(meta?.metadata || { source: 'logger.ts', level })
      ]
    );
  } catch (err: any) {
    console.error('[LOGGER_DB_ERROR]:', err.message);
  }
};

export const updateAgentStats = async (agent: string, status: string) => {
  await log(`updateAgentStats chamado para ${agent} => ${status}`, 'INFO', {
    source_brain: 'JARVIS',
    agent_id: agent,
    agent_role: 'AGENT',
    action_type: 'UPDATE_AGENT_STATS',
    autonomy: 'N1',
    status,
    metadata: { function: 'updateAgentStats' }
  });
};

export async function queryLogs(sql: string, params: any[] = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

