CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS races (
  race_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  series TEXT NOT NULL,
  classification TEXT,
  discipline TEXT NOT NULL,
  race_type TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  location_country TEXT,
  location_city TEXT,
  organizer TEXT,
  official_website TEXT,
  data_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  gender_division TEXT,
  search_vector TSVECTOR
);
CREATE UNIQUE INDEX IF NOT EXISTS races_natural_key
  ON races (name, start_date, discipline);

CREATE TABLE IF NOT EXISTS teams (
  team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  uci_code TEXT,
  discipline TEXT NOT NULL,
  region TEXT,
  website TEXT,
  social_handles JSONB,
  logo_url TEXT,
  search_vector TSVECTOR
);
CREATE UNIQUE INDEX IF NOT EXISTS teams_natural_key
  ON teams (name, uci_code);

CREATE TABLE IF NOT EXISTS athletes (
  athlete_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  team_id UUID REFERENCES teams(team_id),
  nationality TEXT,
  discipline TEXT,
  dob DATE,
  social_handles JSONB,
  search_vector TSVECTOR
);
CREATE UNIQUE INDEX IF NOT EXISTS athletes_natural_key
  ON athletes (full_name, dob);

CREATE TABLE IF NOT EXISTS race_participants (
  race_id UUID REFERENCES races(race_id),
  athlete_id UUID REFERENCES athletes(athlete_id),
  team_id UUID REFERENCES teams(team_id),
  role TEXT,
  PRIMARY KEY (race_id, athlete_id)
);

CREATE INDEX IF NOT EXISTS races_search_idx ON races USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS teams_search_idx ON teams USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS athletes_search_idx ON athletes USING GIN (search_vector);

CREATE OR REPLACE FUNCTION races_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', coalesce(NEW.name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(NEW.series, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(NEW.location_country, '')), 'C') ||
    setweight(to_tsvector('simple', coalesce(NEW.location_city, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION teams_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', coalesce(NEW.name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(NEW.region, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(NEW.uci_code, '')), 'B');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION athletes_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', coalesce(NEW.full_name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(NEW.nationality, '')), 'B');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS races_search_vector_trigger ON races;
CREATE TRIGGER races_search_vector_trigger
BEFORE INSERT OR UPDATE ON races
FOR EACH ROW EXECUTE FUNCTION races_search_vector_update();

DROP TRIGGER IF EXISTS teams_search_vector_trigger ON teams;
CREATE TRIGGER teams_search_vector_trigger
BEFORE INSERT OR UPDATE ON teams
FOR EACH ROW EXECUTE FUNCTION teams_search_vector_update();

DROP TRIGGER IF EXISTS athletes_search_vector_trigger ON athletes;
CREATE TRIGGER athletes_search_vector_trigger
BEFORE INSERT OR UPDATE ON athletes
FOR EACH ROW EXECUTE FUNCTION athletes_search_vector_update();
