export type PhysicalEdition = {
  id: string;
  label: string;
  format: string;
  spineNumber: string | null;
  notes: string | null;
};

export type PhysicalMedia = {
  editions: PhysicalEdition[];
  hasCriterion: boolean;
  has4K: boolean;
  hasBluRay: boolean;
  manualOverride: boolean;
};

const editionKey = (edition: PhysicalEdition) =>
  [edition.label, edition.format, edition.spineNumber || "", edition.notes || ""].join("|");

export const isEmptyPhysicalMedia = (media?: PhysicalMedia | null) =>
  !media || (!media.hasCriterion && !media.has4K && !media.hasBluRay && !(media.editions || []).length);

export const normalizePhysicalMedia = (raw: unknown): PhysicalMedia | null => {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const value = raw as Record<string, unknown>;
  const editions = Array.isArray(value.editions)
    ? value.editions
        .map((edition) => {
          if (!edition || typeof edition !== "object") {
            return null;
          }
          const row = edition as Record<string, unknown>;
          const label = String(row.label || "other");
          const format = String(row.format || "bluRay");
          return {
            id: String(row.id || `${label}-${format}-${row.spineNumber || "none"}`),
            label,
            format,
            spineNumber: row.spineNumber != null ? String(row.spineNumber) : null,
            notes: row.notes != null ? String(row.notes) : null
          } satisfies PhysicalEdition;
        })
        .filter((edition): edition is PhysicalEdition => Boolean(edition))
    : [];
  const media: PhysicalMedia = {
    editions,
    hasCriterion: Boolean(value.hasCriterion) || editions.some((edition) => edition.label === "criterion"),
    has4K: Boolean(value.has4K) || editions.some((edition) => edition.format === "uhd4k"),
    hasBluRay:
      Boolean(value.hasBluRay) ||
      editions.some((edition) => edition.format === "bluRay" || edition.format === "uhd4k"),
    manualOverride: Boolean(value.manualOverride)
  };
  return isEmptyPhysicalMedia(media) && !media.manualOverride ? null : media;
};

export const mergePhysicalMedia = (
  stored?: PhysicalMedia | null,
  inferred?: PhysicalMedia | null
): PhysicalMedia | null => {
  if (stored?.manualOverride) {
    return stored;
  }
  if (!stored) {
    return inferred ?? null;
  }
  if (!inferred) {
    return stored;
  }
  const byKey = new Map<string, PhysicalEdition>();
  for (const edition of [...stored.editions, ...inferred.editions]) {
    if (!byKey.has(editionKey(edition))) {
      byKey.set(editionKey(edition), edition);
    }
  }
  return normalizePhysicalMedia({
    editions: [...byKey.values()],
    hasCriterion: stored.hasCriterion || inferred.hasCriterion,
    has4K: stored.has4K || inferred.has4K,
    hasBluRay: stored.hasBluRay || inferred.hasBluRay,
    manualOverride: stored.manualOverride || inferred.manualOverride
  });
};

export const overlayMapFromUnknown = (raw: unknown) => {
  const map = new Map<number, PhysicalMedia>();
  if (!raw || typeof raw !== "object") {
    return map;
  }
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const tmdbId = Number(key);
    const media = normalizePhysicalMedia(value);
    if (Number.isFinite(tmdbId) && media) {
      map.set(tmdbId, media);
    }
  }
  return map;
};

export const emptyPhysicalMedia = (): PhysicalMedia => ({
  editions: [],
  hasCriterion: false,
  has4K: false,
  hasBluRay: false,
  manualOverride: false
});

export const reconcilePhysicalMedia = (media: PhysicalMedia): PhysicalMedia => {
  media.hasCriterion = media.hasCriterion || media.editions.some((edition) => edition.label === "criterion");
  media.has4K = media.has4K || media.editions.some((edition) => edition.format === "uhd4k");
  media.hasBluRay =
    media.hasBluRay || media.editions.some((edition) => edition.format === "bluRay" || edition.format === "uhd4k");
  return media;
};

export const addPhysicalEdition = (
  media: PhysicalMedia,
  edition: { id?: string; label: string; format: string; spineNumber?: string | null; notes?: string | null }
): PhysicalMedia => {
  const next: PhysicalEdition = {
    id: edition.id || `${edition.label}-${edition.format}-${edition.spineNumber || "none"}`,
    label: edition.label,
    format: edition.format,
    spineNumber: edition.spineNumber ?? null,
    notes: edition.notes ?? null
  };
  if (media.editions.some((existing) => editionKey(existing) === editionKey(next))) {
    return media;
  }
  media.editions.push(next);
  return reconcilePhysicalMedia(media);
};

export const FORMAT_QIDS: Record<string, string> = {
  Q20993976: "uhd4k",
  Q188808: "bluRay",
  Q34467: "dvd"
};

export const LABEL_QIDS: Record<string, string> = {
  Q1150316: "criterion",
  Q5187902: "criterion",
  Q4796236: "arrow",
  Q2277442: "shoutFactory",
  Q6413894: "kinoLorber"
};

const LABEL_NAME_HINTS = [
  { pattern: /criterion/i, label: "criterion" },
  { pattern: /arrow (video|films|academy)/i, label: "arrow" },
  { pattern: /shout!? factory/i, label: "shoutFactory" },
  { pattern: /kino lorber/i, label: "kinoLorber" }
];

export const qidFromUri = (value?: string | null) => {
  if (!value) {
    return null;
  }
  const match = String(value).match(/\/(Q\d+)$/);
  return match ? match[1] : null;
};

export const mediaFromWikidataRow = ({
  spine,
  formatQid,
  publisherQid,
  publisherLabel
}: {
  spine?: string | null;
  formatQid?: string | null;
  publisherQid?: string | null;
  publisherLabel?: string | null;
}): PhysicalMedia => {
  const media = emptyPhysicalMedia();
  const format = (formatQid && FORMAT_QIDS[formatQid]) || null;
  let label = (publisherQid && LABEL_QIDS[publisherQid]) || null;
  if (!label && publisherLabel) {
    const hint = LABEL_NAME_HINTS.find((item) => item.pattern.test(publisherLabel));
    if (hint) {
      label = hint.label;
    }
  }
  if (spine) {
    media.hasCriterion = true;
    addPhysicalEdition(media, {
      label: "criterion",
      format: format || "bluRay",
      spineNumber: String(spine)
    });
  }
  if (label === "criterion") {
    media.hasCriterion = true;
  }
  if (format === "uhd4k") {
    media.has4K = true;
  }
  if (format === "bluRay" || format === "uhd4k") {
    media.hasBluRay = true;
  }
  if (label || format) {
    addPhysicalEdition(media, {
      label: label || "other",
      format: format || "bluRay"
    });
  }
  return reconcilePhysicalMedia(media);
};

export const CURATED_4K_TMDB_IDS = [
  62, 155, 238, 280, 346, 348, 539, 550, 578, 603, 679, 680, 694, 769, 947, 949, 1091, 1949, 6977, 7345, 9693, 27205,
  37799, 438631, 76341, 157336, 244786, 273481, 361743, 503919
];

export const seedCurated4K = (byTmdbId: Map<string, PhysicalMedia>) => {
  for (const tmdbId of CURATED_4K_TMDB_IDS) {
    const existing = byTmdbId.get(String(tmdbId)) || emptyPhysicalMedia();
    existing.has4K = true;
    existing.hasBluRay = true;
    if (!existing.editions.some((edition) => edition.format === "uhd4k")) {
      addPhysicalEdition(existing, {
        label: existing.hasCriterion ? "criterion" : "other",
        format: "uhd4k"
      });
    }
    byTmdbId.set(String(tmdbId), reconcilePhysicalMedia(existing));
  }
  return byTmdbId;
};

export const seedCriterionFromSources = (
  movies: Array<{ sourceIdentifier?: string | null; tmdbId?: number | null }>,
  byTmdbId: Map<string, PhysicalMedia>
) => {
  for (const movie of movies) {
    if ((movie.sourceIdentifier !== "criterion" && movie.sourceIdentifier !== "criterion-closet-picks") || !movie.tmdbId) {
      continue;
    }
    const existing = byTmdbId.get(String(movie.tmdbId)) || emptyPhysicalMedia();
    existing.hasCriterion = true;
    if (!existing.editions.some((edition) => edition.label === "criterion")) {
      addPhysicalEdition(existing, { label: "criterion", format: "bluRay" });
    }
    byTmdbId.set(String(movie.tmdbId), reconcilePhysicalMedia(existing));
  }
  return byTmdbId;
};

export const isUsefulPhysicalMedia = (media?: PhysicalMedia | null) => {
  if (!media || isEmptyPhysicalMedia(media)) {
    return false;
  }
  if (media.hasCriterion || media.has4K) {
    return true;
  }
  return (media.editions || []).some((edition) => edition.label && edition.label !== "other");
};

export const filterIndexToCatalog = (
  byTmdbId: Map<string, PhysicalMedia>,
  movies: Array<{ tmdbId?: number | null }>
) => {
  const catalog = new Set(
    movies.map((movie) => (movie.tmdbId != null ? String(movie.tmdbId) : "")).filter(Boolean)
  );
  const filtered = new Map<string, PhysicalMedia>();
  for (const [tmdbId, media] of byTmdbId.entries()) {
    if (catalog.has(String(tmdbId)) && isUsefulPhysicalMedia(media)) {
      filtered.set(String(tmdbId), media);
    }
  }
  return filtered;
};

export const overlayFromIndex = (byTmdbId: Map<string, PhysicalMedia>) => {
  const mapped: Record<string, PhysicalMedia> = {};
  for (const [tmdbId, media] of byTmdbId.entries()) {
    if (isUsefulPhysicalMedia(media)) {
      mapped[tmdbId] = media;
    }
  }
  return { byTmdbId: mapped };
};

export const physicalMediaStats = (movies: Array<{ physicalMedia?: unknown }>) => {
  const withMedia = movies.filter((movie) => !isEmptyPhysicalMedia(normalizePhysicalMedia(movie.physicalMedia)));
  return {
    totalMovies: movies.length,
    withPhysicalMedia: withMedia.length,
    withCriterion: withMedia.filter((movie) => normalizePhysicalMedia(movie.physicalMedia)?.hasCriterion).length,
    with4K: withMedia.filter((movie) => normalizePhysicalMedia(movie.physicalMedia)?.has4K).length,
    withBluRay: withMedia.filter((movie) => normalizePhysicalMedia(movie.physicalMedia)?.hasBluRay).length,
    manualOverrides: withMedia.filter((movie) => normalizePhysicalMedia(movie.physicalMedia)?.manualOverride).length
  };
};
