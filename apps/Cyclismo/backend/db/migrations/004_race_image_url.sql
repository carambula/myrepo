-- Add optional artwork/image URL for each race (e.g. hero image for detail view)
ALTER TABLE races ADD COLUMN IF NOT EXISTS image_url TEXT;
