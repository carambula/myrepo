CREATE INDEX IF NOT EXISTS race_participants_team_idx
  ON race_participants (team_id);

CREATE INDEX IF NOT EXISTS race_participants_athlete_idx
  ON race_participants (athlete_id);

CREATE INDEX IF NOT EXISTS race_participants_race_idx
  ON race_participants (race_id);
