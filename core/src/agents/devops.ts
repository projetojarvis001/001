import { exec } from 'child_process';
import { readFileSync } from 'fs';
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
  'docker compose ps',
  'git commit',
  'git push'
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

  const normalizedApprovedCommand = command.trim().toLowerCase();

  const approvedAllowed = APPROVED_EXECUTION_COMMANDS.some((allowed) => {
    const normalizedAllowed = allowed.toLowerCase();
    return (
      normalizedApprovedCommand === normalizedAllowed ||
      normalizedApprovedCommand.startsWith(normalizedAllowed + ' ')
    );
  });

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

  if (normalizedApprovedCommand.startsWith('git push')) {
    try {
      const { stdout: remoteStdout } = await execAsync('git remote', {
        cwd: '/host_jarvis',
        timeout: 5000
      });

      const remotes = remoteStdout
        .split('\n')
        .map((x) => x.trim())
        .filter(Boolean);

      if (!remotes.includes('origin')) {
        return {
          ok: false,
          error: 'Remote origin não configurado',
          decision_id: decisionId,
          command
        };
      }
    } catch (err: any) {
      return {
        ok: false,
        error: `Falha ao validar remote: ${err.message}`,
        decision_id: decisionId,
        command
      };
    }

    try {
      const { stdout: branchStdout } = await execAsync('git branch --show-current', {
        cwd: '/host_jarvis',
        timeout: 5000
      });

      const currentBranch = branchStdout.trim();

      if (currentBranch !== 'main') {
        return {
          ok: false,
          error: `Push permitido apenas na branch main. Atual: ${currentBranch || 'desconhecida'}`,
          decision_id: decisionId,
          command
        };
      }
    } catch (err: any) {
      return {
        ok: false,
        error: `Falha ao validar branch: ${err.message}`,
        decision_id: decisionId,
        command
      };
    }

    try {
      const { stdout: statusStdout } = await execAsync('git status --short', {
        cwd: '/host_jarvis',
        timeout: 5000
      });

      const pending = statusStdout
        .split('\n')
        .map((x) => x.trimEnd())
        .filter(Boolean);

      if (pending.length > 0) {
        return {
          ok: false,
          error: 'Working tree não está limpo para push',
          decision_id: decisionId,
          command,
          pending
        };
      }
    } catch (err: any) {
      return {
        ok: false,
        error: `Falha ao validar working tree: ${err.message}`,
        decision_id: decisionId,
        command
      };
    }
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


async function runRepoStatus() {
  const checks: Record<string, any> = {};

  try {
    const { stdout } = await execAsync('git branch --show-current', {
      cwd: '/host_jarvis',
      timeout: 5000
    });
    checks.branch = stdout.trim();
  } catch (err: any) {
    checks.branch = `ERRO: ${err.message}`;
  }

  try {
    const { stdout } = await execAsync('git status --short', {
      cwd: '/host_jarvis',
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    checks.changed_files = lines;
    checks.staged_count = lines.filter((line) => line[0] && line[0] !== '?').length;
    checks.untracked_count = lines.filter((line) => line.startsWith('??')).length;
    checks.clean = lines.length === 0;
  } catch (err: any) {
    checks.changed_files = [`ERRO: ${err.message}`];
    checks.clean = false;
  }

  try {
    const { stdout } = await execAsync('git log --oneline -n 5', {
      cwd: '/host_jarvis',
      timeout: 5000
    });
    checks.last_commits = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);
  } catch (err: any) {
    checks.last_commits = [`ERRO: ${err.message}`];
  }

  await log('Repo status executado com sucesso', 'SUCCESS', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_REPO_STATUS',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(checks).slice(0, 500),
    metadata: checks
  });

  return {
    ok: true,
    command: 'repo status',
    repo: checks
  };
}


async function runRepoLastCommits() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync('git log --oneline -n 10', {
      cwd: '/host_jarvis',
      timeout: 5000
    });

    result.commits = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);
  } catch (err: any) {
    result.commits = [`ERRO: ${err.message}`];
  }

  await log('Repo last commits executado com sucesso', 'SUCCESS', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_REPO_LAST_COMMITS',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: 'repo last commits',
    repo: result
  };
}


async function runRepoPending() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync('git status --short', {
      cwd: '/host_jarvis',
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.items = lines;
    result.total = lines.length;
    result.staged = lines.filter((line) => line[0] && line[0] !== '?').length;
    result.untracked = lines.filter((line) => line.startsWith('??')).length;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.items = [`ERRO: ${err.message}`];
    result.total = 0;
    result.staged = 0;
    result.untracked = 0;
    result.clean = false;
  }

  await log('Repo pending executado com sucesso', 'SUCCESS', {
    source_brain: 'JARVIS',
    agent_id: 'devops',
    agent_role: 'DEVOPS',
    action_type: 'DEVOPS_REPO_PENDING',
    autonomy: 'N1',
    status: 'SUCCESS',
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: 'repo pending',
    repo: result
  };
}






















async function runCommitChangesExecute() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git diff --cached --name-only", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.staged_files = lines;
    result.staged_count = lines.length;
    result.has_staged = lines.length > 0;
  } catch (err: any) {
    result.staged_files = [];
    result.staged_count = 0;
    result.has_staged = false;
    result.error = err.message;
  }

  if (!result.has_staged) {
    result.next_step = "nenhum commit necessario";

    await log("Commit changes execute sem staged files", "SUCCESS", {
      source_brain: "JARVIS",
      agent_id: "devops",
      agent_role: "DEVOPS",
      action_type: "DEVOPS_COMMIT_CHANGES_EXECUTE",
      autonomy: "N1",
      status: "SUCCESS",
      output_summary: JSON.stringify(result).slice(0, 500),
      metadata: result
    });

    return {
      ok: true,
      command: "commit changes execute",
      commit: result
    };
  }

  result.suggested_message = "atualiza comandos e playbooks operacionais do devops";

  const approval = await createPendingDecision(`git commit -m "${result.suggested_message}"`);

  result.next_step = "aguardando aprovacao para git commit";
  result.approval_required = true;
  result.approval = approval.decision || null;

  await log("Commit changes execute solicitou aprovacao", "INFO", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_COMMIT_CHANGES_EXECUTE",
    autonomy: "N2",
    status: "PENDING",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: false,
    command: "commit changes execute",
    commit: result
  };
}

async function runCommitChangesPlan() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git diff --cached --name-only", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.staged_files = lines;
    result.staged_count = lines.length;
    result.has_staged = lines.length > 0;
  } catch (err: any) {
    result.staged_files = [];
    result.staged_count = 0;
    result.has_staged = false;
    result.error = err.message;
  }

  if (result.has_staged) {
    result.suggested_message = "atualiza comandos e playbooks operacionais do devops";
    result.can_request_commit = true;
    result.next_step = "solicitar aprovacao para git commit";
  } else {
    result.suggested_message = null;
    result.can_request_commit = false;
    result.next_step = "nenhum commit necessario";
  }

  await log("Commit changes plan executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_COMMIT_CHANGES_PLAN",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "commit changes plan",
    commit: result
  };
}

async function runStageChangesExecute() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.pending_count = lines.length;
    result.has_pending = lines.length > 0;
  } catch (err: any) {
    result.pending = [];
    result.pending_count = 0;
    result.has_pending = false;
    result.error = err.message;
  }

  if (!result.has_pending) {
    result.next_step = "nenhum staging necessario";

    await log("Stage changes execute sem pendencias", "SUCCESS", {
      source_brain: "JARVIS",
      agent_id: "devops",
      agent_role: "DEVOPS",
      action_type: "DEVOPS_STAGE_CHANGES_EXECUTE",
      autonomy: "N1",
      status: "SUCCESS",
      output_summary: JSON.stringify(result).slice(0, 500),
      metadata: result
    });

    return {
      ok: true,
      command: "stage changes execute",
      stage: result
    };
  }

  const approval = await createPendingDecision("git add .");

  result.next_step = "aguardando aprovacao para git add .";
  result.approval_required = true;
  result.approval = approval.decision || null;

  await log("Stage changes execute solicitou aprovacao", "INFO", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_STAGE_CHANGES_EXECUTE",
    autonomy: "N2",
    status: "PENDING",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: false,
    command: "stage changes execute",
    stage: result
  };
}




async function runWorkingTreeFixPlan() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.items = lines;
    result.total = lines.length;
    result.staged = lines.filter((line) => line.length >= 2 && line[0] !== ' ' && line[0] !== '?').length;
    result.unstaged = lines.filter((line) => line.length >= 2 && line[1] !== ' ').length;
    result.untracked = lines.filter((line) => line.startsWith("??")).length;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.items = [];
    result.total = 0;
    result.staged = 0;
    result.unstaged = 0;
    result.untracked = 0;
    result.clean = false;
    result.error = err.message;
  }

  result.needs_stage = result.unstaged > 0 || result.untracked > 0;
  result.needs_commit = result.staged > 0 || result.needs_stage;

  if (result.clean) {
    result.next_step = "repositorio limpo; pode seguir para revalidacao de push";
  } else if (result.needs_stage) {
    result.next_step = "executar novo stage changes plan/execution e depois novo commit";
  } else if (result.staged > 0) {
    result.next_step = "executar commit changes plan/execution";
  } else {
    result.next_step = "revisar manualmente o working tree";
  }

  await log("Working tree fix plan executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_WORKING_TREE_FIX_PLAN",
    autonomy: "N1",
    status: result.clean ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "working tree fix plan",
    tree: result
  };
}

async function runWorkingTreeDoctor() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.items = lines;
    result.total = lines.length;
    result.staged = lines.filter((line) => line.length >= 2 && line[0] !== ' ' && line[0] !== '?').length;
    result.unstaged = lines.filter((line) => line.length >= 2 && line[1] !== ' ').length;
    result.untracked = lines.filter((line) => line.startsWith("??")).length;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.items = [];
    result.total = 0;
    result.staged = 0;
    result.unstaged = 0;
    result.untracked = 0;
    result.clean = false;
    result.error = err.message;
  }

  if (result.clean) {
    result.next_step = "working tree limpo";
  } else if (result.unstaged > 0) {
    result.next_step = "revisar e decidir se faz novo staging ou commit";
  } else if (result.staged > 0) {
    result.next_step = "avaliar commit ou restauracao";
  } else {
    result.next_step = "revisar estado do working tree";
  }

  await log("Working tree doctor executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_WORKING_TREE_DOCTOR",
    autonomy: "N1",
    status: result.clean ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "working tree doctor",
    tree: result
  };
}




async function runPushRequest() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_origin = lines.some((line) => line.startsWith("origin"));
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.pending = [];
    result.clean = false;
    result.status_error = err.message;
  }

  result.can_request_push = !!(
    result.branch &&
    result.upstream &&
    result.has_origin &&
    result.clean
  );

  if (!result.can_request_push) {
    result.next_step = "repositorio ainda nao pode solicitar push";

    await log("Push request bloqueado por pre-condicoes", "SUCCESS", {
      source_brain: "JARVIS",
      agent_id: "devops",
      agent_role: "DEVOPS",
      action_type: "DEVOPS_PUSH_REQUEST",
      autonomy: "N1",
      status: "ERROR",
      output_summary: JSON.stringify(result).slice(0, 500),
      metadata: result
    });

    return {
      ok: false,
      command: "push request",
      push: result
    };
  }

  const approval = await createPendingDecision("git push");

  result.next_step = "aguardando aprovacao para git push";
  result.approval_required = true;
  result.approval = approval.decision || null;

  await log("Push request solicitou aprovacao", "INFO", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_PUSH_REQUEST",
    autonomy: "N2",
    status: "PENDING",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: false,
    command: "push request",
    push: result
  };
}

async function runPushReadinessRecheck() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_origin = lines.some((line) => line.startsWith("origin"));
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.pending = [];
    result.clean = false;
    result.status_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  result.can_request_push = !!(
    result.branch &&
    result.upstream &&
    result.has_origin &&
    result.clean &&
    result.last_commit
  );

  if (result.can_request_push) {
    result.next_step = "solicitar aprovacao para git push";
  } else if (!result.clean) {
    result.next_step = "limpar working tree antes do push";
  } else if (!result.upstream) {
    result.next_step = "configurar upstream da branch";
  } else if (!result.has_origin) {
    result.next_step = "configurar remote origin";
  } else {
    result.next_step = "revisar estado final do repositorio";
  }

  await log("Push readiness recheck executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_PUSH_READINESS_RECHECK",
    autonomy: "N1",
    status: result.can_request_push ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "push readiness recheck",
    push: result
  };
}

async function runStageChangesPlan() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.pending_count = lines.length;
    result.has_pending = lines.length > 0;
  } catch (err: any) {
    result.pending = [];
    result.pending_count = 0;
    result.has_pending = false;
    result.error = err.message;
  }

  result.can_stage = !!result.has_pending;

  if (result.can_stage) {
    result.next_step = "solicitar git add pelo fluxo controlado";
  } else {
    result.next_step = "nenhum staging necessario";
  }

  await log("Stage changes plan executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_STAGE_CHANGES_PLAN",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "stage changes plan",
    repo: result
  };
}

async function runExecutionReadiness() {
  const result: Record<string, any> = {
    has_prepare_repo: false,
    has_commit_plan: false,
    has_commit_message: false,
    has_repo_ready: false,
    has_safe_push_plan: false
  };

  let code = "";

  try {
    code = readFileSync("/host_jarvis/core/src/agents/devops.ts", "utf-8");
  } catch (err: any) {
    result.error = err.message;

    await log("Execution readiness executado com erro de leitura", "ERROR", {
      source_brain: "JARVIS",
      agent_id: "devops",
      agent_role: "DEVOPS",
      action_type: "DEVOPS_EXECUTION_READINESS",
      autonomy: "N1",
      status: "ERROR",
      output_summary: JSON.stringify(result).slice(0, 500),
      metadata: result
    });

    return {
      ok: false,
      command: "execution readiness",
      readiness: result
    };
  }

  result.has_prepare_repo = code.includes("runPrepareRepo()");
  result.has_commit_plan = code.includes("runRepoCommitPlan()");
  result.has_commit_message = code.includes("runRepoCommitMessage()");
  result.has_repo_ready = code.includes("runRepoReady()");
  result.has_safe_push_plan = code.includes("runSafePushPlan()");

  result.execution_readiness = !!(
    result.has_prepare_repo &&
    result.has_commit_plan &&
    result.has_commit_message &&
    result.has_repo_ready &&
    result.has_safe_push_plan
  );

  result.next_step = result.execution_readiness
    ? "playbook base pronto para execucao guiada"
    : "completar playbooks faltantes";

  await log("Execution readiness executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_EXECUTION_READINESS",
    autonomy: "N1",
    status: result.execution_readiness ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "execution readiness",
    readiness: result
  };
}

async function runSafePushPlan() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_origin = lines.some((line) => line.startsWith("origin"));
    result.remote_lines = lines;
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.pending = [];
    result.clean = false;
    result.status_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_diff = lines.length > 0;
    result.diff_stat = lines;

    const fileLines = lines.filter((line) => line.includes('|'));
    result.changed_files_count = fileLines.length;
  } catch (err: any) {
    result.has_diff = false;
    result.diff_stat = [];
    result.changed_files_count = 0;
    result.diff_error = err.message;
  }

  result.ready_for_push = !!(
    result.branch &&
    result.upstream &&
    result.has_origin &&
    result.clean
  );

  if (result.ready_for_push) {
    result.suggested_message = null;
    result.next_step = "push permitido";
  } else if (result.has_diff) {
    result.suggested_message = "atualiza comandos e playbooks operacionais do devops";
    result.next_step = "executar git add, git commit e depois revisar push";
  } else if (!result.has_origin) {
    result.suggested_message = null;
    result.next_step = "configurar remote origin";
  } else if (!result.upstream) {
    result.suggested_message = null;
    result.next_step = "configurar upstream da branch";
  } else {
    result.suggested_message = null;
    result.next_step = "revisar estado do repositorio";
  }

  await log("Safe push plan executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_SAFE_PUSH_PLAN",
    autonomy: "N1",
    status: result.ready_for_push ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "safe push plan",
    repo: result
  };
}

async function runRepoCommitMessage() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.diff_stat = lines;
    result.has_diff = lines.length > 0;

    const fileLines = lines.filter((line) => line.includes('|'));
    result.changed_files_count = fileLines.length;

    if (result.has_diff) {
      result.suggested_message = "atualiza comandos e playbooks operacionais do devops";
      result.next_step = "revisar mensagem e executar git add/git commit";
    } else {
      result.suggested_message = null;
      result.next_step = "nenhum commit necessario";
    }
  } catch (err: any) {
    result.has_diff = false;
    result.changed_files_count = 0;
    result.suggested_message = null;
    result.error = err.message;
    result.next_step = "revisar estado do repositorio";
  }

  await log("Repo commit message executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_COMMIT_MESSAGE",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo commit message",
    repo: result
  };
}

async function runRepoCommitPlan() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.pending_count = lines.length;
    result.has_pending = lines.length > 0;
  } catch (err: any) {
    result.pending = [];
    result.pending_count = 0;
    result.has_pending = false;
    result.status_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.diff_stat = lines;
    result.has_diff = lines.length > 0;
  } catch (err: any) {
    result.diff_stat = [];
    result.has_diff = false;
    result.diff_error = err.message;
  }

  result.ready_to_commit = !!result.has_pending;

  if (result.ready_to_commit) {
    result.next_step = "revisar diff e definir mensagem de commit";
  } else {
    result.next_step = "nenhum commit necessario";
  }

  await log("Repo commit plan executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_COMMIT_PLAN",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo commit plan",
    repo: result
  };
}

async function runPrepareRepo() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_origin = lines.some((line) => line.startsWith("origin"));
    result.remote_lines = lines;
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_diff = lines.length > 0;
    result.diff_stat = lines;
  } catch (err: any) {
    result.has_diff = false;
    result.diff_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.pending = [];
    result.clean = false;
    result.status_error = err.message;
  }

  result.ready_for_push = !!(
    result.branch &&
    result.upstream &&
    result.has_origin &&
    result.clean
  );

  if (result.ready_for_push) {
    result.next_step = "push permitido";
  } else if (result.has_diff && result.clean === false) {
    result.next_step = "revisar diff e commitar antes do push";
  } else if (!result.has_origin) {
    result.next_step = "configurar remote origin";
  } else if (!result.upstream) {
    result.next_step = "configurar upstream da branch";
  } else {
    result.next_step = "revisar estado do repositorio";
  }

  await log("Prepare repo executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_PREPARE_REPO",
    autonomy: "N1",
    status: result.ready_for_push ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "prepare repo",
    repo: result
  };
}

async function runRepoReady() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_origin = lines.some((line) => line.startsWith("origin"));
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.pending = lines;
    result.clean = lines.length === 0;
  } catch (err: any) {
    result.pending = [];
    result.clean = false;
    result.status_error = err.message;
  }

  result.ready_for_push = !!(
    result.branch &&
    result.upstream &&
    result.has_origin &&
    result.clean
  );

  await log("Repo ready executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_READY",
    autonomy: "N1",
    status: result.ready_for_push ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo ready",
    repo: result
  };
}

async function runRepoDoctor() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.branch_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.remote_lines = lines;
    result.has_origin = lines.some((line) => line.startsWith("origin"));
  } catch (err: any) {
    result.has_origin = false;
    result.remote_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_diff = lines.length > 0;
    result.diff_stat = lines;
  } catch (err: any) {
    result.has_diff = false;
    result.diff_error = err.message;
  }

  result.repo_ok = !!(result.branch && result.has_origin);

  await log("Repo doctor executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_DOCTOR",
    autonomy: "N1",
    status: result.repo_ok ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo doctor",
    repo: result
  };
}

async function runRepoDiff() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git diff --stat", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.has_diff = lines.length > 0;
    result.diff_stat = lines;
  } catch (err: any) {
    result.has_diff = false;
    result.error = err.message;
  }

  await log("Repo diff executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_DIFF",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo diff",
    repo: result
  };
}

async function runRepoRemote() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git remote -v", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    result.raw = lines;

    const fetchLine = lines.find((line) => line.startsWith("origin") && line.includes("(fetch)"));
    const pushLine = lines.find((line) => line.startsWith("origin") && line.includes("(push)"));

    result.fetch = fetchLine || null;
    result.push = pushLine || null;
    result.has_origin = !!(fetchLine || pushLine);
  } catch (err: any) {
    result.has_origin = false;
    result.error = err.message;
  }

  await log("Repo remote executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_REMOTE",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo remote",
    repo: result
  };
}

async function runRepoBranch() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git branch --show-current", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.branch = stdout.trim();
  } catch (err: any) {
    result.branch = null;
    result.error = err.message;
  }

  try {
    const { stdout } = await execAsync("git rev-parse --abbrev-ref --symbolic-full-name @{u}", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.upstream = stdout.trim();
  } catch (_err: any) {
    result.upstream = null;
  }

  await log("Repo branch executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_REPO_BRANCH",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "repo branch",
    repo: result
  };
}



async function queryOne(sql: string) {
  const res = await pool.query(sql);
  return res.rows?.[0] || null;
}









async function runExecutiveCockpit() {
  const result: Record<string, any> = {};

  try {
    const goal = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_GOAL_EXECUTION'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_goal_execution = goal || null;
  } catch (err: any) {
    result.last_goal_execution = null;
    result.last_goal_execution_error = err.message;
  }

  try {
    const orchestration = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MULTIAGENT_ORCHESTRATION'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_orchestration = orchestration || null;
  } catch (err: any) {
    result.last_orchestration = null;
    result.last_orchestration_error = err.message;
  }

  try {
    const push = await queryOne(`
      SELECT id, created_at, status, resolved_at, resolved_by, description
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'APPROVED'
        AND description ILIKE '%git push%'
      ORDER BY resolved_at DESC NULLS LAST, created_at DESC
      LIMIT 1
    `);
    result.last_push = push || null;
  } catch (err: any) {
    result.last_push = null;
    result.last_push_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    const lines = stdout.split('\n').map(x => x.trimEnd()).filter(Boolean);
    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  result.current_phase = "Fase 18";
  result.open_approvals = result.pending_decisions ?? 0;

  result.executive_status = (result.repo_clean && result.open_approvals === 0)
    ? "GREEN"
    : "YELLOW";

  result.program_status = {
    repository: result.repo_clean ? "OK" : "PENDENTE",
    approvals: result.open_approvals === 0 ? "OK" : "PENDENTE",
    orchestration: "ATIVA",
    execution: "ATIVA"
  };

  result.recommended_agent = result.executive_status === "GREEN"
    ? "dispatcher"
    : "devops";

  result.next_executive_command = result.executive_status === "GREEN"
    ? "iniciar cockpit de despacho executivo"
    : "limpar pendencias antes do cockpit executivo final";

  await log("Executive cockpit executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_EXECUTIVE_COCKPIT",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "executive cockpit",
    cockpit: result
  };
}

async function runGoalExecution() {
  const result: Record<string, any> = {};

  try {
    const orchestration = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MULTIAGENT_ORCHESTRATION'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_orchestration = orchestration || null;
  } catch (err: any) {
    result.last_orchestration = null;
    result.last_orchestration_error = err.message;
  }

  try {
    const memory = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MEMORY_BOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_memory_board = memory || null;
  } catch (err: any) {
    result.last_memory_board = null;
    result.last_memory_board_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    const lines = stdout.split('\n').map(x => x.trimEnd()).filter(Boolean);
    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  result.current_phase = "Fase 17";
  result.active_goal = "goal execution";
  result.goal_owner = "devops";
  result.goal_status = (result.repo_clean && (result.pending_decisions ?? 0) === 0)
    ? "READY"
    : "ATTENTION";

  result.dependencies = [
    "multiagent orchestration",
    "memory board",
    "execution dashboard"
  ];

  result.blockers = [];
  if (!result.repo_clean) {
    result.blockers.push("repositorio com pendencias locais");
  }
  if ((result.pending_decisions ?? 0) > 0) {
    result.blockers.push("existem aprovacoes pendentes");
  }

  result.next_recommended_command = result.goal_status === "READY"
    ? "definir objetivo operacional e proximo agente executor"
    : "limpar pendencias antes de iniciar goal execution";

  await log("Goal execution executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_GOAL_EXECUTION",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "goal execution",
    goal: result
  };
}

async function runMultiagentOrchestration() {
  const result: Record<string, any> = {};

  try {
    const missionBoard = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_BOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mission_board = missionBoard || null;
  } catch (err: any) {
    result.last_mission_board = null;
    result.last_mission_board_error = err.message;
  }

  try {
    const memoryBoard = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MEMORY_BOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_memory_board = memoryBoard || null;
  } catch (err: any) {
    result.last_memory_board = null;
    result.last_memory_board_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    const lines = stdout.split('\n').map(x => x.trimEnd()).filter(Boolean);
    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  result.current_phase = "Fase 16";
  result.active_mission = "multiagent orchestration";
  result.lead_agent = "devops";
  result.available_agents = ["devops", "dispatcher", "sentinel", "vision"];

  result.orchestration_state = result.repo_clean ? "SYNCED" : "DIRTY";
  result.shared_context_status = result.repo_clean ? "AVAILABLE" : "PENDING_UPDATE";
  result.handoff_queue = [
    "devops -> dispatcher",
    "dispatcher -> sentinel",
    "sentinel -> vision"
  ];
  result.last_handoff = "devops -> proxima camada de coordenacao";

  result.coordination_status = (result.repo_clean && (result.pending_decisions ?? 0) === 0)
    ? "READY"
    : "ATTENTION";

  result.next_recommended_agent = result.coordination_status === "READY"
    ? "dispatcher"
    : "devops";

  result.next_step = result.coordination_status === "READY"
    ? "estruturar handoff e estado compartilhado entre agentes"
    : "limpar pendencias antes da orquestracao";

  result.mission_contract = {
    owner: "devops",
    next_owner: result.next_recommended_agent,
    shared_state_required: true,
    approval_gate_required: true
  };

  await log("Multiagent orchestration executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MULTIAGENT_ORCHESTRATION",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "multiagent orchestration",
    orchestration: result
  };
}

async function runMemoryBoard() {
  const result: Record<string, any> = {};

  try {
    const lastCommit = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = lastCommit.stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  try {
    const lastPush = await queryOne(`
      SELECT id, created_at, status, resolved_at, resolved_by, description
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'APPROVED'
        AND description ILIKE '%git push%'
      ORDER BY resolved_at DESC NULLS LAST, created_at DESC
      LIMIT 1
    `);
    result.last_push = lastPush || null;
  } catch (err: any) {
    result.last_push = null;
    result.last_push_error = err.message;
  }

  try {
    const dashboard = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_EXECUTION_DASHBOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_dashboard = dashboard || null;
  } catch (err: any) {
    result.last_dashboard = null;
    result.last_dashboard_error = err.message;
  }

  try {
    const missionBoard = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_BOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mission_board = missionBoard || null;
  } catch (err: any) {
    result.last_mission_board = null;
    result.last_mission_board_error = err.message;
  }

  try {
    const recentSummary = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_SUMMARY'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mission_summary = recentSummary || null;
  } catch (err: any) {
    result.last_mission_summary = null;
    result.last_mission_summary_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const lastMissionClose = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_CLOSE'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mission_close = lastMissionClose || null;
  } catch (err: any) {
    result.last_mission_close = null;
    result.last_mission_close_error = err.message;
  }

  try {
    const lastPriorities = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_NEXT_PRIORITIES'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_priorities = lastPriorities || null;
  } catch (err: any) {
    result.last_priorities = null;
    result.last_priorities_error = err.message;
  }

  result.last_known_phase = "Fase 15";
  result.memory_status = result.repo_clean ? "STABLE" : "DIRTY";
  result.resume_hint = result.repo_clean
    ? "retomar a partir do mission board ou iniciar nova feature"
    : "fechar pendencias locais antes de retomar a proxima missao";

  result.next_recommended_step = result.repo_clean
    ? "seguir para consolidacao avancada da memoria operacional"
    : "limpar pendencias antes da consolidacao da memoria";

  await log("Memory board executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MEMORY_BOARD",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "memory board",
    memory: result
  };
}

async function runMissionBoard() {
  const result: Record<string, any> = {};

  try {
    const dashboard = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_EXECUTION_DASHBOARD'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_dashboard = dashboard || null;
  } catch (err: any) {
    result.last_dashboard = null;
    result.last_dashboard_error = err.message;
  }

  try {
    const priorities = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_NEXT_PRIORITIES'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_priorities = priorities || null;
  } catch (err: any) {
    result.last_priorities = null;
    result.last_priorities_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  result.current_phase = "Fase 14";
  result.current_step = "mission board";
  result.completed_steps = [
    "repositorio preparado",
    "fluxo de stage/commit/push com aprovacao",
    "mission summary",
    "mission close",
    "next priorities",
    "execution dashboard"
  ];

  result.in_progress = (result.repo_clean && (result.pending_decisions ?? 0) === 0)
    ? "mission board consolidado"
    : "limpar pendencias antes de consolidar board";

  result.next_steps = [
    "mission board",
    "memory board",
    "multiagent orchestration"
  ];

  result.blockers = [];
  if (!result.repo_clean) {
    result.blockers.push("repositorio com pendencias locais");
  }
  if ((result.pending_decisions ?? 0) > 0) {
    result.blockers.push("existem aprovacoes pendentes");
  }

  result.overall_status = (result.repo_clean && (result.pending_decisions ?? 0) === 0)
    ? "ON TRACK"
    : "ATTENTION";

  await log("Mission board executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MISSION_BOARD",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "mission board",
    board: result
  };
}

async function runExecutionDashboard() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo = {
      clean: lines.length === 0,
      pending: lines,
      pending_count: lines.length
    };
  } catch (err: any) {
    result.repo = {
      clean: false,
      pending: [],
      pending_count: 0,
      error: err.message
    };
  }

  try {
    const lastCommit = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = lastCommit.stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  try {
    const missionClose = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_CLOSE'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.mission_close = missionClose || null;
  } catch (err: any) {
    result.mission_close = null;
    result.mission_close_error = err.message;
  }

  try {
    const nextPriorities = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_NEXT_PRIORITIES'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.next_priorities = nextPriorities || null;
  } catch (err: any) {
    result.next_priorities = null;
    result.next_priorities_error = err.message;
  }

  try {
    const mesh = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MESH_STATUS'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.mesh_status = mesh || null;
  } catch (err: any) {
    result.mesh_status = null;
    result.mesh_status_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  result.mission_status = result.repo?.clean ? "READY" : "ATTENTION";
  result.recommended_action = result.repo?.clean
    ? "seguir para mission board"
    : "limpar pendencias e concluir ciclo git antes da proxima evolucao";

  await log("Execution dashboard executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_EXECUTION_DASHBOARD",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "execution dashboard",
    dashboard: result
  };
}

async function runNextPriorities() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const lastClose = await queryOne(`
      SELECT created_at, action_type, status, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MISSION_CLOSE'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mission_close = lastClose || null;
  } catch (err: any) {
    result.last_mission_close = null;
    result.last_mission_close_error = err.message;
  }

  try {
    const pending = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'PENDING'
    `);
    result.pending_decisions = pending?.total ?? 0;
  } catch (err: any) {
    result.pending_decisions = 0;
    result.pending_decisions_error = err.message;
  }

  try {
    const mesh = await queryOne(`
      SELECT created_at, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MESH_STATUS'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mesh_status = mesh || null;
  } catch (err: any) {
    result.last_mesh_status = null;
    result.last_mesh_status_error = err.message;
  }

  result.priority_1 = result.repo_clean
    ? "criar dashboard executivo de execucao"
    : "limpar o repositorio antes de nova evolucao";

  result.priority_2 = "criar mission board com status por fase";

  result.priority_3 = "estruturar carga inicial de conhecimento operacional";

  result.blockers = [];
  if (!result.repo_clean) {
    result.blockers.push("repositorio com pendencias locais");
  }
  if ((result.pending_decisions ?? 0) > 0) {
    result.blockers.push("existem aprovacoes pendentes");
  }

  result.recommended_action = result.repo_clean
    ? "seguir para execution dashboard"
    : "executar ciclo de stage, commit e push antes da proxima feature";

  await log("Next priorities executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_NEXT_PRIORITIES",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "next priorities",
    priorities: result
  };
}

async function runMissionClose() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const push = await queryOne(`
      SELECT id, created_at, status, resolved_at, resolved_by, description
      FROM pending_decisions
      WHERE agent_id = 'devops'
        AND status = 'APPROVED'
        AND description ILIKE '%git push%'
      ORDER BY resolved_at DESC NULLS LAST, created_at DESC
      LIMIT 1
    `);
    result.last_successful_push = push || null;
  } catch (err: any) {
    result.last_successful_push = null;
    result.last_push_error = err.message;
  }

  try {
    const mesh = await queryOne(`
      SELECT created_at, input_summary, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MESH_STATUS'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mesh_status = mesh || null;
  } catch (err: any) {
    result.last_mesh_status = null;
    result.last_mesh_status_error = err.message;
  }

  result.final_status = (result.repo_clean && result.last_successful_push)
    ? "DONE"
    : "PARTIAL";

  result.summary = result.final_status === "DONE"
    ? "Missao encerrada com sucesso, push realizado e repositorio limpo."
    : "Missao encerrada parcialmente; revisar pendencias operacionais.";

  await log("Mission close executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MISSION_CLOSE",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "mission close",
    mission: result
  };
}

async function runMissionSummary() {
  const result: Record<string, any> = {};

  try {
    const lastLog = await queryOne(`
      SELECT created_at, action_type, status, input_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_event = lastLog || null;
  } catch (err: any) {
    result.last_event = null;
    result.last_event_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git log --oneline -n 1", {
      cwd: "/host_jarvis",
      timeout: 5000
    });
    result.last_commit = stdout.trim() || null;
  } catch (err: any) {
    result.last_commit = null;
    result.last_commit_error = err.message;
  }

  try {
    const mesh = await queryOne(`
      SELECT created_at, input_summary, output_summary
      FROM jarvis_logs
      WHERE agent_id = 'devops'
        AND action_type = 'DEVOPS_MESH_STATUS'
      ORDER BY created_at DESC
      LIMIT 1
    `);
    result.last_mesh_status = mesh || null;
  } catch (err: any) {
    result.last_mesh_status = null;
    result.last_mesh_status_error = err.message;
  }

  try {
    const { stdout } = await execAsync("git status --short", {
      cwd: "/host_jarvis",
      timeout: 5000
    });

    const lines = stdout
      .split('\n')
      .map((x) => x.trimEnd())
      .filter(Boolean);

    result.repo_clean = lines.length === 0;
    result.repo_pending = lines;
  } catch (err: any) {
    result.repo_clean = false;
    result.repo_pending = [];
    result.repo_status_error = err.message;
  }

  try {
    const decisions = await queryOne(`
      SELECT COUNT(*)::int AS total
      FROM pending_decisions
      WHERE agent_id = 'devops'
    `);
    result.recent_decisions_total = decisions?.total ?? 0;
  } catch (err: any) {
    result.recent_decisions_total = 0;
    result.recent_decisions_error = err.message;
  }

  result.summary = result.repo_clean
    ? "Missao operacional concluida com repositorio limpo e push realizado."
    : "Missao avancou, mas ainda existem pendencias no repositorio.";

  await log("Mission summary executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MISSION_SUMMARY",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "mission summary",
    mission: result
  };
}

async function runRecentSummary() {
  const lastEventResult = await pool.query(
    `SELECT created_at, action_type, status, input_summary
     FROM jarvis_logs
     WHERE agent_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    ['devops']
  );

  const recentLogsResult = await pool.query(
    `SELECT created_at, action_type, status, input_summary
     FROM jarvis_logs
     WHERE agent_id = $1
     ORDER BY created_at DESC
     LIMIT 10`,
    ['devops']
  );

  const recentDecisionsResult = await pool.query(
    `SELECT id, created_at, status, description
     FROM pending_decisions
     ORDER BY created_at DESC
     LIMIT 10`
  );

  const lastMeshResult = await pool.query(
    `SELECT created_at, input_summary, output_summary
     FROM jarvis_logs
     WHERE agent_id = $1
       AND action_type = $2
     ORDER BY created_at DESC
     LIMIT 1`,
    ['devops', 'DEVOPS_MESH_STATUS']
  );

  const summary = {
    last_event: lastEventResult.rows[0] || null,
    recent_logs_count: recentLogsResult.rows.length,
    recent_decisions_count: recentDecisionsResult.rows.length,
    last_mesh_status: lastMeshResult.rows[0] || null
  };

  await log("Recent summary executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_RECENT_SUMMARY",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(summary).slice(0, 500),
    metadata: summary
  });

  return {
    ok: true,
    command: "recent summary",
    summary
  };
}

async function runRecentDecisions() {
  const result = await pool.query(
    `SELECT id, created_at, agent_id, autonomy, description, recommendation, status, resolved_at, resolved_by
     FROM pending_decisions
     ORDER BY created_at DESC
     LIMIT 10`
  );

  await log("Recent decisions executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_RECENT_DECISIONS",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result.rows).slice(0, 500),
    metadata: { total: result.rows.length }
  });

  return {
    ok: true,
    command: "recent decisions",
    decisions: result.rows
  };
}

async function runLastMission() {
  const result = await pool.query(
    `SELECT created_at, action_type, status, input_summary
     FROM jarvis_logs
     WHERE agent_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    ['devops']
  );

  const row = result.rows[0] || null;

  await log("Last mission executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_LAST_MISSION",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(row).slice(0, 500),
    metadata: { found: !!row }
  });

  return {
    ok: true,
    command: "last mission",
    mission: row
  };
}

async function runRecentLogs() {
  const result = await pool.query(
    `SELECT created_at, action_type, status, input_summary
     FROM jarvis_logs
     WHERE agent_id = $1
     ORDER BY created_at DESC
     LIMIT 10`,
    ['devops']
  );

  await log("Recent logs executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_RECENT_LOGS",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result.rows).slice(0, 500),
    metadata: { total: result.rows.length }
  });

  return {
    ok: true,
    command: "recent logs",
    logs: result.rows
  };
}

async function runMeshStatus() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("wget -qO- http://localhost:3000/health", {
      cwd: "/app",
      timeout: 5000
    });
    result.core = JSON.parse(stdout);
  } catch (err: any) {
    result.core = { ok: false, error: err.message };
  }

  const visionHost = process.env.VISION_HOST || '';
  result.vision_host = visionHost || null;

  if (!visionHost) {
    result.vision = { ok: false, error: "VISION_HOST não configurado" };
  } else {
    try {
      const { stdout } = await execAsync(`wget -qO- http://${visionHost}:5005/health`, {
        cwd: "/app",
        timeout: 5000
      });
      result.vision = JSON.parse(stdout);
    } catch (err: any) {
      result.vision = { ok: false, error: err.message };
    }
  }

  result.mesh_ok = !!(result.core?.ok && result.vision?.ok);

  await log("Mesh status executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_MESH_STATUS",
    autonomy: "N1",
    status: result.mesh_ok ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "mesh status",
    mesh: result
  };
}

async function runVisionHealth() {
  const visionHost = process.env.VISION_HOST || '';
  const baseUrl = visionHost ? `http://${visionHost}:5005/health` : '';

  const result: Record<string, any> = {
    host: visionHost || null
  };

  if (!visionHost) {
    result.ok = false;
    result.error = 'VISION_HOST não configurado';

    await log("Vision health executado sem VISION_HOST", "ERROR", {
      source_brain: "JARVIS",
      agent_id: "devops",
      agent_role: "DEVOPS",
      action_type: "DEVOPS_VISION_HEALTH",
      autonomy: "N1",
      status: "ERROR",
      output_summary: JSON.stringify(result).slice(0, 500),
      metadata: result
    });

    return {
      ok: false,
      command: "vision health",
      vision: result
    };
  }

  try {
    const { stdout } = await execAsync(`wget -qO- ${baseUrl}`, {
      cwd: "/app",
      timeout: 5000
    });

    const payload = JSON.parse(stdout);
    result.ok = !!payload.ok;
    result.response = payload;
  } catch (err: any) {
    result.ok = false;
    result.error = err.message;
  }

  await log("Vision health executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_VISION_HEALTH",
    autonomy: "N1",
    status: result.ok ? "SUCCESS" : "ERROR",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: !!result.ok,
    command: "vision health",
    vision: result
  };
}

async function runStackHealth() {
  const result: Record<string, any> = {};

  try {
    const { stdout } = await execAsync("wget -qO- http://localhost:3000/health", {
      cwd: "/app",
      timeout: 5000
    });
    result.core = JSON.parse(stdout);
  } catch (err: any) {
    result.core = { ok: false, error: err.message };
  }

  try {
    const { stdout } = await execAsync("pg_isready -h postgres -U jarvis_admin -d jarvis_db", {
      cwd: "/app",
      timeout: 5000
    });
    result.postgres = { ok: stdout.includes("accepting connections"), output: stdout.trim() };
  } catch (err: any) {
    result.postgres = { ok: false, error: err.message };
  }

  try {
    const { stdout } = await execAsync("redis-cli -h redis -a 'W!@#wps@2026' ping", {
      cwd: "/app",
      timeout: 5000
    });
    result.redis = { ok: stdout.trim() == "PONG", output: stdout.trim() };
  } catch (err: any) {
    result.redis = { ok: false, error: err.message };
  }

  await log("Stack health executado com sucesso", "SUCCESS", {
    source_brain: "JARVIS",
    agent_id: "devops",
    agent_role: "DEVOPS",
    action_type: "DEVOPS_STACK_HEALTH",
    autonomy: "N1",
    status: "SUCCESS",
    output_summary: JSON.stringify(result).slice(0, 500),
    metadata: result
  });

  return {
    ok: true,
    command: "stack health",
    stack: result
  };
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

  if (normalized === 'repo status') {
    return await runRepoStatus();
  }

  if (normalized === 'repo last commits') {
    return await runRepoLastCommits();
  }

  if (normalized === 'repo pending') {
    return await runRepoPending();
  }

  if (normalized === 'stack health') {
    return await runStackHealth();
  }

  if (normalized === 'vision health') {
    return await runVisionHealth();
  }

  if (normalized === 'mesh status') {
    return await runMeshStatus();
  }

  if (normalized === 'recent logs') {
    return await runRecentLogs();
  }

  if (normalized === 'last mission') {
    return await runLastMission();
  }

  if (normalized === 'recent decisions') {
    return await runRecentDecisions();
  }

  if (normalized === 'recent summary') {
    return await runRecentSummary();
  }

  if (normalized === 'mission summary') {
    return await runMissionSummary();
  }

  if (normalized === 'mission close') {
    return await runMissionClose();
  }

  if (normalized === 'next priorities') {
    return await runNextPriorities();
  }

  if (normalized === 'execution dashboard') {
    return await runExecutionDashboard();
  }

  if (normalized === 'mission board') {
    return await runMissionBoard();
  }

  if (normalized === 'memory board') {
    return await runMemoryBoard();
  }

  if (normalized === 'multiagent orchestration') {
    return await runMultiagentOrchestration();
  }

  if (normalized === 'goal execution') {
    return await runGoalExecution();
  }

  if (normalized === 'executive cockpit') {
    return await runExecutiveCockpit();
  }

  if (normalized === 'repo branch') {
    return await runRepoBranch();
  }

  if (normalized === 'repo remote') {
    return await runRepoRemote();
  }

  if (normalized === 'repo diff') {
    return await runRepoDiff();
  }

  if (normalized === 'repo doctor') {
    return await runRepoDoctor();
  }

  if (normalized === 'repo ready') {
    return await runRepoReady();
  }

  if (normalized === 'prepare repo') {
    return await runPrepareRepo();
  }

  if (normalized === 'repo commit plan') {
    return await runRepoCommitPlan();
  }

  if (normalized === 'repo commit message') {
    return await runRepoCommitMessage();
  }

  if (normalized === 'safe push plan') {
    return await runSafePushPlan();
  }

  if (normalized === 'execution readiness') {
    return await runExecutionReadiness();
  }

  if (normalized === 'stage changes plan') {
    return await runStageChangesPlan();
  }

  if (normalized === 'push readiness recheck') {
    return await runPushReadinessRecheck();
  }

  if (normalized === 'push request') {
    return await runPushRequest();
  }

  if (normalized === 'working tree doctor') {
    return await runWorkingTreeDoctor();
  }

  if (normalized === 'working tree fix plan') {
    return await runWorkingTreeFixPlan();
  }

  if (normalized === 'working tree doctor') {
    return await runWorkingTreeDoctor();
  }

  if (normalized === 'stage changes execute') {
    return await runStageChangesExecute();
  }

  if (normalized === 'commit changes plan') {
    return await runCommitChangesPlan();
  }

  if (normalized === 'commit changes execute') {
    return await runCommitChangesExecute();
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
