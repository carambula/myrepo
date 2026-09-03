ALTER TABLE admin_audit
  ADD COLUMN IF NOT EXISTS before_state JSONB;

ALTER TABLE admin_audit
  ADD COLUMN IF NOT EXISTS after_state JSONB;

CREATE TABLE IF NOT EXISTS catalog_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app TEXT NOT NULL CHECK (app IN ('watchedit', 'podlink')),
  label TEXT,
  trigger TEXT NOT NULL,
  actor TEXT NOT NULL,
  revision BIGINT,
  movie_count INT NOT NULL DEFAULT 0,
  source_count INT NOT NULL DEFAULT 0,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS catalog_snapshots_app_idx
  ON catalog_snapshots (app, created_at DESC);
