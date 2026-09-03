import { Router, type Request } from "express";
import { query } from "../db.js";
import { catalogMovieFromTmdb, fetchTmdbMovie, searchTmdbMovie } from "../lib/tmdb.js";
import { lookupItunesPodcast } from "../lib/itunes.js";
import { config } from "../config.js";
import { runNamedJob } from "../jobs.js";
import { movieIdFromTmdb, podcastIdFromItunes } from "../lib/passwords.js";
import { importMovieCatalog } from "../lib/catalog-import.js";

const router = Router();

const audit = async (req: Request, action: string, details: unknown) => {
  const actor = (req as Request & { adminActor?: string }).adminActor || "unknown";
  await query(`INSERT INTO admin_audit (actor, action, details) VALUES ($1, $2, $3::jsonb)`, [
    actor,
    action,
    JSON.stringify(details ?? {})
  ]);
};

router.get("/health", async (_req, res) => {
  const movies = await query(`SELECT COUNT(*)::int AS count FROM mov_movies`);
  const staleStreaming = await query(
    `SELECT COUNT(*)::int AS count FROM mov_movies m
     LEFT JOIN mov_streaming s ON s.movie_id = m.id
     WHERE m.tmdb_id IS NOT NULL AND (s.refreshed_at IS NULL OR s.refreshed_at < NOW() - INTERVAL '36 hours')`
  );
  const podcasts = await query(`SELECT COUNT(*)::int AS count FROM pod_podcasts`);
  const episodes = await query(`SELECT COUNT(*)::int AS count FROM pod_episodes`);
  const users = await query(`SELECT COUNT(*)::int AS count FROM users`);
  const jobs = await query(
    `SELECT name, status, started_at, finished_at, stats, error FROM job_runs ORDER BY started_at DESC LIMIT 12`
  );
  const revisions = await query(`SELECT app, revision, generated_at FROM catalog_revisions`);
  res.json({
    movies: movies.rows[0].count,
    staleStreaming: staleStreaming.rows[0].count,
    podcasts: podcasts.rows[0].count,
    episodes: episodes.rows[0].count,
    users: users.rows[0].count,
    revisions: revisions.rows,
    jobs: jobs.rows
  });
});

router.get("/jobs", async (_req, res) => {
  const result = await query(
    `SELECT id, name, status, started_at, finished_at, stats, error FROM job_runs ORDER BY started_at DESC LIMIT 40`
  );
  res.json({ jobs: result.rows });
});

router.post("/jobs/:name", async (req, res) => {
  try {
    const result = await runNamedJob(String(req.params.name));
    await audit(req, `job:${String(req.params.name)}`, result);
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Job failed." });
  }
});

router.post("/mov/movies", async (req, res) => {
  const title = String(req.body?.title || "").trim();
  const tmdbId = req.body?.tmdbId ? Number(req.body.tmdbId) : null;
  if (!title && !tmdbId) {
    res.status(400).json({ error: "title or tmdbId required." });
    return;
  }
  let movie = {
    id: tmdbId ? movieIdFromTmdb(tmdbId) : `custom-${Date.now()}`,
    tmdbId,
    title: title || "Untitled",
    year: req.body?.year ?? null,
    posterPath: req.body?.posterPath ?? null,
    backdropPath: req.body?.backdropPath ?? null,
    overview: req.body?.overview ?? null,
    genres: req.body?.genres ?? []
  };
  if (tmdbId && config.tmdbApiKey) {
    try {
      movie = { ...movie, ...catalogMovieFromTmdb(await fetchTmdbMovie(tmdbId, config.tmdbApiKey)) };
    } catch {
      // keep submitted fields
    }
  }
  await query(
    `
    INSERT INTO mov_movies (id, tmdb_id, title, year, poster_path, backdrop_path, overview, genres, last_updated)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,NOW())
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      year = EXCLUDED.year,
      poster_path = EXCLUDED.poster_path,
      overview = EXCLUDED.overview,
      last_updated = NOW()
    `,
    [movie.id, movie.tmdbId, movie.title, movie.year, movie.posterPath, movie.backdropPath, movie.overview, JSON.stringify(movie.genres)]
  );
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
  await audit(req, "mov.movie.upsert", { id: movie.id });
  res.status(201).json({ movie });
});

router.patch("/mov/movies/:id", async (req, res) => {
  await query(
    `
    UPDATE mov_movies
    SET title = COALESCE($2, title),
        year = COALESCE($3, year),
        overview = COALESCE($4, overview),
        poster_path = COALESCE($5, poster_path),
        last_updated = NOW()
    WHERE id = $1
    `,
    [String(req.params.id), req.body?.title ?? null, req.body?.year ?? null, req.body?.overview ?? null, req.body?.posterPath ?? null]
  );
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
  await audit(req, "mov.movie.patch", { id: String(req.params.id) });
  res.json({ ok: true });
});

router.delete("/mov/movies/:id", async (req, res) => {
  await query(`DELETE FROM mov_movies WHERE id = $1`, [String(req.params.id)]);
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
  await audit(req, "mov.movie.delete", { id: String(req.params.id) });
  res.json({ ok: true });
});

router.post("/mov/sources", async (req, res) => {
  const identifier = String(req.body?.identifier || "").trim();
  const name = String(req.body?.name || "").trim();
  if (!identifier || !name) {
    res.status(400).json({ error: "identifier and name required." });
    return;
  }
  await query(
    `
    INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, updated_at)
    VALUES ($1,$2,$3,$4,$5,$6,NOW())
    ON CONFLICT (identifier) DO UPDATE SET
      name = EXCLUDED.name,
      type = EXCLUDED.type,
      url = EXCLUDED.url,
      is_ranked = EXCLUDED.is_ranked,
      enabled = EXCLUDED.enabled,
      updated_at = NOW()
    `,
    [
      identifier,
      name,
      req.body?.type || "url",
      req.body?.url ?? null,
      Boolean(req.body?.isRanked),
      req.body?.enabled !== false
    ]
  );
  await audit(req, "mov.source.upsert", { identifier });
  res.status(201).json({ ok: true });
});

router.post("/mov/import", async (req, res) => {
  const result = await importMovieCatalog({
    dataSources: Array.isArray(req.body?.dataSources) ? req.body.dataSources : [],
    movies: Array.isArray(req.body?.movies) ? req.body.movies : []
  });
  await audit(req, "mov.import", result);
  res.json(result);
});

router.get("/mov/tmdb/search", async (req, res) => {
  const term = String(req.query.q || "");
  if (!term || !config.tmdbApiKey) {
    res.status(400).json({ error: "Search term and TMDB_API_KEY required." });
    return;
  }
  const year = req.query.year ? Number(req.query.year) : undefined;
  const movie = await searchTmdbMovie(term, year, config.tmdbApiKey);
  res.json({ movie });
});

router.post("/pod/podcasts", async (req, res) => {
  const itunesId = req.body?.itunesId ? String(req.body.itunesId) : "";
  let podcast = {
    id: itunesId ? podcastIdFromItunes(itunesId) : `custom-${Date.now()}`,
    itunesId: itunesId || null,
    title: String(req.body?.title || "Untitled"),
    author: String(req.body?.author || ""),
    feedUrl: String(req.body?.feedUrl || ""),
    artworkUrl: req.body?.artworkUrl ?? null,
    artworkUrl600: req.body?.artworkUrl600 ?? null,
    categories: req.body?.categories ?? [],
    websiteUrl: req.body?.websiteUrl ?? null
  };
  if (itunesId) {
    const found = await lookupItunesPodcast(itunesId);
    if (found) {
      podcast = { ...podcast, ...found };
    }
  }
  if (!podcast.feedUrl) {
    res.status(400).json({ error: "feedUrl or a resolvable itunesId is required." });
    return;
  }
  await query(
    `
    INSERT INTO pod_podcasts (id, itunes_id, title, author, feed_url, artwork_url, artwork_url_600, categories, website_url, updated_at)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,NOW())
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      author = EXCLUDED.author,
      feed_url = EXCLUDED.feed_url,
      artwork_url = EXCLUDED.artwork_url,
      categories = EXCLUDED.categories,
      updated_at = NOW()
    `,
    [
      podcast.id,
      podcast.itunesId,
      podcast.title,
      podcast.author,
      podcast.feedUrl,
      podcast.artworkUrl,
      podcast.artworkUrl600,
      JSON.stringify(podcast.categories),
      podcast.websiteUrl
    ]
  );
  if (Array.isArray(req.body?.categories)) {
    for (const [index, name] of req.body.categories.entries()) {
      await query(
        `INSERT INTO pod_categories (name, sort_order) VALUES ($1, $2) ON CONFLICT (name) DO NOTHING`,
        [String(name), index]
      );
    }
  }
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'podlink'`);
  await audit(req, "pod.podcast.upsert", { id: podcast.id });
  res.status(201).json({ podcast });
});

router.delete("/pod/podcasts/:id", async (req, res) => {
  await query(`DELETE FROM pod_podcasts WHERE id = $1`, [String(req.params.id)]);
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'podlink'`);
  await audit(req, "pod.podcast.delete", { id: String(req.params.id) });
  res.json({ ok: true });
});

export default router;
