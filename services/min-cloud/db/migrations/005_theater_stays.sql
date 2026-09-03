CREATE TABLE IF NOT EXISTS mov_theater_stays (
  tmdb_id INTEGER NOT NULL,
  region TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  has_imax BOOLEAN NOT NULL DEFAULT FALSE,
  in_catalog BOOLEAN NOT NULL DEFAULT FALSE,
  manual_override BOOLEAN NOT NULL DEFAULT FALSE,
  refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tmdb_id, region)
);

CREATE INDEX IF NOT EXISTS mov_theater_stays_region_idx
  ON mov_theater_stays (region, in_catalog);

CREATE TABLE IF NOT EXISTS mov_theater_stay_snapshots (
  region TEXT PRIMARY KEY,
  refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source TEXT NOT NULL DEFAULT 'tmdb'
);
