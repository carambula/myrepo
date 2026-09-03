ALTER TABLE mov_theater_stays
  ADD COLUMN IF NOT EXISTS ticket_links JSONB;
