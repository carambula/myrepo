-- Streaming services and race-to-streamer mappings
-- Supports FloBikes, Peacock, Max, and other sources

CREATE TABLE IF NOT EXISTS streamers (
  streamer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  website_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS race_streams (
  race_stream_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id UUID NOT NULL REFERENCES races(race_id) ON DELETE CASCADE,
  streamer_id UUID NOT NULL REFERENCES streamers(streamer_id) ON DELETE CASCADE,
  region_codes TEXT[] NOT NULL DEFAULT '{}',
  stream_url TEXT,
  source_url TEXT,
  scraped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (race_id, streamer_id)
);

CREATE INDEX IF NOT EXISTS race_streams_race_id_idx ON race_streams(race_id);
CREATE INDEX IF NOT EXISTS race_streams_streamer_id_idx ON race_streams(streamer_id);

-- Seed known streamers (idempotent); FloSports is the parent brand (FloBikes for cycling)
INSERT INTO streamers (name, slug, website_url)
VALUES
  ('FloSports', 'flobikes', 'https://www.flobikes.com'),
  ('Peacock', 'peacock', 'https://www.peacocktv.com'),
  ('Max', 'max', 'https://www.max.com')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  website_url = EXCLUDED.website_url;
