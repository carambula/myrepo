import { deleteAdminRow, loadAdminMovies, upsertAdminMovie, bumpWatchedIt, type AdminMovie } from "./admin-catalog.js";
import {
  CLOSET_PICKS_INDEX_URL,
  CLOSET_PICKS_SOURCE_ID,
  collapseClosetPicks,
  fetchClosetPicksPage,
  normalizeClosetPicksTitle,
  parseClosetPicksEpisode,
  parseClosetPicksIndex,
  parseCriterionFilmPage,
  type ClosetPicksEpisode,
  type CollapsedClosetPick
} from "./closet-picks-scrape.js";
import { closetPicksMatchLooksWrong, prepareClosetPicksQuery } from "./closet-picks-match.js";
import { loadCriterionTmdbIndex, pickCriterionTmdbId, type CriterionTmdbHit } from "./closet-picks-wikidata.js";
import { resolveTmdbMatch } from "./podcast-ingest.js";
import { fetchTmdbMovieDetails } from "./tmdb.js";
import { config } from "../config.js";

export type ClosetPicksRematchProgress = {
  phase:
    | "fetching-index"
    | "scraping-episodes"
    | "fetching-film-pages"
    | "loading-wikidata"
    | "matching"
    | "done";
  episodeDone?: number;
  episodeTotal?: number;
  filmPageDone?: number;
  filmPageTotal?: number;
  matchDone?: number;
  matchTotal?: number;
  scanned?: number;
  matched?: number;
  corrected?: number;
  unchanged?: number;
  added?: number;
  missing?: number;
};

export type ClosetPicksRematchOptions = {
  dryRun?: boolean;
  episodeLimit?: number;
  fetchFilmPages?: boolean;
  preferWayback?: boolean;
  onProgress?: (progress: ClosetPicksRematchProgress) => void | Promise<void>;
};

export type ClosetPicksRematchItem = {
  title: string;
  director: string | null;
  year: number | null;
  tmdbId: number | null;
  previousTmdbId: number | null;
  status: "matched" | "corrected" | "unchanged" | "added" | "missing";
};

const mapPool = async <T, R>(items: T[], concurrency: number, worker: (item: T) => Promise<R>) => {
  const results: R[] = [];
  let next = 0;
  const run = async () => {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await worker(items[index]);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, run));
  return results;
};

const detailsPayload = (details: Record<string, unknown>, film: CollapsedClosetPick) => {
  const credits = details.credits as { cast?: Array<Record<string, unknown>>; crew?: Array<Record<string, unknown>> } | undefined;
  const director = credits?.crew?.find((member) => member.job === "Director");
  const cast = (credits?.cast ?? []).slice(0, 10).map((member) => ({
    id: member.id,
    name: member.name,
    character: member.character ?? null,
    profilePath: member.profile_path ?? null
  }));
  const releaseDate = details.release_date ? String(details.release_date) : "";
  return {
    title: String(details.title || film.title),
    tmdbId: Number(details.id),
    year: releaseDate ? Number(releaseDate.slice(0, 4)) : film.year,
    sourceIdentifier: CLOSET_PICKS_SOURCE_ID,
    sourceTitle: film.sourceTitle,
    rank: film.rank,
    sourceUrl: film.episodeUrl,
    filmUrl: film.filmUrl,
    director: film.director,
    episodeDate: film.episodeDate,
    overview: (details.overview as string) || null,
    posterPath: (details.poster_path as string) || null,
    backdropPath: (details.backdrop_path as string) || null,
    genres: Array.isArray(details.genres) ? (details.genres as Array<{ name: string }>).map((genre) => genre.name) : [],
    credits: director || cast.length ? { director: director?.name ?? null, cast } : null,
    podcastEpisodeDescription: film.description
  };
};

const reportProgress = async (
  onProgress: ClosetPicksRematchOptions["onProgress"],
  progress: ClosetPicksRematchProgress
) => {
  try {
    await onProgress?.(progress);
  } catch {
    // progress is best-effort
  }
};

const scrapeClosetPicksFilms = async (options: ClosetPicksRematchOptions) => {
  await reportProgress(options.onProgress, { phase: "fetching-index" });
  const indexHtml = await fetchClosetPicksPage(CLOSET_PICKS_INDEX_URL, {
    preferWayback: options.preferWayback
  });
  const episodes = parseClosetPicksIndex(indexHtml);
  const selected = options.episodeLimit ? episodes.slice(0, options.episodeLimit) : episodes;
  const visits: Array<{ episode: ClosetPicksEpisode; films: ReturnType<typeof parseClosetPicksEpisode> }> = [];
  let episodeDone = 0;
  await reportProgress(options.onProgress, {
    phase: "scraping-episodes",
    episodeDone: 0,
    episodeTotal: selected.length
  });
  await mapPool(selected, 6, async (episode) => {
    try {
      const html = await fetchClosetPicksPage(episode.episodeUrl, { preferWayback: options.preferWayback });
      visits.push({ episode, films: parseClosetPicksEpisode(html) });
    } catch {
      // skip unreachable episode pages
    } finally {
      episodeDone += 1;
      await reportProgress(options.onProgress, {
        phase: "scraping-episodes",
        episodeDone,
        episodeTotal: selected.length
      });
    }
  });
  return collapseClosetPicks(visits);
};

const fillFilmPageMetadata = async (
  films: CollapsedClosetPick[],
  options: Pick<ClosetPicksRematchOptions, "preferWayback" | "onProgress">
) => {
  const needsPage = films.filter((film) => film.filmUrl && (!film.year || !film.director));
  let filmPageDone = 0;
  await reportProgress(options.onProgress, {
    phase: "fetching-film-pages",
    filmPageDone: 0,
    filmPageTotal: needsPage.length,
    scanned: films.length
  });
  await mapPool(needsPage, 4, async (film) => {
    try {
      const html = await fetchClosetPicksPage(film.filmUrl as string, { preferWayback: options.preferWayback });
      const parsed = parseCriterionFilmPage(html);
      if (!film.year && parsed.year) {
        film.year = parsed.year;
      }
      if (!film.director && parsed.director) {
        film.director = parsed.director;
      }
      if (parsed.originalTitle && parsed.originalTitle !== film.title) {
        (film as CollapsedClosetPick & { originalTitle?: string }).originalTitle = parsed.originalTitle;
      }
    } catch {
      // keep card metadata
    } finally {
      filmPageDone += 1;
      await reportProgress(options.onProgress, {
        phase: "fetching-film-pages",
        filmPageDone,
        filmPageTotal: needsPage.length,
        scanned: films.length
      });
    }
  });
  return films;
};

const resolveClosetPicksTmdbId = async (film: CollapsedClosetPick, wikiHits: CriterionTmdbHit[]) => {
  const prepared = prepareClosetPicksQuery({
    title: film.title,
    year: film.year,
    director: film.director,
    originalTitle: (film as CollapsedClosetPick & { originalTitle?: string }).originalTitle
  });
  const search = await resolveTmdbMatch(prepared);
  if (search?.id) {
    return search.id;
  }
  return pickCriterionTmdbId(wikiHits, film.title, film.year);
};

const writeMatch = async (existing: AdminMovie | undefined, film: CollapsedClosetPick, tmdbId: number) => {
  const details = await fetchTmdbMovieDetails(tmdbId, config.tmdbApiKey);
  const payload = detailsPayload(details, film);
  if (existing?.__movieId && existing.tmdbId && existing.tmdbId !== tmdbId) {
    await deleteAdminRow({ ...existing, sourceIdentifier: CLOSET_PICKS_SOURCE_ID });
  }
  await upsertAdminMovie(payload, existing?.tmdbId === tmdbId ? existing : null, { bump: false });
};

export const rematchClosetPicks = async (options: ClosetPicksRematchOptions = {}) => {
  const films = await scrapeClosetPicksFilms(options);
  if (options.fetchFilmPages !== false) {
    await fillFilmPageMetadata(films, options);
  }

  await reportProgress(options.onProgress, { phase: "loading-wikidata", scanned: films.length });
  let wikiHits: CriterionTmdbHit[] = [];
  try {
    wikiHits = await loadCriterionTmdbIndex();
  } catch {
    wikiHits = [];
  }

  const movies = (await loadAdminMovies()).filter((movie) => movie.sourceIdentifier === CLOSET_PICKS_SOURCE_ID);
  const byTitle = new Map<string, AdminMovie>();
  for (const movie of movies) {
    const key = normalizeClosetPicksTitle(movie.title);
    if (key && !byTitle.has(key)) {
      byTitle.set(key, movie);
    }
  }

  const items: ClosetPicksRematchItem[] = [];
  let matched = 0;
  let corrected = 0;
  let unchanged = 0;
  let added = 0;
  let missing = 0;
  let matchDone = 0;

  await reportProgress(options.onProgress, {
    phase: "matching",
    matchDone: 0,
    matchTotal: films.length,
    scanned: films.length,
    matched,
    corrected,
    unchanged,
    added,
    missing
  });

  for (const film of films) {
    const existing = byTitle.get(normalizeClosetPicksTitle(film.title));
    const tmdbId = await resolveClosetPicksTmdbId(film, wikiHits);
    if (!tmdbId) {
      missing += 1;
      items.push({
        title: film.title,
        director: film.director,
        year: film.year,
        tmdbId: null,
        previousTmdbId: existing?.tmdbId ?? null,
        status: "missing"
      });
    } else {
      const alreadyCorrect = existing?.tmdbId === tmdbId && !closetPicksMatchLooksWrong(existing, film);
      const status = !existing ? "added" : existing.tmdbId === tmdbId ? (alreadyCorrect ? "unchanged" : "matched") : "corrected";
      if (status === "added") {
        added += 1;
      } else if (status === "corrected") {
        corrected += 1;
      } else if (status === "unchanged") {
        unchanged += 1;
      } else {
        matched += 1;
      }

      items.push({
        title: film.title,
        director: film.director,
        year: film.year,
        tmdbId,
        previousTmdbId: existing?.tmdbId ?? null,
        status
      });

      if (!options.dryRun && status !== "unchanged") {
        await writeMatch(existing, film, tmdbId);
      }
    }

    matchDone += 1;
    await reportProgress(options.onProgress, {
      phase: "matching",
      matchDone,
      matchTotal: films.length,
      scanned: films.length,
      matched,
      corrected,
      unchanged,
      added,
      missing
    });
  }

  if (!options.dryRun && (matched || corrected || added)) {
    await bumpWatchedIt();
  }

  await reportProgress(options.onProgress, {
    phase: "done",
    matchDone,
    matchTotal: films.length,
    scanned: films.length,
    matched,
    corrected,
    unchanged,
    added,
    missing
  });

  return {
    scanned: films.length,
    matched,
    corrected,
    unchanged,
    added,
    missing,
    items
  };
};
