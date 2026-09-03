export const mapCatalogSourceLink = (link: Record<string, unknown>) => ({
  identifier: link.source_id ?? link.identifier ?? null,
  rank: link.rank ?? null,
  sourceTitle: link.source_title ?? link.sourceTitle ?? null,
  episodeDate: link.episode_date ?? link.episodeDate ?? null,
  episode: link.episode ?? null
});

export const catalogCacheHeaders = (revision: number, total: number) => ({
  "Cache-Control": "no-store, no-cache, must-revalidate",
  Pragma: "no-cache",
  "X-Catalog-Revision": String(revision),
  "X-Catalog-Total": String(total)
});

export const catalogPageMeta = (total: number, offset: number, returned: number, limit: number) => ({
  total,
  offset,
  limit,
  truncated: offset + returned < total
});

export const catalogMovieStats = (movies: Array<{ tmdbId?: unknown }>) => ({
  unmatchedCount: movies.filter((movie) => movie.tmdbId == null || movie.tmdbId === "").length
});

export const shouldFetchNextCatalogPage = (input: {
  fetched: number;
  batchLength: number;
  truncated?: boolean | null;
  total?: number | null;
}) => {
  if (input.batchLength <= 0) {
    return false;
  }
  if (input.total != null && Number.isFinite(Number(input.total))) {
    return input.fetched < Number(input.total);
  }
  return input.truncated === true;
};

export const shouldSkipIncrementalCatalogSync = (input: {
  force: boolean;
  hasSyncedBefore: boolean;
  localRevision: number;
  remoteRevision: number;
  localCount: number;
  remoteCount: number | null;
}) => {
  if (input.force || !input.hasSyncedBefore) {
    return false;
  }
  if (input.localRevision !== input.remoteRevision) {
    return false;
  }
  if (input.remoteCount != null && input.remoteCount > input.localCount) {
    return false;
  }
  return true;
};

export const formatCatalogRefreshMessage = (input: {
  added: number;
  updated: number;
  unmatched: number;
  catalogCount: number;
  revision: number;
  incomplete: boolean;
  fetched: number;
}) => {
  const unmatched =
    input.unmatched > 0 ? ` ${input.unmatched} titles have no TMDB match.` : "";
  const incomplete = input.incomplete
    ? ` Incomplete catalog: received ${input.fetched} of ${input.catalogCount} titles.`
    : "";
  if (input.added > 0) {
    return `Added ${input.added} new titles, updated ${input.updated}. Catalog ${input.catalogCount} titles, revision ${input.revision}.${unmatched}${incomplete}`;
  }
  return `No new titles. Catalog ${input.catalogCount} titles, revision ${input.revision}.${unmatched}${incomplete}`;
};
