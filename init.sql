CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE jarvis_logs (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source_brain  TEXT NOT NULL DEFAULT 'JARVIS' CHECK (source_brain IN ('JARVIS','VISION')),
  agent_id      TEXT NOT NULL,
  agent_role    TEXT NOT NULL,
  model_used    TEXT,
  action_type   TEXT NOT NULL,
  autonomy      TEXT NOT NULL CHECK (autonomy IN ('N1','N2','N3','N4')),
  input_summary TEXT,
  output_summary TEXT,
  tokens_in     INTEGER DEFAULT 0,
  tokens_out    INTEGER DEFAULT 0,
  cost_usd      NUMERIC(10,6) DEFAULT 0,
  duration_ms   INTEGER DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'SUCCESS',
  human_approved BOOLEAN,
  parent_task_id UUID REFERENCES jarvis_logs(id),
  error_detail  JSONB,
  metadata      JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_logs_created ON jarvis_logs(created_at DESC);
CREATE INDEX idx_logs_agent ON jarvis_logs(agent_id, created_at DESC);
CREATE INDEX idx_logs_status ON jarvis_logs(status) WHERE status != 'SUCCESS';
CREATE INDEX idx_logs_brain ON jarvis_logs(source_brain, created_at DESC);

CREATE TABLE agent_registry (
  id            TEXT PRIMARY KEY,
  display_name  TEXT NOT NULL,
  role          TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'ACTIVE',
  model_primary TEXT,
  model_fallback TEXT,
  last_execution TIMESTAMPTZ,
  total_executions INTEGER DEFAULT 0,
  total_cost_usd NUMERIC(10,4) DEFAULT 0,
  config        JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE pending_decisions (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  agent_id      TEXT NOT NULL,
  autonomy      TEXT NOT NULL,
  description   TEXT NOT NULL,
  options       JSONB NOT NULL DEFAULT '[]'::jsonb,
  recommendation TEXT,
  status        TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','DENIED','EXPIRED')),
  resolved_at   TIMESTAMPTZ,
  resolved_by   TEXT
);

INSERT INTO agent_registry (id, display_name, role, model_primary, model_fallback, status) VALUES
  ('sentinel', 'Sentinel', 'GUARDIAN', 'groq/llama-3.3-70b-versatile', 'ollama/llama3.2:8b', 'ACTIVE');
