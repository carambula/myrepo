import { Router } from "express";
import { query } from "../db.js";
import { config } from "../config.js";
import { fetchJson, fetchText } from "../lib/http.js";
import { fetchStreamingServices, fetchTmdbMovieDetails, searchTmdbMovies } from "../lib/tmdb.js";
import { parseRssFeed } from "../lib/rss.js";
import { applyPhysicalMediaOverlay } from "../lib/catalog-import.js";
import { normalizePhysicalMedia } from "../lib/physical-media.js";
import {
  adminCatalogHealth,
  buildDedupeGroups,
  bumpWatchedIt,
  deleteAdminRow,
  loadAdminBootstrap,
  loadAdminMovies,
  loadAdminSources,
  upsertAdminMovie,
  type AdminMovie
} from "../lib/admin-catalog.js";

const router = Router();

const movieAt = async (index: number) => {
  const movies = await loadAdminMovies();
  if (!Number.isInteger(index) || index < 0 || index >= movies.length) {
    return null;
  }
  return movies[index];
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

router.get("/bootstrap", async (_req, res) => {
  res.json(await loadAdminBootstrap());
});

router.get("/data/health", async (_req, res) => {
  const movies = await loadAdminMovies();
  const sources = await loadAdminSources();
  res.json(adminCatalogHealth(movies, sources));
});

router.post("/bootstrap/regenerate", async (_req, res) => {
  await bumpWatchedIt();
  res.json({ success: true, published: true });
});

router.post("/sources", async (req, res) => {
  const identifier = String(req.body?.identifier || "").trim().toLowerCase();
  const name = String(req.body?.name || "").trim();
  const url = String(req.body?.url || "").trim();
  if (!identifier || !name) {
    res.status(400).json({ error: "Invalid source payload" });
    return;
  }
  await query(
    `
    INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, updated_at)
    VALUES ($1,$2,$3,$4,$5,TRUE,NOW())
    ON CONFLICT (identifier) DO UPDATE SET
      name = EXCLUDED.name, type = EXCLUDED.type, url = EXCLUDED.url, is_ranked = EXCLUDED.is_ranked, updated_at = NOW()
    `,
    [identifier, name, req.body?.type === "podcast" ? "podcast" : "url", url || null, Boolean(req.body?.isRankedList)]
  );
  await bumpWatchedIt();
  res.json({ success: true, source: { identifier, name, type: req.body?.type === "podcast" ? "podcast" : "url", url, isRankedList: Boolean(req.body?.isRankedList) } });
});

router.put("/sources/:identifier", async (req, res) => {
  const existing = String(req.params.identifier);
  const identifier = String(req.body?.identifier || existing).trim().toLowerCase();
  const name = String(req.body?.name || "").trim();
  await query(
    `
    UPDATE mov_sources
    SET identifier = $2, name = $3, type = $4, url = $5, is_ranked = $6, updated_at = NOW()
    WHERE identifier = $1
    `,
    [existing, identifier, name, req.body?.type === "podcast" ? "podcast" : "url", req.body?.url ?? null, Boolean(req.body?.isRankedList)]
  );
  if (identifier !== existing) {
    await query(`UPDATE mov_movie_sources SET source_id = $2 WHERE source_id = $1`, [existing, identifier]);
  }
  await bumpWatchedIt();
  res.json({ success: true, source: { identifier, name } });
});

router.post("/movies", async (req, res) => {
  if (!req.body?.title || !req.body?.sourceIdentifier) {
    res.status(400).json({ error: "Missing required fields" });
    return;
  }
  await upsertAdminMovie(req.body);
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
  await upsertAdminMovie(req.body, row);
  res.json({ success: true });
});

router.delete("/movies/:index", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row) {
    res.status(400).json({ error: "Invalid index" });
    return;
  }
  await deleteAdminRow(row);
  res.json({ success: true });
});

router.post("/movies/:index/streaming/refresh", async (req, res) => {
  const row = await movieAt(Number(req.params.index));
  if (!row?.tmdbId) {
    res.status(400).json({ error: "Movie has no TMDB ID" });
    return;
  }
  const providers = await fetchStreamingServices(row.tmdbId, config.tmdbApiKey, String(req.body?.region || config.tmdbRegion));
  await upsertAdminMovie({ ...row, streamingServices: providers }, row);
  res.json({ success: true, count: providers.length, streamingServices: providers });
});

router.post("/streaming/refresh-all", async (req, res) => {
  const movies = await loadAdminMovies();
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
      await upsertAdminMovie({ ...movie, streamingServices: providers }, movie, { bump: false });
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
  const year = req.query.year ? Number(req.query.year) : undefined;
  const results = await searchTmdbMovies(term, year, config.tmdbApiKey);
  res.json({ results });
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
  const details = await fetchTmdbMovieDetails(tmdbId, config.tmdbApiKey);
  const next = applyTmdbDetails(row, details);
  await upsertAdminMovie(next, row);
  res.json({ success: true, movie: next });
});

router.get("/physical-media/stats", async (_req, res) => {
  const movies = await loadAdminMovies();
  const withMedia = movies.filter((movie) => movie.physicalMedia);
  res.json({
    totalMovies: movies.length,
    withPhysicalMedia: withMedia.length,
    withCriterion: withMedia.filter((movie) => (movie.physicalMedia as { hasCriterion?: boolean })?.hasCriterion).length,
    with4K: withMedia.filter((movie) => (movie.physicalMedia as { has4K?: boolean })?.has4K).length,
    withBluRay: withMedia.filter((movie) => (movie.physicalMedia as { hasBluRay?: boolean })?.hasBluRay).length,
    manualOverrides: withMedia.filter((movie) => (movie.physicalMedia as { manualOverride?: boolean })?.manualOverride).length
  });
});

router.post("/physical-media/update", async (req, res) => {
  const tmdbId = Number(req.body?.tmdbId);
  const media = normalizePhysicalMedia(req.body);
  if (!tmdbId || !media) {
    res.status(400).json({ error: "tmdbId and physical media required." });
    return;
  }
  await applyPhysicalMediaOverlay({ [String(tmdbId)]: media });
  res.json({ success: true, physicalMedia: media });
});

router.post("/physical-media/clear", async (_req, res) => {
  await query(`UPDATE mov_movies SET physical_media = NULL, last_updated = NOW() WHERE COALESCE((physical_media->>'manualOverride')::boolean, false) = false`);
  await bumpWatchedIt();
  res.json({ success: true });
});

router.post("/physical-media/enrich", async (_req, res) => {
  res.json({
    success: true,
    updatedCount: 0,
    overlayCount: 0,
    message: "Use Cloud Jobs or POST /v1/admin/mov/physical-media with the overlay file. Live Wikidata enrich can take minutes."
  });
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

router.post("/oscar-awards/clear", async (_req, res) => {
  await query(`UPDATE mov_movies SET oscar_awards = NULL, last_updated = NOW()`);
  await bumpWatchedIt();
  res.json({ success: true });
});

router.post("/oscar-awards/enrich", async (_req, res) => {
  res.json({ success: true, updatedCount: 0, message: "Oscar text enrich is available from Wikidata single/bulk endpoints." });
});

router.post("/oscar-awards/wikidata-single", async (req, res) => {
  const row = await movieAt(Number(req.body?.index ?? -1));
  const imdbId = String(req.body?.imdbId || row?.imdbId || "");
  if (!imdbId) {
    res.status(400).json({ error: "imdbId required" });
    return;
  }
  const sparql = `
SELECT ?awardLabel ?type ?recipientLabel WHERE {
  ?film wdt:P345 "${imdbId}" .
  { ?film p:P166 ?stmt . ?stmt ps:P166 ?award . OPTIONAL { ?stmt pq:P1346 ?recipient . } BIND("won" AS ?type) }
  UNION
  { ?film p:P1411 ?stmt . ?stmt ps:P1411 ?award . OPTIONAL { ?stmt pq:P1346 ?recipient . } BIND("nominated" AS ?type) }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
}`.trim();
  const url = `https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(sparql)}`;
  const parsed = await fetchJson<{ results?: { bindings?: Array<Record<string, { value?: string }>> } }>(url, {
    "User-Agent": "MinCloud/0.1 (movie catalog)"
  });
  const wins: unknown[] = [];
  const nominations: unknown[] = [];
  for (const binding of parsed.results?.bindings ?? []) {
    const label = binding.awardLabel?.value || "";
    if (!label.toLowerCase().startsWith("academy award")) {
      continue;
    }
    const entry = {
      id: `${label}-${binding.recipientLabel?.value || ""}`.slice(0, 80),
      category: label,
      year: null,
      recipient: binding.recipientLabel?.value || null
    };
    if (binding.type?.value === "won") {
      wins.push(entry);
    } else {
      nominations.push({ ...entry, nominee: entry.recipient });
    }
  }
  const oscarAwards = { wins, nominations, totalWins: wins.length, totalNominations: nominations.length, rawAwardsText: null };
  if (row) {
    await upsertAdminMovie({ ...row, oscarAwards }, row);
  }
  res.json({ success: true, oscarAwards });
});

router.get("/dedupe/preview", async (_req, res) => {
  const movies = await loadAdminMovies();
  const sources = await loadAdminSources();
  res.json({ groups: buildDedupeGroups(movies, sources) });
});

router.post("/dedupe/commit", async (req, res) => {
  const movies = await loadAdminMovies();
  const remove = new Set<number>(Array.isArray(req.body?.indexes) ? req.body.indexes.map(Number) : []);
  let removed = 0;
  for (const index of [...remove].sort((a, b) => b - a)) {
    const row = movies[index];
    if (!row) {
      continue;
    }
    await deleteAdminRow(row);
    removed += 1;
  }
  res.json({ success: true, removedCount: removed });
});

router.post("/feeds/refresh-all", async (_req, res) => {
  const sources = await loadAdminSources();
  let addedCount = 0;
  let skippedCount = 0;
  for (const source of sources.filter((item) => item.type === "podcast" && item.url)) {
    const result = await refreshPodcastSource(source.identifier);
    addedCount += result.addedCount;
    skippedCount += result.skippedCount;
  }
  res.json({ success: true, addedCount, skippedCount });
});

router.post("/podcasts/refresh", async (req, res) => {
  const sourceIdentifier = String(req.body?.sourceIdentifier || "");
  if (!sourceIdentifier) {
    res.status(400).json({ error: "Missing sourceIdentifier" });
    return;
  }
  res.json(await refreshPodcastSource(sourceIdentifier));
});

router.post("/feeds/preview", async (req, res) => {
  const identifiers: string[] = Array.isArray(req.body?.sourceIdentifiers) ? req.body.sourceIdentifiers : [];
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
        items.push({
          title: episode.title,
          sourceTitle: episode.title,
          sourceIdentifier: identifier,
          episodeDate: episode.publishDate,
          isDuplicate: existing.has(episode.title)
        });
      }
    } catch {
      // skip broken feeds
    }
  }
  res.json({ items, summary: { count: items.length } });
});

router.post("/podcasts/latest/preview", async (req, res) => {
  const sources = await loadAdminSources();
  const identifiers = Array.isArray(req.body?.sourceIdentifiers)
    ? req.body.sourceIdentifiers
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
        items.push({
          title: episode.title,
          sourceTitle: episode.title,
          sourceIdentifier: identifier,
          episodeDate: episode.publishDate,
          isDuplicate: existing.has(episode.title)
        });
      }
    } catch {
      // skip
    }
  }
  res.json({ items, summary: { count: items.length } });
});

router.post("/ingest/preview", async (req, res) => {
  const url = String(req.body?.url || "");
  if (!url) {
    res.status(400).json({ error: "url required" });
    return;
  }
  const html = await fetchText(url);
  const titles: Array<{ title: string; rank: number }> = [];
  const seen = new Set<string>();
  const matches = html.match(/<a[^>]*>([^<]{2,120})<\/a>/gi) || [];
  for (const match of matches) {
    const text = match.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&#039;/g, "'").trim();
    const key = text.toLowerCase();
    if (!text || seen.has(key)) {
      continue;
    }
    seen.add(key);
    titles.push({ title: text, rank: titles.length + 1 });
    if (titles.length >= 80) {
      break;
    }
  }
  res.json({ items: titles, summary: { count: titles.length } });
});

router.post("/ingest/enrich", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  const enriched = [];
  for (const item of items.slice(0, 40)) {
    try {
      const found = item.title && config.tmdbApiKey ? await searchTmdbMovies(String(item.title), undefined, config.tmdbApiKey) : [];
      const first = found[0];
      if (!first) {
        enriched.push({ ...item, status: "missing" });
        continue;
      }
      const details = await fetchTmdbMovieDetails(first.id, config.tmdbApiKey);
      enriched.push({
        ...item,
        ...applyTmdbDetails(
          {
            title: item.title,
            year: null,
            tmdbId: first.id,
            sourceIdentifier: item.sourceIdentifier ?? null,
            sourceTitle: item.sourceTitle ?? item.title,
            rank: item.rank ?? null,
            mpaaRating: null,
            episodeDate: null,
            overview: null,
            posterPath: null,
            backdropPath: null,
            genres: [],
            streamingServices: [],
            credits: null,
            trailer: null,
            oscarAwards: null,
            physicalMedia: null,
            podcastEpisodeDescription: null
          },
          details
        ),
        status: "enriched"
      });
    } catch {
      enriched.push({ ...item, status: "missing" });
    }
  }
  res.json({ items: enriched });
});

router.post("/ingest/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  let addedCount = 0;
  for (const item of items) {
    if (!item?.title || !item?.sourceIdentifier) {
      continue;
    }
    await upsertAdminMovie(item);
    addedCount += 1;
  }
  res.json({ success: true, addedCount, report: { items: [], addedCount } });
});

router.post("/feeds/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  let addedCount = 0;
  for (const item of items) {
    if (!item?.title || !item?.sourceIdentifier) {
      continue;
    }
    await upsertAdminMovie(item);
    addedCount += 1;
  }
  res.json({ success: true, addedCount, report: { items: [], addedCount } });
});

router.post("/podcasts/latest/commit", async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  let addedCount = 0;
  for (const item of items) {
    if (!item?.title || !item?.sourceIdentifier) {
      continue;
    }
    await upsertAdminMovie(item);
    addedCount += 1;
  }
  res.json({ success: true, addedCount, report: { items: [], addedCount } });
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
  for (const episode of parsed.episodes.slice(0, 40)) {
    if (existing.has(episode.title)) {
      skippedCount += 1;
      continue;
    }
    await upsertAdminMovie({
      title: episode.title,
      sourceIdentifier,
      sourceTitle: episode.title,
      episodeDate: episode.publishDate,
      overview: episode.description,
      podcastEpisodeDescription: episode.description
    });
    existing.add(episode.title);
    addedCount += 1;
  }
  return { addedCount, skippedCount, addedMovies: [] };
};

export default router;
