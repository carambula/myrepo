-- Stage-race support: stage metadata and stage-level podcast associations.
CREATE TABLE IF NOT EXISTS race_stages (
  stage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id UUID NOT NULL REFERENCES races(race_id) ON DELETE CASCADE,
  source_stage_id TEXT,
  stage_number INTEGER,
  stage_type TEXT,
  name TEXT NOT NULL,
  date DATE,
  start_location TEXT,
  end_location TEXT,
  distance_km NUMERIC(6, 2),
  depart_time_local TIME,
  depart_timezone TEXT,
  depart_datetime_utc TIMESTAMPTZ,
  is_rest_day BOOLEAN NOT NULL DEFAULT FALSE,
  source_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (race_id, source_stage_id),
  CHECK (stage_number IS NULL OR stage_number >= 1),
  CHECK (distance_km IS NULL OR distance_km >= 0)
);

-- Primary idempotency key when source provides durable stage IDs.
CREATE INDEX IF NOT EXISTS race_stages_race_idx ON race_stages(race_id);
CREATE INDEX IF NOT EXISTS race_stages_date_idx ON race_stages(date);
CREATE UNIQUE INDEX IF NOT EXISTS race_stages_number_date_unique_idx
  ON race_stages(race_id, stage_number, date)
  WHERE stage_number IS NOT NULL AND date IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS race_stages_rest_day_unique_idx
  ON race_stages(race_id, date, is_rest_day, name)
  WHERE date IS NOT NULL;

CREATE TABLE IF NOT EXISTS stage_podcast_episodes (
  stage_id UUID NOT NULL REFERENCES race_stages(stage_id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES podcast_episodes(episode_id) ON DELETE CASCADE,
  matched_by TEXT,
  matched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (stage_id, episode_id)
);

CREATE INDEX IF NOT EXISTS stage_podcast_episodes_episode_idx
  ON stage_podcast_episodes(episode_id);
