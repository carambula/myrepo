import express from "express";
import cors from "cors";
import { query } from "./db.js";
import {
  ensureRaceWinnerResult,
  ensureStageWinnerResult,
  type RaceLookupRow,
  type StageLookupRow
} from "./wikidataResults.js";

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/races", async (req, res) => {
  const { startDate, endDate, series, discipline, raceType, gender, limit, format } =
    req.query;
  const formatValue = format ?? raceType;

  const filters: string[] = [];
  const params: Array<string | number> = [];

  if (startDate) {
    params.push(String(startDate));
    filters.push(`start_date >= $${params.length}`);
  }
  if (endDate) {
    params.push(String(endDate));
    filters.push(`end_date <= $${params.length}`);
  }
  if (series) {
    params.push(String(series));
    filters.push(`series = $${params.length}`);
  }
  if (discipline) {
    params.push(String(discipline));
    filters.push(`discipline = $${params.length}`);
  }
  if (formatValue) {
    params.push(String(formatValue));
    filters.push(`race_type = $${params.length}`);
  }
  if (gender) {
    params.push(String(gender));
    filters.push(`gender_division = $${params.length}`);
  }

  const whereClause = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
  const parsedLimit = Number(limit);
  const limitValue = Number.isFinite(parsedLimit)
    ? Math.min(Math.max(parsedLimit, 1), 200)
    : 50;

  try {
    const result = await query(
      `
      SELECT race_id, name, series, classification, discipline, race_type,
             to_char(start_date, 'YYYY-MM-DD') AS start_date,
             to_char(end_date, 'YYYY-MM-DD') AS end_date,
             start_time_local, start_timezone, start_datetime_utc,
             location_country, location_city, organizer, official_website,
             data_timestamp, gender_division, image_url, colloquial_categories
      FROM races
      ${whereClause}
      ORDER BY start_date ASC
      LIMIT $${params.length + 1}
      `,
      [...params, limitValue]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch races." });
  }
});

app.get("/races/:id", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT race_id, name, series, classification, discipline, race_type,
             to_char(start_date, 'YYYY-MM-DD') AS start_date,
             to_char(end_date, 'YYYY-MM-DD') AS end_date,
             start_time_local, start_timezone, start_datetime_utc,
             location_country, location_city, organizer, official_website,
             data_timestamp, gender_division, image_url, colloquial_categories
      FROM races
      WHERE race_id = $1
      `,
      [req.params.id]
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: "Race not found." });
      return;
    }
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch race." });
  }
});

app.get("/races/:id/podcasts", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        pe.episode_id,
        pe.source_id,
        ps.slug AS source_slug,
        ps.name AS source_name,
        pe.title,
        pe.raw_title,
        pe.description,
        pe.episode_url,
        pe.published_at,
        rpe.matched_by
      FROM race_podcast_episodes rpe
      INNER JOIN podcast_episodes pe ON pe.episode_id = rpe.episode_id
      INNER JOIN podcast_sources ps ON ps.source_id = pe.source_id
      WHERE rpe.race_id = $1
      ORDER BY pe.published_at DESC NULLS LAST, pe.title ASC
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch race podcasts." });
  }
});

app.get("/races/:id/stages", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        stage_id, race_id, source_stage_id, stage_number, stage_type, name,
        to_char(date, 'YYYY-MM-DD') AS date,
        start_location, end_location, distance_km, depart_time_local, depart_timezone,
        depart_datetime_utc, is_rest_day, source_url, created_at, updated_at
      FROM race_stages
      WHERE race_id = $1
      ORDER BY date ASC NULLS LAST, stage_number ASC NULLS LAST, name ASC
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch race stages." });
  }
});

app.get("/races/:id/results", async (req, res) => {
  try {
    const raceResult = await query(
      `
      SELECT race_id, name,
             to_char(start_date, 'YYYY-MM-DD') AS start_date,
             to_char(end_date, 'YYYY-MM-DD') AS end_date,
             race_type, gender_division, official_website
      FROM races
      WHERE race_id = $1
      `,
      [req.params.id]
    );
    if (raceResult.rowCount === 0) {
      res.status(404).json({ error: "Race not found." });
      return;
    }
    const race = raceResult.rows[0] as RaceLookupRow;
    await ensureRaceWinnerResult(race);
    const result = await query(
      `
      SELECT
        race_result_id, race_id, result_type, rank, athlete_name, team_name, nationality,
        result_text, source, source_url, metadata, synced_at, created_at, updated_at
      FROM race_results
      WHERE race_id = $1
      ORDER BY rank ASC, created_at ASC
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch race results." });
  }
});

app.get("/stages/:id", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        stage_id, race_id, source_stage_id, stage_number, stage_type, name,
        to_char(date, 'YYYY-MM-DD') AS date,
        start_location, end_location, distance_km, depart_time_local, depart_timezone,
        depart_datetime_utc, is_rest_day, source_url, created_at, updated_at
      FROM race_stages
      WHERE stage_id = $1
      `,
      [req.params.id]
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: "Stage not found." });
      return;
    }
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch stage." });
  }
});

app.get("/stages/:id/results", async (req, res) => {
  try {
    const stageResult = await query(
      `
      SELECT
        s.stage_id, s.race_id, s.stage_number, s.name, to_char(s.date, 'YYYY-MM-DD') AS date, s.is_rest_day,
        r.name AS race_name, to_char(r.start_date, 'YYYY-MM-DD') AS start_date,
        to_char(r.end_date, 'YYYY-MM-DD') AS end_date, r.race_type, r.gender_division, r.official_website
      FROM race_stages s
      INNER JOIN races r ON r.race_id = s.race_id
      WHERE s.stage_id = $1
      `,
      [req.params.id]
    );
    if (stageResult.rowCount === 0) {
      res.status(404).json({ error: "Stage not found." });
      return;
    }
    const row = stageResult.rows[0] as StageLookupRow &
      Omit<RaceLookupRow, "race_id" | "name"> & { race_name: string };
    const race: RaceLookupRow = {
      race_id: row.race_id,
      name: row.race_name,
      start_date: row.start_date,
      end_date: row.end_date,
      race_type: row.race_type,
      gender_division: row.gender_division,
      official_website: row.official_website
    };
    const stage: StageLookupRow = {
      stage_id: row.stage_id,
      race_id: row.race_id,
      stage_number: row.stage_number,
      name: row.name,
      date: row.date,
      is_rest_day: row.is_rest_day
    };
    await ensureStageWinnerResult(race, stage);
    const result = await query(
      `
      SELECT
        stage_result_id, stage_id, result_type, rank, athlete_name, team_name, nationality,
        result_text, source, source_url, metadata, synced_at, created_at, updated_at
      FROM stage_results
      WHERE stage_id = $1
      ORDER BY rank ASC, created_at ASC
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch stage results." });
  }
});

app.get("/stages/:id/podcasts", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        pe.episode_id,
        pe.source_id,
        ps.slug AS source_slug,
        ps.name AS source_name,
        pe.title,
        pe.raw_title,
        pe.description,
        pe.episode_url,
        pe.published_at,
        spe.matched_by
      FROM stage_podcast_episodes spe
      INNER JOIN podcast_episodes pe ON pe.episode_id = spe.episode_id
      INNER JOIN podcast_sources ps ON ps.source_id = pe.source_id
      WHERE spe.stage_id = $1
      ORDER BY pe.published_at DESC NULLS LAST, pe.title ASC
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch stage podcasts." });
  }
});

app.get("/teams/:id", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT team_id, name, uci_code, discipline, region, website,
             social_handles, logo_url
      FROM teams
      WHERE team_id = $1
      `,
      [req.params.id]
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: "Team not found." });
      return;
    }
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch team." });
  }
});

app.get("/teams/:id/races", async (req, res) => {
  const onlyUpcoming = String(req.query.upcoming || "false") === "true";
  try {
    const result = await query(
      `
      SELECT r.race_id, r.name, r.series, r.classification, r.discipline, r.race_type,
             to_char(r.start_date, 'YYYY-MM-DD') AS start_date,
             to_char(r.end_date, 'YYYY-MM-DD') AS end_date,
             r.start_time_local, r.start_timezone, r.start_datetime_utc,
             r.location_country, r.location_city, r.organizer, r.official_website,
             r.data_timestamp, r.gender_division, r.image_url, r.colloquial_categories
      FROM races r
      INNER JOIN race_participants rp ON rp.race_id = r.race_id
      WHERE rp.team_id = $1
      ${onlyUpcoming ? "AND r.start_date >= CURRENT_DATE" : ""}
      ORDER BY r.start_date ASC
      LIMIT 50
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch team races." });
  }
});

app.get("/athletes/:id", async (req, res) => {
  try {
    const result = await query(
      `
      SELECT athlete_id, full_name, team_id, nationality, discipline, dob, social_handles
      FROM athletes
      WHERE athlete_id = $1
      `,
      [req.params.id]
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: "Athlete not found." });
      return;
    }
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch athlete." });
  }
});

app.get("/athletes/:id/races", async (req, res) => {
  const onlyUpcoming = String(req.query.upcoming || "false") === "true";
  try {
    const result = await query(
      `
      SELECT r.race_id, r.name, r.series, r.classification, r.discipline, r.race_type,
             to_char(r.start_date, 'YYYY-MM-DD') AS start_date,
             to_char(r.end_date, 'YYYY-MM-DD') AS end_date,
             r.start_time_local, r.start_timezone, r.start_datetime_utc,
             r.location_country, r.location_city, r.organizer, r.official_website,
             r.data_timestamp, r.gender_division, r.image_url, r.colloquial_categories
      FROM races r
      INNER JOIN race_participants rp ON rp.race_id = r.race_id
      WHERE rp.athlete_id = $1
      ${onlyUpcoming ? "AND r.start_date >= CURRENT_DATE" : ""}
      ORDER BY r.start_date ASC
      LIMIT 50
      `,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch athlete races." });
  }
});

app.get("/search", async (req, res) => {
  const queryText = String(req.query.q || "").trim();
  if (!queryText) {
    res.json({ races: [], teams: [], athletes: [] });
    return;
  }

  try {
    const [races, teams, athletes] = await Promise.all([
      query(
        `
        SELECT race_id, name,
               to_char(start_date, 'YYYY-MM-DD') AS start_date,
               to_char(end_date, 'YYYY-MM-DD') AS end_date,
               location_country, location_city
        FROM races
        WHERE search_vector @@ websearch_to_tsquery('simple', $1)
        ORDER BY start_date DESC
        LIMIT 20
        `,
        [queryText]
      ),
      query(
        `
        SELECT team_id, name, region, discipline
        FROM teams
        WHERE search_vector @@ websearch_to_tsquery('simple', $1)
        LIMIT 20
        `,
        [queryText]
      ),
      query(
        `
        SELECT athlete_id, full_name, nationality, discipline
        FROM athletes
        WHERE search_vector @@ websearch_to_tsquery('simple', $1)
        LIMIT 20
        `,
        [queryText]
      )
    ]);

    res.json({
      races: races.rows,
      teams: teams.rows,
      athletes: athletes.rows
    });
  } catch (error) {
    res.status(500).json({ error: "Search failed." });
  }
});

app.listen(port, () => {
  console.log(`Cyclismo API listening on ${port}`);
});
