CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  handle TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions (user_id);

CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app TEXT NOT NULL CHECK (app IN ('watchedit', 'podlink')),
  platform TEXT NOT NULL,
  push_token TEXT,
  timezone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS devices_push_idx
  ON devices (user_id, app, push_token)
  WHERE push_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app TEXT NOT NULL CHECK (app IN ('watchedit', 'podlink')),
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, app)
);

CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app TEXT NOT NULL CHECK (app IN ('watchedit', 'podlink')),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notification_queue_pending_idx
  ON notification_queue (scheduled_for)
  WHERE sent_at IS NULL;

CREATE TABLE IF NOT EXISTS follows (
  follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);

CREATE TABLE IF NOT EXISTS activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app TEXT NOT NULL CHECK (app IN ('watchedit', 'podlink', 'platform')),
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS activity_user_idx ON activity (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS user_library_mov (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  movie_id TEXT NOT NULL,
  is_watched BOOLEAN NOT NULL DEFAULT FALSE,
  is_saved BOOLEAN NOT NULL DEFAULT FALSE,
  is_rewatched BOOLEAN NOT NULL DEFAULT FALSE,
  is_listened BOOLEAN NOT NULL DEFAULT FALSE,
  rating INT,
  notes TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, movie_id)
);

CREATE TABLE IF NOT EXISTS user_library_pod (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  podcast_id TEXT NOT NULL,
  feed_url TEXT,
  title TEXT,
  artwork_url TEXT,
  is_followed BOOLEAN NOT NULL DEFAULT TRUE,
  notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  playback JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, podcast_id)
);

CREATE TABLE IF NOT EXISTS mov_sources (
  identifier TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  url TEXT,
  is_ranked BOOLEAN NOT NULL DEFAULT FALSE,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  movie_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mov_movies (
  id TEXT PRIMARY KEY,
  tmdb_id INT,
  imdb_id TEXT,
  title TEXT NOT NULL,
  year INT,
  poster_path TEXT,
  backdrop_path TEXT,
  overview TEXT,
  mpaa_rating TEXT,
  genres JSONB NOT NULL DEFAULT '[]'::jsonb,
  credits JSONB,
  trailer JSONB,
  oscar_awards JSONB,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS mov_movies_tmdb_idx
  ON mov_movies (tmdb_id)
  WHERE tmdb_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS mov_movies_updated_idx ON mov_movies (last_updated DESC);
CREATE INDEX IF NOT EXISTS mov_movies_title_idx ON mov_movies (lower(title));

CREATE TABLE IF NOT EXISTS mov_movie_sources (
  movie_id TEXT NOT NULL REFERENCES mov_movies(id) ON DELETE CASCADE,
  source_id TEXT NOT NULL REFERENCES mov_sources(identifier) ON DELETE CASCADE,
  rank INT,
  source_title TEXT,
  episode_date TIMESTAMPTZ,
  episode JSONB,
  PRIMARY KEY (movie_id, source_id)
);

CREATE TABLE IF NOT EXISTS mov_streaming (
  movie_id TEXT NOT NULL REFERENCES mov_movies(id) ON DELETE CASCADE,
  region TEXT NOT NULL DEFAULT 'US',
  providers JSONB NOT NULL DEFAULT '[]'::jsonb,
  refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (movie_id, region)
);

CREATE TABLE IF NOT EXISTS pod_categories (
  name TEXT PRIMARY KEY,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS pod_podcasts (
  id TEXT PRIMARY KEY,
  itunes_id TEXT,
  title TEXT NOT NULL,
  author TEXT,
  feed_url TEXT NOT NULL,
  artwork_url TEXT,
  artwork_url_600 TEXT,
  categories JSONB NOT NULL DEFAULT '[]'::jsonb,
  language TEXT DEFAULT 'en',
  description TEXT,
  website_url TEXT,
  is_explicit BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS pod_podcasts_feed_idx ON pod_podcasts (feed_url);
CREATE UNIQUE INDEX IF NOT EXISTS pod_podcasts_itunes_idx
  ON pod_podcasts (itunes_id)
  WHERE itunes_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS pod_episodes (
  id TEXT PRIMARY KEY,
  podcast_id TEXT NOT NULL REFERENCES pod_podcasts(id) ON DELETE CASCADE,
  guid TEXT,
  title TEXT NOT NULL,
  description TEXT,
  publish_date TIMESTAMPTZ,
  duration_seconds INT,
  audio_url TEXT,
  video_url TEXT,
  artwork_url TEXT,
  episode_number INT,
  season_number INT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS pod_episodes_guid_idx
  ON pod_episodes (podcast_id, guid)
  WHERE guid IS NOT NULL;

CREATE INDEX IF NOT EXISTS pod_episodes_pub_idx
  ON pod_episodes (podcast_id, publish_date DESC);

CREATE TABLE IF NOT EXISTS job_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  stats JSONB,
  error TEXT
);

CREATE TABLE IF NOT EXISTS catalog_revisions (
  app TEXT PRIMARY KEY CHECK (app IN ('watchedit', 'podlink')),
  revision BIGINT NOT NULL DEFAULT 0,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO catalog_revisions (app, revision)
VALUES ('watchedit', 0), ('podlink', 0)
ON CONFLICT (app) DO NOTHING;

CREATE TABLE IF NOT EXISTS admin_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
