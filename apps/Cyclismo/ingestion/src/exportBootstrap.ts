import fs from "node:fs/promises";
import path from "node:path";
import { query, closePool } from "./db.js";

type RaceRow = {
  race_id: string;
  name: string;
  series: string;
  classification: string | null;
  colloquial_categories: string[];
  discipline: string;
  race_type: string;
  start_date: string;
  end_date: string;
  start_time_local: string | null;
  start_timezone: string | null;
  start_datetime_utc: string | null;
  location_country: string | null;
  location_city: string | null;
  organizer: string | null;
  official_website: string | null;
  data_timestamp: string;
  gender_division: string | null;
  image_url: string | null;
};

type TeamRow = {
  team_id: string;
  name: string;
  uci_code: string | null;
  discipline: string;
  region: string | null;
  website: string | null;
  social_handles: Record<string, string> | null;
  logo_url: string | null;
};

type AthleteRow = {
  athlete_id: string;
  full_name: string;
  team_id: string | null;
  nationality: string | null;
  discipline: string | null;
  dob: string | null;
  social_handles: Record<string, string> | null;
};

type ParticipantRow = {
  race_id: string;
  athlete_id: string;
  team_id: string | null;
  role: string | null;
};

type StreamerRow = {
  streamer_id: string;
  name: string;
  slug: string;
  website_url: string | null;
};

type RaceStreamRow = {
  race_id: string;
  streamer_id: string;
  region_codes: string[];
  stream_url: string | null;
  source_url: string | null;
};

type PodcastSourceRow = {
  source_id: string;
  slug: string;
  name: string;
  feed_url: string;
  website_url: string | null;
};

type PodcastEpisodeRow = {
  episode_id: string;
  source_id: string;
  guid: string | null;
  title: string;
  raw_title: string | null;
  description: string | null;
  episode_url: string | null;
  published_at: string | null;
};

type RacePodcastEpisodeRow = {
  race_id: string;
  episode_id: string;
  matched_by: string | null;
};

type StageRow = {
  stage_id: string;
  race_id: string;
  source_stage_id: string | null;
  stage_number: number | null;
  stage_type: string | null;
  name: string;
  date: string | null;
  start_location: string | null;
  end_location: string | null;
  distance_km: number | null;
  depart_time_local: string | null;
  depart_timezone: string | null;
  depart_datetime_utc: string | null;
  is_rest_day: boolean;
  source_url: string | null;
  created_at: string;
  updated_at: string;
};

type StagePodcastEpisodeRow = {
  stage_id: string;
  episode_id: string;
  matched_by: string | null;
};

type RaceResultRow = {
  race_result_id: string;
  race_id: string;
  result_type: string;
  rank: number;
  athlete_name: string;
  team_name: string | null;
  nationality: string | null;
  result_text: string | null;
  source: string;
  source_url: string | null;
  metadata: Record<string, unknown> | null;
  synced_at: string;
  created_at: string;
  updated_at: string;
};

type StageResultRow = {
  stage_result_id: string;
  stage_id: string;
  result_type: string;
  rank: number;
  athlete_name: string;
  team_name: string | null;
  nationality: string | null;
  result_text: string | null;
  source: string;
  source_url: string | null;
  metadata: Record<string, unknown> | null;
  synced_at: string;
  created_at: string;
  updated_at: string;
};

const exportBootstrap = async () => {
  const races = await query(
    `SELECT race_id, name, series, classification, discipline, race_type,
            to_char(start_date, 'YYYY-MM-DD') AS start_date,
            to_char(end_date, 'YYYY-MM-DD') AS end_date,
            start_time_local, start_timezone, start_datetime_utc,
            location_country, location_city, organizer, official_website,
            data_timestamp, gender_division, image_url, colloquial_categories
     FROM races`
  );
  const teams = await query(
    `SELECT team_id, name, uci_code, discipline, region, website, social_handles, logo_url
     FROM teams`
  );
  const athletes = await query(
    `SELECT athlete_id, full_name, team_id, nationality, discipline, dob, social_handles
     FROM athletes`
  );
  const participants = await query(
    `SELECT race_id, athlete_id, team_id, role
     FROM race_participants`
  );

  const streamers = await query(
    `SELECT streamer_id, name, slug, website_url FROM streamers`
  );
  const raceStreams = await query(
    `SELECT race_id, streamer_id, region_codes, stream_url, source_url
     FROM race_streams`
  );
  const podcastSources = await query(
    `SELECT source_id, slug, name, feed_url, website_url
     FROM podcast_sources`
  );
  const podcastEpisodes = await query(
    `SELECT episode_id, source_id, guid, title, raw_title, description, episode_url, published_at
     FROM podcast_episodes`
  );
  const racePodcastEpisodes = await query(
    `SELECT race_id, episode_id, matched_by
     FROM race_podcast_episodes`
  );
  const stages = await query(
    `SELECT stage_id, race_id, source_stage_id, stage_number, stage_type, name,
            to_char(date, 'YYYY-MM-DD') AS date,
            start_location, end_location, distance_km, depart_time_local, depart_timezone,
            depart_datetime_utc, is_rest_day, source_url, created_at, updated_at
     FROM race_stages`
  );
  const stagePodcastEpisodes = await query(
    `SELECT stage_id, episode_id, matched_by
     FROM stage_podcast_episodes`
  );
  const raceResults = await query(
    `SELECT race_result_id, race_id, result_type, rank, athlete_name, team_name, nationality,
            result_text, source, source_url, metadata, synced_at, created_at, updated_at
     FROM race_results`
  );
  const stageResults = await query(
    `SELECT stage_result_id, stage_id, result_type, rank, athlete_name, team_name, nationality,
            result_text, source, source_url, metadata, synced_at, created_at, updated_at
     FROM stage_results`
  );

  const payload = {
    races: races.rows as RaceRow[],
    teams: teams.rows as TeamRow[],
    athletes: athletes.rows as AthleteRow[],
    participants: participants.rows as ParticipantRow[],
    streamers: streamers.rows as StreamerRow[],
    raceStreams: raceStreams.rows as RaceStreamRow[],
    podcastSources: podcastSources.rows as PodcastSourceRow[],
    podcastEpisodes: podcastEpisodes.rows as PodcastEpisodeRow[],
    racePodcastEpisodes: racePodcastEpisodes.rows as RacePodcastEpisodeRow[],
    stages: stages.rows as StageRow[],
    stagePodcastEpisodes: stagePodcastEpisodes.rows as StagePodcastEpisodeRow[],
    raceResults: raceResults.rows as RaceResultRow[],
    stageResults: stageResults.rows as StageResultRow[]
  };

  if (payload.races.length > 0 && payload.stages.length === 0) {
    throw new Error(
      "Sanity check failed: attempted to export bootstrap with races but zero stages. Aborting export."
    );
  }

  const outputPath =
    process.env.BOOTSTRAP_OUTPUT_PATH ??
    path.resolve(process.cwd(), "../Cyclismo/bootstrap_database.json");

  await fs.writeFile(outputPath, JSON.stringify(payload, null, 2), "utf8");
  console.log(`Bootstrap exported to ${outputPath}`);
};

exportBootstrap()
  .catch((error) => {
    console.error("Export bootstrap failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
