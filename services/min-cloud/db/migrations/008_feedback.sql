CREATE TABLE IF NOT EXISTS feedback_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app TEXT NOT NULL CHECK (app IN ('mov', 'pod', 'vid', 'cyc', 'spin', 'fit')),
  kind TEXT NOT NULL CHECK (kind IN ('idea', 'bug')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'planned', 'in_progress', 'shipped', 'closed', 'hidden')),
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  context JSONB NOT NULL DEFAULT '{}'::jsonb,
  vote_count INTEGER NOT NULL DEFAULT 0,
  author_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  author_device_id TEXT,
  author_handle TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS feedback_items_board_idx
  ON feedback_items (app, kind, status, vote_count DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS feedback_items_created_idx
  ON feedback_items (created_at DESC);

CREATE TABLE IF NOT EXISTS feedback_votes (
  item_id UUID NOT NULL REFERENCES feedback_items(id) ON DELETE CASCADE,
  voter_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (item_id, voter_key)
);

CREATE INDEX IF NOT EXISTS feedback_votes_voter_idx
  ON feedback_votes (voter_key);
