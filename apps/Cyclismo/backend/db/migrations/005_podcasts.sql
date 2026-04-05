-- Podcast ingestion support: sources, episodes, and race associations.
CREATE TABLE IF NOT EXISTS podcast_sources (
  source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL UNIQUE,
  feed_url TEXT NOT NULL,
  website_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS podcast_episodes (
  episode_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id UUID NOT NULL REFERENCES podcast_sources(source_id) ON DELETE CASCADE,
  guid TEXT,
  title TEXT NOT NULL,
  raw_title TEXT,
  description TEXT,
  episode_url TEXT,
  published_at TIMESTAMPTZ,
  scraped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (source_id, guid),
  UNIQUE (source_id, episode_url)
);

CREATE INDEX IF NOT EXISTS podcast_episodes_source_idx ON podcast_episodes(source_id);
CREATE INDEX IF NOT EXISTS podcast_episodes_published_idx ON podcast_episodes(published_at DESC);

CREATE TABLE IF NOT EXISTS race_podcast_episodes (
  race_id UUID NOT NULL REFERENCES races(race_id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES podcast_episodes(episode_id) ON DELETE CASCADE,
  matched_by TEXT,
  matched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (race_id, episode_id)
);

CREATE INDEX IF NOT EXISTS race_podcast_episodes_episode_idx ON race_podcast_episodes(episode_id);
