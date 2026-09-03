ALTER TABLE mov_movies
  ADD COLUMN IF NOT EXISTS physical_media JSONB;

CREATE INDEX IF NOT EXISTS mov_movies_physical_idx
  ON mov_movies ((physical_media->>'hasCriterion'))
  WHERE physical_media IS NOT NULL;
