import { Router } from "express";
import { query } from "../db.js";
import { fetchStreamingServices } from "../lib/tmdb.js";
import { config } from "../config.js";
import { catalogCacheHeaders, catalogPageMeta } from "../lib/catalog-response.js";

const router = Router();

const mapMovie = (row: Record<string, unknown>, providers: unknown[] = []) => ({
  id: row.id,
  tmdbId: row.tmdb_id == null ? null : Number(row.tmdb_id),
  imdbId: row.imdb_id,
  title: row.title,
  year: row.year == null ? null : Number(row.year),
  posterPath: row.poster_path,
  backdropPath: row.backdrop_path,
  overview: row.overview,
  mpaaRating: row.mpaa_rating,
  genres: row.genres ?? [],
  credits: row.credits,
  trailer: row.trailer,
  oscarAwards: row.oscar_awards,
  physicalMedia: row.physical_media ?? null,
  lastUpdated: row.last_updated,
  streamingServices: providers
});

router.get("/meta", async (_req, res) => {
  const revision = await query(`SELECT revision, generated_at FROM catalog_revisions WHERE app = 'watchedit'`);
  const movies = await query(`SELECT COUNT(*)::int AS count FROM mov_movies`);
  const unmatched = await query(`SELECT COUNT(*)::int AS count FROM mov_movies WHERE tmdb_id IS NULL`);
  const physicalMedia = await query(
    `SELECT COUNT(*)::int AS count FROM mov_movies WHERE physical_media IS NOT NULL`
  );
  const revisionNumber = Number(revision.rows[0]?.revision ?? 0);
  const movieCount = Number(movies.rows[0].count ?? 0);
  res.set(catalogCacheHeaders(revisionNumber, movieCount));
  res.json({
    app: "watchedit",
    revision: revisionNumber,
    generatedAt: revision.rows[0]?.generated_at ?? null,
    movieCount,
    unmatchedCount: Number(unmatched.rows[0].count ?? 0),
    physicalMediaCount: physicalMedia.rows[0].count
  });
});

router.get("/catalog", async (req, res) => {
  const since = typeof req.query.updatedSince === "string" ? req.query.updatedSince : null;
  const limit = Math.min(Number(req.query.limit) || 400, 1000);
  const offset = Math.max(Number(req.query.offset) || 0, 0);
  const params: Array<string | number> = [limit, offset];
  let where = "";
  if (since) {
    params.push(since);
    where = `WHERE m.last_updated > $${params.length}`;
  }
  const revision = await query(`SELECT revision, generated_at FROM catalog_revisions WHERE app = 'watchedit'`);
  const totalResult = await query(
    `SELECT COUNT(*)::int AS count FROM mov_movies m ${since ? "WHERE m.last_updated > $1" : ""}`,
    since ? [since] : []
  );
  const movies = await query(
    `
    SELECT m.*, COALESCE(s.providers, '[]'::jsonb) AS providers
    FROM mov_movies m
    LEFT JOIN mov_streaming s ON s.movie_id = m.id AND s.region = $${params.length + 1}
    ${where}
    ORDER BY m.last_updated DESC, m.title ASC
    LIMIT $1 OFFSET $2
    `,
    [...params, config.tmdbRegion]
  );
  const sources = await query(`SELECT identifier, name, type, url, is_ranked, enabled, movie_count FROM mov_sources ORDER BY name`);
  const links = await query(
    `SELECT movie_id, source_id, rank, source_title, episode_date, episode FROM mov_movie_sources`
  );
  const linksByMovie = new Map<string, unknown[]>();
  for (const link of links.rows) {
    const list = linksByMovie.get(String(link.movie_id)) ?? [];
    list.push({
      identifier: link.source_id,
      rank: link.rank,
      sourceTitle: link.source_title,
      episodeDate: link.episode_date,
      episode: link.episode
    });
    linksByMovie.set(String(link.movie_id), list);
  }
  const mapped = movies.rows.map((row) => ({
    ...mapMovie(row, Array.isArray(row.providers) ? row.providers : []),
    sources: linksByMovie.get(String(row.id)) ?? []
  }));
  const revisionNumber = Number(revision.rows[0]?.revision ?? 0);
  const total = Number(totalResult.rows[0]?.count ?? 0);
  const page = catalogPageMeta(total, offset, mapped.length, limit);
  res.set(catalogCacheHeaders(revisionNumber, total));
  res.json({
    app: "watchedit",
    revision: revisionNumber,
    generatedAt: revision.rows[0]?.generated_at ?? null,
    sources: sources.rows,
    movies: mapped,
    ...page
  });
});

router.get("/movies/:id", async (req, res) => {
  const result = await query(
    `
    SELECT m.*, COALESCE(s.providers, '[]'::jsonb) AS providers
    FROM mov_movies m
    LEFT JOIN mov_streaming s ON s.movie_id = m.id AND s.region = $2
    WHERE m.id = $1 OR m.tmdb_id::text = $1
    `,
    [String(req.params.id), config.tmdbRegion]
  );
  if (!result.rowCount) {
    res.status(404).json({ error: "Movie not found." });
    return;
  }
  const links = await query(
    `SELECT source_id, rank, source_title, episode_date, episode FROM mov_movie_sources WHERE movie_id = $1`,
    [result.rows[0].id]
  );
  res.json({
    movie: {
      ...mapMovie(result.rows[0], result.rows[0].providers ?? []),
      sources: links.rows
    }
  });
});

router.get("/streaming/:tmdbId", async (req, res) => {
  const tmdbId = Number(String(req.params.tmdbId));
  if (!Number.isFinite(tmdbId)) {
    res.status(400).json({ error: "Invalid TMDB id." });
    return;
  }
  const cached = await query(
    `
    SELECT s.providers, s.refreshed_at
    FROM mov_streaming s
    JOIN mov_movies m ON m.id = s.movie_id
    WHERE m.tmdb_id = $1 AND s.region = $2
    `,
    [tmdbId, config.tmdbRegion]
  );
  if (cached.rowCount) {
    res.json({
      tmdbId,
      region: config.tmdbRegion,
      providers: cached.rows[0].providers,
      refreshedAt: cached.rows[0].refreshed_at,
      source: "cache"
    });
    return;
  }
  if (!config.tmdbApiKey) {
    res.status(503).json({ error: "Streaming lookup unavailable." });
    return;
  }
  try {
    const providers = await fetchStreamingServices(tmdbId, config.tmdbApiKey, config.tmdbRegion);
    res.json({ tmdbId, region: config.tmdbRegion, providers, source: "tmdb" });
  } catch (error) {
    res.status(502).json({ error: error instanceof Error ? error.message : "TMDB lookup failed." });
  }
});

router.get("/sources", async (_req, res) => {
  const result = await query(
    `SELECT identifier, name, type, url, is_ranked, enabled, movie_count, updated_at FROM mov_sources ORDER BY name`
  );
  res.json({ sources: result.rows });
});

export default router;
