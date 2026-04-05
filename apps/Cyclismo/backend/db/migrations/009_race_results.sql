-- Store race-level results (winner and classification summaries) with source provenance.
CREATE TABLE IF NOT EXISTS race_results (
  race_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id UUID NOT NULL REFERENCES races(race_id) ON DELETE CASCADE,
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

CREATE UNIQUE INDEX IF NOT EXISTS race_results_unique_rank_idx
  ON race_results(race_id, result_type, rank);

CREATE INDEX IF NOT EXISTS race_results_race_idx
  ON race_results(race_id);

CREATE INDEX IF NOT EXISTS race_results_synced_at_idx
  ON race_results(synced_at DESC);
