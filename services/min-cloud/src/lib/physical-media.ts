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
