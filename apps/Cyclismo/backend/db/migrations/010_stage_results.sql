-- Store stage-level results (stage winners) with source provenance.
CREATE TABLE IF NOT EXISTS stage_results (
  stage_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id UUID NOT NULL REFERENCES race_stages(stage_id) ON DELETE CASCADE,
  result_type TEXT NOT NULL,
  rank INTEGER NOT NULL,
  athlete_name TEXT NOT NULL,
  team_name TEXT,
  nationality TEXT,
  result_text TEXT,
  source TEXT NOT NULL,
  source_url TEXT,
  metadata JSONB,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (rank >= 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS stage_results_unique_rank_idx
  ON stage_results(stage_id, result_type, rank);

CREATE INDEX IF NOT EXISTS stage_results_stage_idx
  ON stage_results(stage_id);

CREATE INDEX IF NOT EXISTS stage_results_synced_at_idx
  ON stage_results(synced_at DESC);
