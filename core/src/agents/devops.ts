import { exec } from 'child_process';
import { promisify } from 'util';
import { log, pool } from '../logger';

const execAsync = promisify(exec);

const SAFE_COMMANDS = [
  'pwd',
  'ls',
  'whoami',
  'hostname',
  'docker ps',
  'docker compose ps',
  'git status',
  'git log --oneline -n 5',
  'pm2 list'
];

const APPROVAL_COMMANDS = [
  'git add .',
  'git commit',
  'git push',
  'docker restart',
  'docker compose restart',
  'docker compose up',
  'docker compose down',
  'git status',
  'git log --oneline -n 5',
  'docker compose ps'
];

const APPROVED_EXECUTION_COMMANDS = [
  'git add .',
  'git status',
  'git log --oneline -n 5',
  'docker compose ps'
];


function isCommandAllowed(command: string): boolean {
  const normalized = command.trim().toLowerCase();
  return SAFE_COMMANDS.some((allowed) => normalized === allowed.toLowerCase());
}

function requiresApproval(command: string): boolean {
  const normalized = command.trim().toLowerCase();
  return APPROVAL_COMMANDS.some((prefix) => normalized.startsWith(prefix.toLowerCase()));
}

async function listPendingDecisions() {
  const result = await pool.query(
    `SELECT id, created_at, agent_id, autonomy, description, recommendation, status, resolved_at, resolved_by
     FROM pending_decisions
     ORDER BY created_at DESC
     LIMIT 10`
  );

  await log('Consulta de pending_decisions executada com sucesso', 'SUCCESS', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_LIST_PENDING',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(result.rows).slice(0, 500),
    metadata: { total: result.rows.length }
  });

  return {
    ok: true,
    command: 'pending list',
    decisions: result.rows
  };
}

async function createPendingDecision(command: string) {
  const result = await pool.query(
    `INSERT INTO pending_decisions
      (agent_id, autonomy, description, options, recommendation, status)
     VALUES ($1, $2, $3, $4::jsonb, $5, $6)
     RETURNING id, created_at, status`,
    [
      'devops',
      'N2',
      `Aprovação necessária para executar comando: ${command}`,
      JSON.stringify(['APPROVED', 'DENIED']),
      'DENIED',
      'PENDING'
    ]
  );

  await log(`Pedido de aprovação criado para comando: ${command}`, 'INFO', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_APPROVAL_REQUESTED',
    autonomy: 'N2',
    status: 'PENDING',
    metadata: { command, decision_id: result.rows[0].id }
  });

  return {
    ok: false,
    approval_required: true,
    command,
    decision: result.rows[0]
  };
}


async function executeApprovedDecision(decisionId: string) {
  const result = await pool.query(
    `SELECT id, description, status
     FROM pending_decisions
     WHERE id = $1
     LIMIT 1`,
    [decisionId]
  );

  const decision = result.rows[0];

  if (!decision) {
    return {
      ok: false,
      error: 'Decisão não encontrada',
      decision_id: decisionId
    };
  }

  if (decision.status !== 'APPROVED') {
    return {
      ok: false,
      error: 'Decisão ainda não aprovada',
      decision_id: decisionId,
      status: decision.status
    };
  }

  const prefix = 'Aprovação necessária para executar comando: ';
  const command = String(decision.description || '').startsWith(prefix)
    ? String(decision.description).slice(prefix.length)
    : '';

  if (!command) {
    return {
      ok: false,
      error: 'Não foi possível extrair o comando da decisão',
      decision_id: decisionId
    };
  }

  const approvedAllowed = APPROVED_EXECUTION_COMMANDS.some(
    (allowed) => command.trim().toLowerCase() === allowed.toLowerCase()
  );

  if (!approvedAllowed) {
    await log(`Execução aprovada bloqueada por whitelist: ${command}`, 'ERROR', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_APPROVAL_EXECUTION_BLOCKED',
      autonomy: 'N2',
      status: 'BLOCKED',
      metadata: { command, decision_id: decisionId }
    });

    return {
      ok: false,
      error: 'Comando aprovado, mas ainda não permitido para execução automática nesta fase',
      decision_id: decisionId,
      command
    };
  }

  await log(`Execução de decisão aprovada iniciada: ${decisionId}`, 'INFO', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_APPROVAL_EXECUTION_STARTED',
    autonomy: 'N2',
    status: 'STARTED',
    metadata: { command, decision_id: decisionId }
  });

  try {
    const normalizedCommand = command.trim().toLowerCase();
    const commandCwd =
      normalizedCommand.startsWith('git ')
        ? '/host_jarvis'
        : '/app';

    const { stdout, stderr } = await execAsync(command, {
      cwd: commandCwd,
      timeout: 15000,
      maxBuffer: 1024 * 1024
    });

    await log(`Execução de decisão aprovada concluída: ${decisionId}`, 'SUCCESS', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_APPROVAL_EXECUTION_SUCCESS',
      autonomy: 'N2',
      status: 'SUCCESS',
      output_summary: stdout?.slice(0, 500) || null,
      metadata: { command, decision_id: decisionId, stderr: stderr?.slice(0, 500) || null }
    });

    return {
      ok: true,
      command: 'pending execute',
      decision_id: decisionId,
      executed_command: command,
      stdout: stdout || '',
      stderr: stderr || ''
    };
  } catch (err: any) {
    await log(`Execução de decisão aprovada falhou: ${decisionId}`, 'ERROR', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_APPROVAL_EXECUTION_ERROR',
      autonomy: 'N2',
      status: 'ERROR',
      error_detail: { message: err.message },
      metadata: { command, decision_id: decisionId }
    });

    return {
      ok: false,
      error: err.message,
      decision_id: decisionId,
      executed_command: command
    };
  }
}

async function runCoreDoctor() {
  const checks: Record<string, any> = {};

  try {
    const { stdout } = await execAsync('pwd', { cwd: '/app', timeout: 5000 });
    checks.pwd = stdout.trim();
  } catch (err: any) {
    checks.pwd = `ERRO: ${err.message}`;
  }

  try {
    const { stdout } = await execAsync('ls', { cwd: '/app', timeout: 5000 });
    checks.ls = stdout.trim().split('\n');
  } catch (err: any) {
    checks.ls = [`ERRO: ${err.message}`];
  }

  try {
    const { stdout } = await execAsync('whoami', { cwd: '/app', timeout: 5000 });
    checks.user = stdout.trim();
  } catch (err: any) {
    checks.user = `ERRO: ${err.message}`;
  }

  try {
    const { stdout } = await execAsync('which git', { cwd: '/app', timeout: 5000 });
    checks.git = stdout.trim() || 'ausente';
  } catch {
    checks.git = 'ausente';
  }

  await log('Core doctor executado com sucesso', 'SUCCESS', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_CORE_DOCTOR',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(checks).slice(0, 500),
    metadata: checks
  });

  return {
    ok: true,
    command: 'core doctor',
    checks
  };
}

export async function runDevOpsCommand(command: string) {
  await log(`DevOps recebeu comando: ${command}`, 'INFO', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_COMMAND_RECEIVED',
    autonomy: 'N1',
    status: 'STARTED',
    metadata: { command }
  });

  const normalized = command.trim().toLowerCase();

  if (normalized === 'core doctor') {
    return await runCoreDoctor();
  }

  if (normalized === 'pending list') {
    return await listPendingDecisions();
  }

  if (normalized.startsWith('pending execute ')) {
    const decisionId = command.trim().split(' ').slice(2).join(' ').trim();
    return await executeApprovedDecision(decisionId);
  }

  if (normalized.startsWith('pending approve ')) {
    const decisionId = command.trim().split(' ').slice(2).join(' ').trim();
    const result = await pool.query(
      `UPDATE pending_decisions
       SET status = 'APPROVED', resolved_at = NOW(), resolved_by = 'jarvis'
       WHERE id = $1
       RETURNING id, created_at, agent_id, autonomy, description, recommendation, status, resolved_at, resolved_by`,
      [decisionId]
    );

    await log(`Decisão aprovada via DevOps: ${decisionId}`, 'SUCCESS', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_APPROVAL_APPROVED',
      autonomy: 'N2',
      status: 'SUCCESS',
      metadata: { decision_id: decisionId }
    });

    return {
      ok: true,
      command: 'pending approve',
      decision: result.rows[0] || null
    };
  }

  if (normalized.startsWith('pending deny ')) {
    const decisionId = command.trim().split(' ').slice(2).join(' ').trim();
    const result = await pool.query(
      `UPDATE pending_decisions
       SET status = 'DENIED', resolved_at = NOW(), resolved_by = 'jarvis'
       WHERE id = $1
       RETURNING id, created_at, agent_id, autonomy, description, recommendation, status, resolved_at, resolved_by`,
      [decisionId]
    );

    await log(`Decisão negada via DevOps: ${decisionId}`, 'SUCCESS', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_APPROVAL_DENIED',
      autonomy: 'N2',
      status: 'SUCCESS',
      metadata: { decision_id: decisionId }
    });

    return {
      ok: true,
      command: 'pending deny',
      decision: result.rows[0] || null
    };
  }

  if (requiresApproval(command)) {
    return await createPendingDecision(command);
  }

  if (!isCommandAllowed(command)) {
    await log(`Comando bloqueado pelo DevOps: ${command}`, 'ERROR', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_COMMAND_BLOCKED',
      autonomy: 'N1',
      status: 'BLOCKED',
      metadata: { command }
    });

    return {
      ok: false,
      error: 'Comando não permitido nesta fase',
      command
    };
  }

  try {
    const normalizedCommand = command.trim().toLowerCase();
    const commandCwd =
      normalizedCommand.startsWith('git ')
        ? '/host_jarvis'
        : '/app';

    const { stdout, stderr } = await execAsync(command, {
      cwd: commandCwd,
      timeout: 15000,
      maxBuffer: 1024 * 1024
    });

    await log(`Comando executado com sucesso: ${command}`, 'SUCCESS', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_COMMAND_SUCCESS',
      autonomy: 'N1',
      status: 'SUCCESS',
      output_summary: stdout?.slice(0, 500) || null,
      metadata: { command, stderr: stderr?.slice(0, 500) || null }
    });

    return {
      ok: true,
      command,
      stdout: stdout || '',
      stderr: stderr || ''
    };
  } catch (err: any) {
    await log(`Falha ao executar comando DevOps: ${command}`, 'ERROR', {
      source_brain: 'JARVIS',
      agent_id: 'devops',
      agent_role: 'DEVOPS',
      action_type: 'DEVOPS_COMMAND_ERROR',
      autonomy: 'N1',
      status: 'ERROR',
      error_detail: { message: err.message },
      metadata: { command }
    });

    return {
      ok: false,
      error: err.message,
      command
    };
  }
}
