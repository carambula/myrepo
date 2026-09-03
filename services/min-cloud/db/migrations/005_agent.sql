CREATE TABLE IF NOT EXISTS agent_connections (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  scopes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS agent_connections_user_idx ON agent_connections (user_id);

CREATE TABLE IF NOT EXISTS agent_undo (
  id TEXT PRIMARY KEY,
  connection_id TEXT NOT NULL REFERENCES agent_connections(id) ON DELETE CASCADE,
  tool TEXT NOT NULL,
  app TEXT,
  before JSONB NOT NULL DEFAULT '{}'::jsonb,
  after JSONB NOT NULL DEFAULT '{}'::jsonb,
  summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  undone_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS agent_undo_connection_idx ON agent_undo (connection_id, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_audit (
  id TEXT PRIMARY KEY,
  connection_id TEXT NOT NULL,
  connection_name TEXT,
  tool TEXT NOT NULL,
  app TEXT,
  input JSONB NOT NULL DEFAULT '{}'::jsonb,
  ok BOOLEAN NOT NULL,
  error TEXT,
  undo_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS agent_audit_connection_idx ON agent_audit (connection_id, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_user_state (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  listening_history JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
