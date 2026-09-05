-- In-app bugs and ideas for all min apps. Full report lives here;
-- GitHub issues are a redacted work queue (no email / name).

CREATE TABLE IF NOT EXISTS feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app TEXT NOT NULL CHECK (app IN ('mov', 'pod', 'vid', 'cyc', 'spin', 'fit')),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  device_id TEXT,
  kind TEXT NOT NULL CHECK (kind IN ('bug', 'idea')),
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  page TEXT NOT NULL DEFAULT '',
  user_agent TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'received',
  github_issue_number INTEGER,
  github_issue_url TEXT,
  proposal_json TEXT,
  chosen_option TEXT,
  pr_url TEXT,
  shipped_at TIMESTAMPTZ,
  last_dispatch_at TIMESTAMPTZ,
  last_build_at TIMESTAMPTZ,
  dispatch_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_user_created
  ON feedback (user_id, created_at DESC)
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_feedback_device_app_created
  ON feedback (device_id, app, created_at DESC)
  WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_feedback_status_created
  ON feedback (status, created_at ASC);

CREATE INDEX IF NOT EXISTS ix_feedback_github_issue
  ON feedback (github_issue_number)
  WHERE github_issue_number IS NOT NULL;
