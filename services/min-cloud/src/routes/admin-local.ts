import { Router, type Request } from "express";
import { query } from "../db.js";
import { config } from "../config.js";
import { fetchText } from "../lib/http.js";
import {
  collapseClosetPicks,
  fetchClosetPicksPage,
  isClosetPicksIndexUrl,
  isClosetPicksUrl,
  parseClosetPicksEpisode,
  parseClosetPicksIndex,
  parseCriterionFilmPage,
  toClosetPicksCatalogItem
} from "../lib/closet-picks-scrape.js";
import { isClosetPicksSource, prepareClosetPicksQuery } from "../lib/closet-picks-match.js";
import { fetchImdbIdFromTmdb, fetchStreamingServices, fetchTmdbMovieDetails, searchTmdbMovies } from "../lib/tmdb.js";
import { parseRssFeed } from "../lib/rss.js";
import { scrapeListItems } from "../lib/list-scrape.js";
import { ingestPodcastEpisode, purgePodcastNoiseMovies, resolveTmdbMatch } from "../lib/podcast-ingest.js";
import {
  determineItemStatus,
  prepareMovieQuery,
  shouldSkipPodcastNoise
} from "../lib/title-match.js";
import { applyPhysicalMediaOverlay } from "../lib/catalog-import.js";
import {
  filterIndexToCatalog,
  normalizePhysicalMedia,
  overlayFromIndex,
  physicalMediaStats,
  seedCriterionFromSources,
  seedCurated4K
} from "../lib/physical-media.js";
import { fetchWikidataPhysicalMediaIndex } from "../lib/physical-media-wikidata.js";
import {
  fetchOmdbAwards,
  fetchOmdbAwardsByTitle,
  fetchWikidataOscars,
  mergeWikidataIntoOscar,
  runOscarOmdbBatch,
  runOscarWikidataBatch,
  type OscarAwards
} from "../lib/oscar-awards.js";
import {
  adminCatalogHealth,
  buildDedupeGroups,
  bumpWatchedIt,
  clearInferredPhysicalMedia,
  clearOscarAwards,
  deleteAdminRow,
  loadAdminBootstrap,
  loadAdminMovies,
  loadAdminSources,
  updateImdbIdForTmdb,
  updateOscarAwardsForTmdb,
  upsertAdminMovie,
  type AdminMovie
} from "../lib/admin-catalog.js";
import {
  clearInferredTheaterStays,
  findTheaterStay,
  loadTheaterStayStats,
  normalizeTheaterStayUpdate,
  normalizeTicketLinks,
  resolveNowPlaying,
  upsertManualTheaterStay,
  upsertTheaterTicketLinks
} from "../lib/theater-stays.js";
import {
  listAudit,
  listSnapshots,
  recordAudit,
  restorePhysicalMediaFromSnapshot,
  restoreSnapshot,
  revertAudit,
  snapshotIfNeeded,
  takeSnapshot
} from "../lib/admin-history.js";

const router = Router();

const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;

const movieAt = async (index: number) => {
  const movies = await loadAdminMovies();
  if (!Number.isInteger(index) || index < 0 || index >= movies.length) {
    return null;
  }
  return movies[index];
};

const findMovie = async (movieId?: string | null, sourceId?: string | null, tmdbId?: number | null) => {
  const movies = await loadAdminMovies();
  return (
    movies.find((movie) => movieId && movie.__movieId === movieId && (!sourceId || movie.sourceIdentifier === sourceId)) ||
    movies.find((movie) => movieId && movie.__movieId === movieId) ||
    movies.find((movie) => tmdbId != null && movie.tmdbId === tmdbId) ||
    null
  );
};

const loadSource = async (identifier: string) => {
  const result = await query(
    `
    SELECT identifier, name, type, url, is_ranked AS "isRankedList", enabled, movie_count AS "movieCount"
    FROM mov_sources
    WHERE identifier = $1
    `,
    [identifier]
  );
  return (result.rows[0] as Record<string, unknown> | undefined) ?? null;
};

const upsertSourceRow = async (row: Record<string, unknown>, previousIdentifier?: string) => {
  const identifier = String(row.identifier || "").trim().toLowerCase();
  const name = String(row.name || "").trim();
  const from = previousIdentifier || identifier;
  await query(
    `
    INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, updated_at)
    VALUES ($1,$2,$3,$4,$5,$6,NOW())
    ON CONFLICT (identifier) DO UPDATE SET
      name = EXCLUDED.name, type = EXCLUDED.type, url = EXCLUDED.url,
      is_ranked = EXCLUDED.is_ranked, enabled = EXCLUDED.enabled, updated_at = NOW()
    `,
    [
      from,
      name,
      row.type === "podcast" ? "podcast" : String(row.type || "url"),
      row.url ?? null,
      Boolean(row.isRankedList ?? row.is_ranked),
      row.enabled !== false
    ]
  );
  if (identifier && identifier !== from) {
    await query(
      `
      UPDATE mov_sources
      SET identifier = $2, name = $3, type = $4, url = $5, is_ranked = $6, enabled = $7, updated_at = NOW()
      WHERE identifier = $1
      `,
      [
        from,
        identifier,
        name,
        row.type === "podcast" ? "podcast" : String(row.type || "url"),
        row.url ?? null,
        Boolean(row.isRankedList ?? row.is_ranked),
        row.enabled !== false
      ]
    );
    await query(`UPDATE mov_movie_sources SET source_id = $2 WHERE source_id = $1`, [from, identifier]);
  }
  await bumpWatchedIt();
};

const deleteSourceRow = async (row: Record<string, unknown>) => {
  const identifier = String(row.identifier || "");
  await query(`DELETE FROM mov_movie_sources WHERE source_id = $1`, [identifier]);
  await query(`DELETE FROM mov_sources WHERE identifier = $1`, [identifier]);
  await bumpWatchedIt();
};

const historyHandlers = {
  movie: {
    restore: async (before: Record<string, unknown>, after: Record<string, unknown> | null) => {
      await upsertAdminMovie(before, (after || before) as unknown as AdminMovie);
    },
    remove: async (after: Record<string, unknown>) => {
      await deleteAdminRow(after as unknown as AdminMovie);
    }
  },
  source: {
    restore: async (before: Record<string, unknown>, after: Record<string, unknown> | null) => {
      await upsertSourceRow(before, after ? String(after.identifier || before.identifier) : undefined);
    },
    remove: async (after: Record<string, unknown>) => {
      await deleteSourceRow(after);
    }
  }
};

const commitMovieItems = async (req: Request, items: unknown[], action: string) => {
  await takeSnapshot(req, { trigger: `before-${action}` });
  let addedCount = 0;
  for (const item of items) {
    const row = item as Record<string, unknown>;
    if (!row?.title || !row?.sourceIdentifier) {
      continue;
    }
    await upsertAdminMovie(row);
    addedCount += 1;
  }
  await recordAudit(req, `catalog.${action}`, { addedCount });
  return { success: true, addedCount, report: { items: [], addedCount } };
};

const applyTmdbDetails = (movie: AdminMovie, details: Record<string, unknown>) => {
  const credits = details.credits as { cast?: Array<Record<string, unknown>>; crew?: Array<Record<string, unknown>> } | undefined;
  const videos = details.videos as { results?: Array<Record<string, unknown>> } | undefined;
  const releaseDates = details.release_dates as { results?: Array<{ iso_3166_1?: string; release_dates?: Array<{ certification?: string }> }> } | undefined;
  const us = releaseDates?.results?.find((row) => row.iso_3166_1 === "US");
  const certification = us?.release_dates?.find((row) => row.certification)?.certification || null;
  const cast = (credits?.cast ?? []).slice(0, 10).map((member) => ({
    id: member.id,
    name: member.name,
    character: member.character ?? null,
    profilePath: member.profile_path ?? null
  }));
  const director = credits?.crew?.find((member) => member.job === "Director");
  const trailer =
    videos?.results?.find((video) => video.site === "YouTube" && video.type === "Trailer") ||
    videos?.results?.find((video) => video.site === "YouTube");
  const releaseDate = details.release_date ? String(details.release_date) : "";
  return {
    ...movie,
    tmdbId: Number(details.id),
    title: String(details.title || movie.title),
    year: releaseDate ? Number(releaseDate.slice(0, 4)) : movie.year,
    overview: (details.overview as string) || movie.overview,
    posterPath: (details.poster_path as string) || movie.posterPath,
    backdropPath: (details.backdrop_path as string) || movie.backdropPath,
    genres: Array.isArray(details.genres) ? (details.genres as Array<{ name: string }>).map((genre) => genre.name) : movie.genres,
    mpaaRating: certification || movie.mpaaRating,
    credits: director || cast.length ? { director: director?.name ?? null, cast } : movie.credits,
    trailer: trailer
      ? {
          id: trailer.id,
          name: trailer.name,
          youtubeKey: trailer.key,
          isOfficial: Boolean(trailer.official)
        }
      : movie.trailer
  };
};

const LIST_FETCH_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
};

const fetchClosetPicksHtml = async (url: string) => fetchClosetPicksPage(url);

const previewIdentifiers = (body: { identifiers?: unknown; sourceIdentifiers?: unknown }) => {
  if (Array.isArray(body?.sourceIdentifiers)) {
    return body.sourceIdentifiers.map(String);
  }
  if (Array.isArray(body?.identifiers)) {
    return body.identifiers.map(String);
  }
  return [];
};

const podcastPreviewItem = (
  episode: { title: string; publishDate: string | null; description: string },
  sourceIdentifier: string,
  existing: Set<string>
) => {
  const prepared = prepareMovieQuery(episode.title, episode.description);
  return {
    title: prepared.title,
    sourceTitle: episode.title,
    sourceIdentifier,
    episodeDate: episode.publishDate,
    podcastEpisodeDescription: episode.description,
    isDuplicate: existing.has(episode.title)
  };
};

router.get("/bootstrap", async (_req, res) => {
  res.json(await loadAdminBootstrap());
});

router.get("/data/health", async (_req, res) => {
  const movies = await loadAdminMovies();
  const sources = await loadAdminSources();
  const discs = physicalMediaStats(movies);
  const theaters = await loadTheaterStayStats(config.tmdbRegion);
  res.json({
    ...adminCatalogHealth(movies, sources),
    withPhysicalMedia: discs.withPhysicalMedia,
    withCriterion: discs.withCriterion,
    with4K: discs.with4K,
    theaterStays: theaters.inTheaters,
    theaterStaysInCatalog: theaters.inCatalog,
    theaterStaysIMAX: theaters.withIMAX
  });
});

router.post("/bootstrap/regenerate", async (req, res) => {
  const snapshot = await takeSnapshot(req, { trigger: "publish" });
  await bumpWatchedIt();
  await recordAudit(req, "catalog.publish", { snapshotId: snapshot.id, movieCount: snapshot.movie_count });
  res.json({ success: true, published: true, snapshotId: snapshot.id });
});

router.post("/sources", async (req, res) => {
  const identifier = String(req.body?.identifier || "").trim().toLowerCase();
  const name = String(req.body?.name || "").trim();
  const url = String(req.body?.url || "").trim();
  if (!identifier || !name) {
    res.status(400).json({ error: "Invalid source payload" });
    return;
  }
  const before = await loadSource(identifier);
  const source = {
    identifier,
    name,
    type: req.body?.type === "podcast" ? "podcast" : "url",
    url: url || null,
    isRankedList: Boolean(req.body?.isRankedList),
    enabled: true
  };
  await snapshotIfNeeded(req, "editor");
  await upsertSourceRow(source);
  const after = await loadSource(identifier);
  await recordAudit(req, before ? "source.update" : "source.create", { identifier }, before, after);
  res.json({ success: true, source: { identifier, name, type: source.type, url, isRankedList: source.isRankedList } });
});

router.put("/sources/:identifier", async (req, res) => {
  const existing = String(req.params.identifier);
  const identifier = String(req.body?.identifier || existing).trim().toLowerCase();
  const name = String(req.body?.name || "").trim();
  const before = await loadSource(existing);
  await snapshotIfNeeded(req, "editor");
  await upsertSourceRow(
    {
      identifier,
      name,
      type: req.body?.type === "podcast" ? "podcast" : "url",
      url: req.body?.url ?? null,
      isRankedList: Boolean(req.body?.isRankedList)
    },
    existing
  );
  const after = await loadSource(identifier);
  await recordAudit(req, "source.update", { identifier, previousIdentifier: existing }, before, after);
  res.json({ success: true, source: { identifier, name } });
});

router.post("/movies", async (req, res) => {
  if (!req.body?.title || !req.body?.sourceIdentifier) {
    res.status(400).json({ error: "Missing required fields" });
    return;
  }
  await snapshotIfNeeded(req, "editor");
  const id = await upsertAdminMovie(req.body);
  const after = await findMovie(id, String(req.body.sourceIdentifier));
  await recordAudit(req, "movie.create", { id, title: req.body.title }, null, after);
  res.json({ success: true });
});

router.put("/movies/:index", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row) {
    res.status(400).json({ error: "Invalid index" });
    return;
  }
  if (!req.body?.title || !req.body?.sourceIdentifier) {
    res.status(400).json({ error: "Missing required fields" });
    return;
  }
  const before = clone(row);
  await snapshotIfNeeded(req, "editor");
  const id = await upsertAdminMovie(req.body, row);
  const after = await findMovie(id, String(req.body.sourceIdentifier));
  await recordAudit(req, "movie.update", { id, title: req.body.title }, before, after);
  res.json({ success: true });
});

router.delete("/movies/:index", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row) {
    res.status(400).json({ error: "Invalid index" });
    return;
  }
  const before = clone(row);
  await snapshotIfNeeded(req, "editor");
  await deleteAdminRow(row);
  await recordAudit(req, "movie.delete", { id: row.__movieId, title: row.title }, before, null);
  res.json({ success: true });
});

router.post("/movies/:index/streaming/refresh", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row?.tmdbId) {
    res.status(400).json({ error: "Movie has no TMDB ID" });
    return;
  }
  const before = clone(row);
  const providers = await fetchStreamingServices(row.tmdbId, config.tmdbApiKey, String(req.body?.region || config.tmdbRegion));
  await upsertAdminMovie({ ...row, streamingServices: providers }, row);
  const after = await findMovie(row.__movieId, row.sourceIdentifier);
  await recordAudit(req, "movie.streaming", { id: row.__movieId, tmdbId: row.tmdbId }, before, after);
  res.json({ success: true, count: providers.length, streamingServices: providers });
});

router.post("/streaming/refresh-all", async (req, res) => {
  const movies = await loadAdminMovies();
  await takeSnapshot(req, { trigger: "before-streaming-refresh" });
  const seen = new Set<string>();
  let updatedCount = 0;
  let skippedCount = 0;
  let failedCount = 0;
  let unchangedCount = 0;
  const items: Array<{ title: string; tmdbId: number | null; status: string; error?: string }> = [];
  for (const movie of movies) {
    if (!movie.tmdbId || !movie.__movieId || seen.has(movie.__movieId)) {
      if (!movie.tmdbId) {
        skippedCount += 1;
      }
      continue;
    }
    seen.add(movie.__movieId);
    try {
      const providers = await fetchStreamingServices(movie.tmdbId, config.tmdbApiKey, String(req.body?.region || config.tmdbRegion));
      const before = JSON.stringify(movie.streamingServices ?? []);
      await upsertAdminMovie({ ...movie, streamingServices: providers }, movie, { bump: false, touch: false });
      if (before !== JSON.stringify(providers)) {
        updatedCount += 1;
        items.push({ title: movie.title, tmdbId: movie.tmdbId, status: "updated" });
      } else {
        unchangedCount += 1;
        items.push({ title: movie.title, tmdbId: movie.tmdbId, status: "unchanged" });
      }
    } catch (error) {
      failedCount += 1;
      items.push({
        title: movie.title,
        tmdbId: movie.tmdbId,
        status: "failed",
        error: error instanceof Error ? error.message : "failed"
      });
    }
  }
  await bumpWatchedIt();
  await recordAudit(req, "catalog.streaming-refresh", { updatedCount, skippedCount, failedCount, unchangedCount });
  res.json({
    success: true,
    updatedCount,
    skippedCount,
    failedCount,
    report: { totalCount: seen.size, updatedCount, unchangedCount, skippedCount, failedCount, items }
  });
});

router.get("/tmdb/search", async (req, res) => {
  const term = String(req.query.query || "");
  if (!term || !config.tmdbApiKey) {
    res.status(400).json({ error: "Missing query" });
    return;
  }
  const prepared = prepareMovieQuery(term);
  const year = req.query.year ? Number(req.query.year) : prepared.year ?? undefined;
  const results = await searchTmdbMovies(prepared.query || term, year, config.tmdbApiKey);
  res.json({ results, query: prepared.query, year: year ?? null });
});

router.post("/tmdb/apply/:index", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row) {
    res.status(400).json({ error: "Invalid index" });
    return;
  }
  const tmdbId = Number(req.body?.tmdbId);
  if (!tmdbId || !config.tmdbApiKey) {
    res.status(400).json({ error: "Missing tmdbId" });
    return;
  }
  const before = clone(row);
  const details = await fetchTmdbMovieDetails(tmdbId, config.tmdbApiKey);
  const next = applyTmdbDetails(row, details);
  await snapshotIfNeeded(req, "editor");
  await upsertAdminMovie(next, row);
  const after = await findMovie(row.__movieId, row.sourceIdentifier, tmdbId);
  await recordAudit(req, "movie.tmdb", { id: row.__movieId, tmdbId }, before, after);
  res.json({ success: true, movie: next });
});

router.get("/physical-media/stats", async (_req, res) => {
  res.json(physicalMediaStats(await loadAdminMovies()));
});

router.post("/physical-media/update", async (req, res) => {
  const tmdbId = Number(req.body?.tmdbId);
  const media = normalizePhysicalMedia(req.body);
  if (!tmdbId || !media) {
    res.status(400).json({ error: "tmdbId and physical media required." });
    return;
  }
  const before = await findMovie(null, null, tmdbId);
  await snapshotIfNeeded(req, "editor");
  await applyPhysicalMediaOverlay({ [String(tmdbId)]: media });
  const after = await findMovie(before?.__movieId, before?.sourceIdentifier, tmdbId);
  await recordAudit(req, "movie.physical-media", { tmdbId }, before, after);
  res.json({ success: true, physicalMedia: media });
});

router.post("/physical-media/clear", async (req, res) => {
  await takeSnapshot(req, { trigger: "before-physical-clear" });
  const clearedCount = await clearInferredPhysicalMedia();
  await bumpWatchedIt();
  await recordAudit(req, "catalog.physical-clear", { clearedCount });
  res.json({ success: true, clearedCount });
});

router.post("/physical-media/enrich", async (req, res) => {
  const overwriteManual = Boolean(req.body?.overwriteManual);
  const dryRun = Boolean(req.body?.dryRun);
  if (!dryRun) {
    await takeSnapshot(req, { trigger: "before-physical-enrich" });
  }
  const movies = await loadAdminMovies();
  const index = await fetchWikidataPhysicalMediaIndex();
  seedCriterionFromSources(movies, index);
  seedCurated4K(index);
  const catalogIndex = filterIndexToCatalog(index, movies);
  const overlay = overlayFromIndex(catalogIndex);
  const updatedCount = dryRun ? 0 : await applyPhysicalMediaOverlay(overlay.byTmdbId, { overwriteManual });
  if (updatedCount > 0) {
    await bumpWatchedIt();
  }
  await recordAudit(req, "catalog.physical-enrich", {
    updatedCount,
    overlayCount: Object.keys(overlay.byTmdbId).length
  });
  const nextMovies = await loadAdminMovies();
  res.json({
    success: true,
    dryRun,
    updatedCount,
    overlayCount: Object.keys(overlay.byTmdbId).length,
    stats: physicalMediaStats(nextMovies)
  });
});

const catalogTmdbIds = async () => {
  const catalog = await query(`SELECT tmdb_id FROM mov_movies WHERE tmdb_id IS NOT NULL`);
  return new Set(
    catalog.rows
      .map((row) => Number(row.tmdb_id))
      .filter((id) => Number.isFinite(id))
  );
};

router.get("/theater-stays/stats", async (_req, res) => {
  res.json(await loadTheaterStayStats(config.tmdbRegion));
});

router.get("/theater-stays/:tmdbId", async (req, res) => {
  const tmdbId = Number(req.params.tmdbId);
  if (!Number.isFinite(tmdbId) || tmdbId <= 0) {
    res.status(400).json({ error: "Invalid TMDB id." });
    return;
  }
  res.json({ success: true, theaterStay: await findTheaterStay(config.tmdbRegion, tmdbId) });
});

router.post("/theater-stays/refresh", async (req, res) => {
  if (!config.tmdbApiKey) {
    res.status(503).json({ error: "TMDB API key required to refresh theater stays." });
    return;
  }
  await takeSnapshot(req, { trigger: "before-theater-refresh" });
  const payload = await resolveNowPlaying(config.tmdbApiKey, config.tmdbRegion, await catalogTmdbIds(), {
    force: true
  });
  const stats = await loadTheaterStayStats(config.tmdbRegion);
  await recordAudit(req, "catalog.theater-refresh", {
    region: config.tmdbRegion,
    inTheaters: stats.inTheaters,
    withIMAX: stats.withIMAX,
    source: payload.source
  });
  res.json({ success: true, ...payload, stats });
});

router.post("/theater-stays/clear", async (req, res) => {
  await takeSnapshot(req, { trigger: "before-theater-clear" });
  const clearedCount = await clearInferredTheaterStays(config.tmdbRegion);
  await recordAudit(req, "catalog.theater-clear", { clearedCount, region: config.tmdbRegion });
  res.json({ success: true, clearedCount, stats: await loadTheaterStayStats(config.tmdbRegion) });
});

router.post("/theater-stays/update", async (req, res) => {
  const update = normalizeTheaterStayUpdate(req.body);
  if (!update) {
    res.status(400).json({ error: "tmdbId required." });
    return;
  }
  const before = await findTheaterStay(config.tmdbRegion, update.tmdbId);
  const catalogIds = await catalogTmdbIds();
  const after = await upsertManualTheaterStay(config.tmdbRegion, {
    ...update,
    inCatalog: catalogIds.has(update.tmdbId)
  });
  await recordAudit(req, "catalog.theater-stay", { tmdbId: update.tmdbId }, before, after);
  res.json({ success: true, theaterStay: after });
});

router.post("/theater-stays/ticket-links", async (req, res) => {
  const tmdbId = Number(req.body?.tmdbId);
  if (!Number.isFinite(tmdbId) || tmdbId <= 0) {
    res.status(400).json({ error: "tmdbId required." });
    return;
  }
  const before = await findTheaterStay(config.tmdbRegion, tmdbId);
  const catalogIds = await catalogTmdbIds();
  const after = await upsertTheaterTicketLinks(config.tmdbRegion, {
    tmdbId,
    title: typeof req.body?.title === "string" ? req.body.title : before?.title,
    ticketLinks: normalizeTicketLinks(req.body?.ticketLinks),
    inCatalog: catalogIds.has(tmdbId)
  });
  await recordAudit(req, "catalog.theater-ticket-links", { tmdbId }, before, after);
  res.json({ success: true, theaterStay: after });
});

router.get("/oscar-awards/stats", async (_req, res) => {
  const movies = await loadAdminMovies();
  const unique = new Map<string, AdminMovie>();
  for (const movie of movies) {
    if (movie.__movieId && !unique.has(movie.__movieId)) {
      unique.set(movie.__movieId, movie);
    }
  }
  const list = [...unique.values()];
  const withAwards = list.filter((movie) => movie.oscarAwards);
  res.json({
    totalMovies: list.length,
    moviesWithTmdb: list.filter((movie) => movie.tmdbId).length,
    moviesWithAwards: withAwards.length,
    moviesWithWins: withAwards.filter((movie) => Number((movie.oscarAwards as { totalWins?: number })?.totalWins || 0) > 0).length,
    moviesWithNominations: withAwards.filter((movie) => Number((movie.oscarAwards as { totalNominations?: number })?.totalNominations || 0) > 0).length,
    eligibleForEnrichment: list.filter((movie) => movie.tmdbId && !movie.oscarAwards).length,
    withCategoryDetail: withAwards.filter((movie) => {
      const awards = movie.oscarAwards as { wins?: unknown[]; nominations?: unknown[] };
      return (awards.wins?.length || 0) > 0 || (awards.nominations?.length || 0) > 0;
    }).length,
    eligibleForWikidata: withAwards.filter((movie) => {
      const awards = movie.oscarAwards as { wins?: unknown[]; nominations?: unknown[] };
      return (awards.wins?.length || 0) === 0 && (awards.nominations?.length || 0) === 0;
    }).length
  });
});

router.post("/oscar-awards/clear", async (req, res) => {
  await takeSnapshot(req, { trigger: "before-oscar-clear" });
  const clearedCount = await clearOscarAwards();
  await bumpWatchedIt();
  await recordAudit(req, "catalog.oscar-clear", { clearedCount });
  res.json({ success: true, clearedCount });
});

router.post("/oscar-awards/enrich", async (req, res) => {
  const omdbApiKey = String(req.body?.omdbApiKey || config.omdbApiKey || "").trim();
  if (!omdbApiKey) {
    res.status(400).json({ error: "omdbApiKey required" });
    return;
  }
  const offset = Math.max(Number(req.body?.offset) || 0, 0);
  const dryRun = Boolean(req.body?.dryRun);
  if (offset === 0 && !dryRun) {
    await takeSnapshot(req, { trigger: "before-oscar-enrich" });
  }
  const movies = await loadAdminMovies();
  const result = await runOscarOmdbBatch(
    movies,
    {
      mode: String(req.body?.mode || "missing"),
      delayMs: Number(req.body?.delayMs ?? 150),
      dryRun,
      batchSize: Number(req.body?.batchSize) || 100,
      offset
    },
    {
      fetchImdbId: (tmdbId) => fetchImdbIdFromTmdb(tmdbId, config.tmdbApiKey),
      fetchOmdbByImdb: (imdbId) => fetchOmdbAwards(imdbId, omdbApiKey),
      fetchOmdbByTitle: (title, year) => fetchOmdbAwardsByTitle(title, year, omdbApiKey),
      persist: async (movie, awards, imdbId) => {
        if (movie.tmdbId) {
          await updateOscarAwardsForTmdb(movie.tmdbId, awards, imdbId);
        }
      }
    }
  );
  if (!result.dryRun && result.enrichedCount > 0) {
    await bumpWatchedIt();
  }
  await recordAudit(req, "catalog.oscar-enrich", {
    offset,
    enrichedCount: result.enrichedCount,
    abortedDueToKey: result.abortedDueToKey
  });
  res.json(result);
});

router.post("/oscar-awards/wikidata-enrich", async (req, res) => {
  const offset = Math.max(Number(req.body?.offset) || 0, 0);
  if (offset === 0) {
    await takeSnapshot(req, { trigger: "before-oscar-wikidata" });
  }
  const movies = await loadAdminMovies();
  const result = await runOscarWikidataBatch(
    movies,
    {
      mode: String(req.body?.mode || "missing"),
      delayMs: Number(req.body?.delayMs ?? 300),
      batchSize: Number(req.body?.batchSize) || 50,
      offset
    },
    {
      fetchImdbId: (tmdbId) => fetchImdbIdFromTmdb(tmdbId, config.tmdbApiKey),
      fetchWikidata: fetchWikidataOscars,
      persist: async (movie, awards, imdbId) => {
        if (movie.tmdbId) {
          await updateOscarAwardsForTmdb(movie.tmdbId, awards, imdbId);
        }
      },
      persistImdb: async (movie, imdbId) => {
        if (movie.tmdbId) {
          await updateImdbIdForTmdb(movie.tmdbId, imdbId);
        }
      }
    }
  );
  if (result.enrichedCount > 0) {
    await bumpWatchedIt();
  }
  await recordAudit(req, "catalog.oscar-wikidata", {
    offset,
    enrichedCount: result.enrichedCount
  });
  res.json(result);
});

router.post("/oscar-awards/wikidata-single", async (req, res) => {
  const tmdbId = Number(req.body?.tmdbId);
  const movies = await loadAdminMovies();
  const target =
    (tmdbId ? movies.find((movie) => movie.tmdbId === tmdbId) : null) ||
    (await movieAt(Number(req.body?.index ?? -1)));
  if (!target) {
    res.status(404).json({ error: "Movie not found" });
    return;
  }
  try {
    let imdbId = String(req.body?.imdbId || target.imdbId || "");
    if (!imdbId && target.tmdbId && config.tmdbApiKey) {
      imdbId = (await fetchImdbIdFromTmdb(target.tmdbId, config.tmdbApiKey)) || "";
      if (imdbId && target.tmdbId) {
        await updateImdbIdForTmdb(target.tmdbId, imdbId);
      }
    }
    if (!imdbId) {
      res.json({ success: false, reason: "no-imdb", title: target.title });
      return;
    }
    const wikidata = await fetchWikidataOscars(imdbId);
    if (!wikidata) {
      res.json({ success: true, reason: "no-wikidata-oscars", title: target.title });
      return;
    }
    const merged = mergeWikidataIntoOscar(target.oscarAwards as OscarAwards | null, wikidata);
    if (target.tmdbId && merged) {
      const before = clone(target);
      await updateOscarAwardsForTmdb(target.tmdbId, merged, imdbId);
      await bumpWatchedIt();
      const after = await findMovie(target.__movieId, target.sourceIdentifier, target.tmdbId);
      await recordAudit(req, "movie.oscar", { id: target.__movieId, tmdbId: target.tmdbId, imdbId }, before, after);
    }
    res.json({ success: true, title: target.title, oscarAwards: merged });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Wikidata lookup failed",
      title: target.title
    });
  }
});

router.get("/dedupe/preview", async (_req, res) => {
  const movies = await loadAdminMovies();
  const sources = await loadAdminSources();
  res.json({ groups: buildDedupeGroups(movies, sources) });
});

router.post("/dedupe/commit", async (req, res) => {
  const movies = await loadAdminMovies();
  const remove = new Set<number>(Array.isArray(req.body?.indexes) ? req.body.indexes.map(Number) : []);
  await takeSnapshot(req, { trigger: "before-dedupe" });
  let removed = 0;
  for (const index of [...remove].sort((a, b) => b - a)) {
    const row = movies[index];
    if (!row) {
      continue;
    }
    await deleteAdminRow(row);
    removed += 1;
  }
  await recordAudit(req, "catalog.dedupe", { removedCount: removed });
  res.json({ success: true, removedCount: removed });
});

router.post("/feeds/refresh-all", async (req, res) => {
  await takeSnapshot(req, { trigger: "before-feeds-refresh" });
  const purged = await purgePodcastNoiseMovies();
  const sources = await loadAdminSources();
  let addedCount = 0;
  let skippedCount = 0;
  for (const source of sources.filter((item) => item.type === "podcast" && item.url)) {
    const result = await refreshPodcastSource(source.identifier);
    addedCount += result.addedCount;
    skippedCount += result.skippedCount;
  }
  await recordAudit(req, "catalog.feeds-refresh", {
    addedCount,
    skippedCount,
    purgedMovies: purged.purgedMovies,
    purgedLinks: purged.purgedLinks
  });
  res.json({
    success: true,
    addedCount,
    skippedCount,
    purgedMovies: purged.purgedMovies,
    purgedLinks: purged.purgedLinks
  });
});

router.post("/podcasts/refresh", async (req, res) => {
  const sourceIdentifier = String(req.body?.sourceIdentifier || "");
  if (!sourceIdentifier) {
    res.status(400).json({ error: "Missing sourceIdentifier" });
    return;
  }
  await snapshotIfNeeded(req, "editor");
  const result = await refreshPodcastSource(sourceIdentifier);
  await recordAudit(req, "catalog.podcast-refresh", { sourceIdentifier, ...result });
  res.json(result);
});

router.post("/feeds/preview", async (req, res) => {
  const identifiers = previewIdentifiers(req.body || {});
  const sources = await loadAdminSources();
  const movies = await loadAdminMovies();
  const items: unknown[] = [];
  for (const identifier of identifiers) {
    const source = sources.find((row) => row.identifier === identifier);
    if (!source?.url) {
      continue;
    }
    try {
      const xml = await fetchText(source.url);
      const parsed = parseRssFeed(xml);
      const existing = new Set(
        movies.filter((movie) => movie.sourceIdentifier === identifier).map((movie) => movie.sourceTitle || movie.title)
      );
      for (const episode of parsed.episodes.slice(0, 40)) {
        const prepared = prepareMovieQuery(episode.title, episode.description);
        if (!prepared.title || shouldSkipPodcastNoise(identifier, episode.title, prepared.title)) {
          continue;
        }
        items.push(podcastPreviewItem(episode, identifier, existing));
      }
    } catch {
      // skip broken feeds
    }
  }
  res.json({ items, summary: { count: items.length } });
});

router.post("/podcasts/latest/preview", async (req, res) => {
  const sources = await loadAdminSources();
  const requested = previewIdentifiers(req.body || {});
  const identifiers = requested.length
    ? requested
    : sources.filter((source) => source.type === "podcast").map((source) => source.identifier);
  const movies = await loadAdminMovies();
  const items: unknown[] = [];
  for (const identifier of identifiers) {
    const source = sources.find((row) => row.identifier === identifier);
    if (!source?.url) {
      continue;
    }
    try {
      const xml = await fetchText(source.url);
      const parsed = parseRssFeed(xml);
      const existing = new Set(
        movies.filter((movie) => movie.sourceIdentifier === identifier).map((movie) => movie.sourceTitle || movie.title)
      );
      for (const episode of parsed.episodes.slice(0, 20)) {
        const prepared = prepareMovieQuery(episode.title, episode.description);
        if (!prepared.title || shouldSkipPodcastNoise(identifier, episode.title, prepared.title)) {
          continue;
        }
        items.push(podcastPreviewItem(episode, identifier, existing));
      }
    } catch {
      // skip
    }
  }
  res.json({ items, summary: { count: items.length } });
});

router.post("/ingest/preview", async (req, res) => {
  const url = String(req.body?.url || "");
  const sourceType = String(req.body?.sourceType || "");
  const identifier = String(req.body?.identifier || "");
  if (!url) {
    res.status(400).json({ error: "url required" });
    return;
  }
  if (sourceType === "podcast") {
    const xml = await fetchText(url);
    const parsed = parseRssFeed(xml);
    const movies = await loadAdminMovies();
    const existing = new Set(
      movies.filter((movie) => movie.sourceIdentifier === identifier).map((movie) => movie.sourceTitle || movie.title)
    );
    const items = parsed.episodes
      .map((episode) => podcastPreviewItem(episode, identifier, existing))
      .filter((item) => item.title && !shouldSkipPodcastNoise(identifier, item.sourceTitle, item.title));
    res.json({ items, summary: { count: items.length } });
    return;
  }
  if (isClosetPicksUrl(url)) {
    const html = await fetchClosetPicksHtml(url);
    const previewLimit = Math.min(Number(req.body?.episodeLimit) || 12, 40);
    const episodes = isClosetPicksIndexUrl(url) ? parseClosetPicksIndex(html) : [];
    const visits = [];
    if (episodes.length) {
      for (const episode of episodes.slice(0, previewLimit)) {
        try {
          const episodeHtml = await fetchClosetPicksHtml(episode.episodeUrl);
          visits.push({ episode, films: parseClosetPicksEpisode(episodeHtml) });
        } catch {
          // skip unreachable episode pages
        }
      }
    } else {
      visits.push({
        episode: {
          guestName: "",
          episodeTitle: "",
          episodeUrl: url,
          date: null
        },
        films: parseClosetPicksEpisode(html)
      });
    }
    const items = collapseClosetPicks(visits).map((film) => ({
      ...toClosetPicksCatalogItem(film, identifier || "criterion-closet-picks"),
      isRankedList: true
    }));
    res.json({
      items,
      summary: { count: items.length, episodes: episodes.length, fetchedEpisodes: visits.length }
    });
    return;
  }
  const html = await fetchText(url, LIST_FETCH_HEADERS);
  const isRanked = Boolean(req.body?.isRankedList);
  const items = scrapeListItems(url, html).map((item) => ({
    title: item.title,
    sourceTitle: item.title,
    rank: isRanked ? item.rank : null,
    sourceIdentifier: identifier || null
  }));
  res.json({ items, summary: { count: items.length } });
});

router.post("/ingest/enrich", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  const enriched = [];
  for (const item of items.slice(0, 40)) {
    try {
      let prepared = prepareMovieQuery(String(item.title || ""), item.podcastEpisodeDescription);
      if (isClosetPicksSource(item.sourceIdentifier)) {
        let year = item.year != null ? Number(item.year) : null;
        let director = item.director ? String(item.director) : null;
        let originalTitle = item.originalTitle ? String(item.originalTitle) : null;
        if (item.filmUrl && (!year || !director)) {
          try {
            const filmHtml = await fetchClosetPicksPage(String(item.filmUrl));
            const parsed = parseCriterionFilmPage(filmHtml);
            year = year || parsed.year;
            director = director || parsed.director;
            originalTitle = originalTitle || parsed.originalTitle;
          } catch {
            // keep card metadata
          }
        }
        prepared = prepareClosetPicksQuery({
          title: String(item.title || ""),
          year,
          director,
          originalTitle
        });
      }
      const match = await resolveTmdbMatch(prepared);
      if (!match) {
        enriched.push({ ...item, title: prepared.title || item.title, sourceTitle: item.sourceTitle || item.title, status: "missing" });
        continue;
      }
      const details = await fetchTmdbMovieDetails(match.id, config.tmdbApiKey);
      const merged = applyTmdbDetails(
        {
          title: prepared.title || String(item.title || ""),
          year: null,
          tmdbId: match.id,
          sourceIdentifier: item.sourceIdentifier ?? null,
          sourceTitle: item.sourceTitle ?? item.title,
          rank: item.rank ?? null,
          mpaaRating: null,
          episodeDate: item.episodeDate ?? null,
          overview: null,
          posterPath: null,
          backdropPath: null,
          genres: [],
          streamingServices: [],
          credits: null,
          trailer: null,
          oscarAwards: null,
          physicalMedia: null,
          podcastEpisodeDescription: item.podcastEpisodeDescription ?? null
        },
        details
      );
      enriched.push({
        ...item,
        ...merged,
        sourceTitle: item.sourceTitle ?? item.title,
        status: determineItemStatus(merged)
      });
    } catch {
      enriched.push({ ...item, status: "missing" });
    }
  }
  res.json({ items: enriched });
});

router.post("/ingest/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  res.json(await commitMovieItems(req, items, "ingest"));
});

router.post("/feeds/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  res.json(await commitMovieItems(req, items, "feeds"));
});

router.post("/podcasts/latest/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  res.json(await commitMovieItems(req, items, "podcasts"));
});

router.get("/themes", async (_req, res) => {
  res.json([]);
});

router.post("/themes", async (_req, res) => {
  res.json({ success: true });
});

router.get("/design-system/tokens", async (_req, res) => {
  res.json({});
});

router.get("/design-system/settings", async (_req, res) => {
  res.json({});
});

router.get("/live/changes", async (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.write(": connected\n\n");
  const timer = setInterval(() => {
    res.write(": ping\n\n");
  }, 25000);
  req.on("close", () => {
    clearInterval(timer);
  });
});

router.get("/history", async (_req, res) => {
  res.json({
    snapshots: await listSnapshots(40),
    audit: await listAudit(80)
  });
});

router.post("/history/snapshots", async (req, res) => {
  const label = typeof req.body?.label === "string" ? req.body.label : "";
  const snapshot = await takeSnapshot(req, { trigger: "manual", label: label || null });
  await recordAudit(req, "catalog.snapshot", { snapshotId: snapshot.id, label: snapshot.label });
  res.json({ success: true, snapshot });
});

router.post("/history/snapshots/:id/restore", async (req, res) => {
  try {
    const result = await restoreSnapshot(req, String(req.params.id));
    res.json({ success: true, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Restore failed.";
    res.status(message.includes("not found") ? 404 : 400).json({ error: message });
  }
});

router.post("/history/snapshots/:id/restore-physical", async (req, res) => {
  try {
    const result = await restorePhysicalMediaFromSnapshot(req, String(req.params.id));
    res.json({ success: true, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Physical restore failed.";
    res.status(message.includes("not found") ? 404 : 400).json({ error: message });
  }
});

router.post("/history/audit/:id/revert", async (req, res) => {
  try {
    const result = await revertAudit(req, String(req.params.id), historyHandlers);
    res.json({ success: true, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Revert failed.";
    res.status(message.includes("not found") ? 404 : 400).json({ error: message });
  }
});

const refreshPodcastSource = async (sourceIdentifier: string) => {
  const sources = await loadAdminSources();
  const source = sources.find((row) => row.identifier === sourceIdentifier);
  if (!source?.url || source.type !== "podcast") {
    throw new Error("Invalid podcast source");
  }
  const movies = await loadAdminMovies();
  const existing = new Set(
    movies.filter((movie) => movie.sourceIdentifier === sourceIdentifier).map((movie) => movie.sourceTitle || movie.title)
  );
  const xml = await fetchText(source.url);
  const parsed = parseRssFeed(xml);
  let addedCount = 0;
  let skippedCount = 0;
  let enrichedCount = 0;
  for (const episode of parsed.episodes.slice(0, 40)) {
    const result = await ingestPodcastEpisode({
      title: episode.title,
      sourceTitle: episode.title,
      sourceIdentifier,
      episodeDate: episode.publishDate,
      description: episode.description,
      existingTitles: existing,
      bump: false
    });
    if (result.skipped) {
      skippedCount += 1;
      continue;
    }
    addedCount += 1;
    if (result.reason === "enriched" || result.reason === "light") {
      enrichedCount += 1;
    }
  }
  if (addedCount > 0) {
    await bumpWatchedIt();
  }
  return { addedCount, skippedCount, enrichedCount, addedMovies: [] };
};

export default router;
