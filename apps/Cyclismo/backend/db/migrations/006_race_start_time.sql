-- Add optional race start time-of-day metadata.
-- start_time_local + start_timezone represent the published local start info.
-- start_datetime_utc is an absolute timestamp when source data provides it.
ALTER TABLE races
  ADD COLUMN IF NOT EXISTS start_time_local TIME,
  ADD COLUMN IF NOT EXISTS start_timezone TEXT,
  ADD COLUMN IF NOT EXISTS start_datetime_utc TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS races_start_datetime_utc_idx
  ON races (start_datetime_utc);
