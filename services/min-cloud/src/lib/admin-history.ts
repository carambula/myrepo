import type { Request } from "express";
import { query, withTransaction } from "../db.js";
import { bumpWatchedIt } from "./admin-catalog.js";

export const SNAPSHOT_KEEP = 40;
export const SNAPSHOT_DEBOUNCE_MS = 2 * 60 * 1000;

export type CatalogPayload = {
  sources: unknown[];
  movies: unknown[];
  streaming: unknown[];
  links: unknown[];
};

export type RowTarget = "movie" | "source";
export type RevertKind = "restore" | "delete" | "none";

export type SnapshotMeta = {
  id: string;
  label?: string | null;
  createdAt: string | Date;
};

export const actorFrom = (req: Request) =>
  (req as Request & { adminActor?: string }).adminActor || "admin-token";

export const revertKind = (before: unknown, after: unknown): RevertKind => {
  if (before != null) {
    return "restore";
  }
  if (after != null) {
    return "delete";
  }
  return "none";
};

export const rowTargetFromAction = (action: string): RowTarget | null => {
  if (action.startsWith("movie.")) {
    return "movie";
  }
  if (action.startsWith("source.")) {
    return "source";
  }
  return null;
};

export const isCatalogPayload = (payload: unknown): payload is CatalogPayload => {
  if (!payload || typeof payload !== "object") {
    return false;
  }
  const row = payload as Record<string, unknown>;
  return (
    Array.isArray(row.sources) &&
    Array.isArray(row.movies) &&
    Array.isArray(row.streaming) &&
    Array.isArray(row.links)
  );
};

export const pruneUnlabeledSnapshotIds = (snapshots: SnapshotMeta[], keep = SNAPSHOT_KEEP): string[] => {
  return snapshots
    .filter((snapshot) => !snapshot.label)
    .sort((left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime())
    .slice(keep)
    .map((snapshot) => snapshot.id);
};

export const shouldSkipDebouncedSnapshot = (
  lastCreatedAt: Date | string | null | undefined,
  now = Date.now(),
  debounceMs = SNAPSHOT_DEBOUNCE_MS
) => {
  if (!lastCreatedAt) {
    return false;
  }
  return now - new Date(lastCreatedAt).getTime() < debounceMs;
};

export const recordAudit = async (
  req: Request,
  action: string,
  details: Record<string, unknown> = {},
  before: unknown = null,
  after: unknown = null
) => {
  await query(
    `
    INSERT INTO admin_audit (actor, action, details, before_state, after_state)
    VALUES ($1, $2, $3::jsonb, $4::jsonb, $5::jsonb)
    `,
    [
      actorFrom(req),
      action,
      JSON.stringify(details),
      before == null ? null : JSON.stringify(before),
      after == null ? null : JSON.stringify(after)
    ]
  );
};

export const captureCatalogPayload = async (): Promise<CatalogPayload> => {
  const sources = await query(
    `SELECT identifier, name, type, url, is_ranked, enabled, movie_count FROM mov_sources ORDER BY identifier`
  );
  const movies = await query(
    `SELECT id, tmdb_id, imdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating,
            genres, credits, trailer, oscar_awards, physical_media
     FROM mov_movies ORDER BY id`
  );
  const streaming = await query(
    `SELECT movie_id, region, providers FROM mov_streaming ORDER BY movie_id, region`
  );
  const links = await query(
    `SELECT movie_id, source_id, rank, source_title, episode_date, episode FROM mov_movie_sources ORDER BY movie_id, source_id`
  );
  return {
    sources: sources.rows,
    movies: movies.rows,
    streaming: streaming.rows,
    links: links.rows
  };
};

const pruneSnapshots = async (app: "watchedit" | "podlink") => {
  await query(
    `
    DELETE FROM catalog_snapshots
    WHERE app = $1
      AND label IS NULL
      AND id NOT IN (
        SELECT id FROM catalog_snapshots
        WHERE app = $1 AND label IS NULL
        ORDER BY created_at DESC
        LIMIT $2
      )
    `,
    [app, SNAPSHOT_KEEP]
  );
};

export const takeSnapshot = async (
  req: Request,
  input: { trigger: string; label?: string | null; app?: "watchedit" | "podlink" }
) => {
  const app = input.app ?? "watchedit";
  const payload = await captureCatalogPayload();
  const revision = await query(`SELECT revision FROM catalog_revisions WHERE app = $1`, [app]);
  const inserted = await query(
    `
    INSERT INTO catalog_snapshots (app, label, trigger, actor, revision, movie_count, source_count, payload)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb)
    RETURNING id, app, label, trigger, actor, revision, movie_count, source_count, created_at
    `,
    [
      app,
      input.label?.trim() || null,
      input.trigger,
      actorFrom(req),
      Number(revision.rows[0]?.revision ?? 0),
      payload.movies.length,
      payload.sources.length,
      JSON.stringify(payload)
    ]
  );
  await pruneSnapshots(app);
  return inserted.rows[0];
};

export const listSnapshots = async (limit = 40) => {
  const result = await query(
    `
    SELECT id, app, label, trigger, actor, revision, movie_count, source_count, created_at
    FROM catalog_snapshots
    WHERE app = 'watchedit'
    ORDER BY created_at DESC
    LIMIT $1
    `,
    [limit]
  );
  return result.rows;
};

export const listAudit = async (limit = 80) => {
  const result = await query(
    `
    SELECT id, actor, action, details, before_state, after_state, created_at
    FROM admin_audit
    ORDER BY created_at DESC
    LIMIT $1
    `,
    [limit]
  );
  return result.rows.map((row) => {
    const kind = revertKind(row.before_state, row.after_state);
    const target = rowTargetFromAction(String(row.action));
    return {
      id: row.id,
      actor: row.actor,
      action: row.action,
      details: row.details,
      created_at: row.created_at,
      reversible: kind !== "none" && target != null,
      revertKind: kind
    };
  });
};

const replaceCatalog = async (payload: CatalogPayload) => {
  if (!isCatalogPayload(payload)) {
    throw new Error("Snapshot payload is missing sources, movies, streaming, or links.");
  }
  await withTransaction(async (client) => {
    await client.query(`DELETE FROM mov_movie_sources`);
    await client.query(`DELETE FROM mov_streaming`);
    await client.query(`DELETE FROM mov_movies`);
    await client.query(`DELETE FROM mov_sources`);

    for (const source of payload.sources ?? []) {
      const row = source as Record<string, unknown>;
      await client.query(
        `
        INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, movie_count, updated_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,NOW())
        `,
        [
          row.identifier,
          row.name,
          row.type || "url",
          row.url ?? null,
          Boolean(row.is_ranked ?? row.isRankedList),
          row.enabled !== false,
          row.movie_count ?? row.movieCount ?? 0
        ]
      );
    }

    for (const movie of payload.movies ?? []) {
      const row = movie as Record<string, unknown>;
      await client.query(
        `
        INSERT INTO mov_movies (
          id, tmdb_id, imdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating,
          genres, credits, trailer, oscar_awards, physical_media, last_updated
        )
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11::jsonb,$12::jsonb,$13::jsonb,$14::jsonb,NOW())
        `,
        [
          row.id,
          row.tmdb_id ?? row.tmdbId ?? null,
          row.imdb_id ?? row.imdbId ?? null,
          row.title,
          row.year ?? null,
          row.poster_path ?? row.posterPath ?? null,
          row.backdrop_path ?? row.backdropPath ?? null,
          row.overview ?? null,
          row.mpaa_rating ?? row.mpaaRating ?? null,
          JSON.stringify(row.genres ?? []),
          JSON.stringify(row.credits ?? null),
          JSON.stringify(row.trailer ?? null),
          JSON.stringify(row.oscar_awards ?? row.oscarAwards ?? null),
          JSON.stringify(row.physical_media ?? row.physicalMedia ?? null)
        ]
      );
    }

    for (const stream of payload.streaming ?? []) {
      const row = stream as Record<string, unknown>;
      await client.query(
        `
        INSERT INTO mov_streaming (movie_id, region, providers, refreshed_at)
        VALUES ($1,$2,$3::jsonb,NOW())
        `,
        [row.movie_id ?? row.movieId, row.region || "US", JSON.stringify(row.providers ?? [])]
      );
    }

    for (const link of payload.links ?? []) {
      const row = link as Record<string, unknown>;
      await client.query(
        `
        INSERT INTO mov_movie_sources (movie_id, source_id, rank, source_title, episode_date, episode)
        VALUES ($1,$2,$3,$4,$5,$6::jsonb)
        `,
        [
          row.movie_id ?? row.movieId,
          row.source_id ?? row.sourceId,
          row.rank ?? null,
          row.source_title ?? row.sourceTitle ?? null,
          row.episode_date ?? row.episodeDate ?? null,
          JSON.stringify(row.episode ?? null)
        ]
      );
    }
  });
  await bumpWatchedIt();
};

export const restoreSnapshot = async (req: Request, snapshotId: string) => {
  const found = await query(
    `SELECT id, label, trigger, payload, movie_count FROM catalog_snapshots WHERE id = $1`,
    [snapshotId]
  );
  if (!found.rowCount) {
    throw new Error("Snapshot not found.");
  }
  const payload = found.rows[0].payload;
  if (!isCatalogPayload(payload)) {
    throw new Error("Snapshot payload is missing sources, movies, streaming, or links.");
  }
  const safety = await takeSnapshot(req, {
    trigger: "before-restore",
    label: `Before restore of ${String(found.rows[0].id).slice(0, 8)}`
  });
  await replaceCatalog(payload);
  await recordAudit(
    req,
    "catalog.restore",
    { snapshotId, safetySnapshotId: safety.id, movieCount: found.rows[0].movie_count },
    null,
    { snapshotId }
  );
  return { restored: found.rows[0], safetySnapshotId: safety.id };
};

export const physicalMediaFromSnapshotMovies = (movies: unknown[]) => {
  const rows: Array<{ id: string; tmdbId: number | null; physicalMedia: unknown }> = [];
  for (const movie of movies) {
    if (!movie || typeof movie !== "object") {
      continue;
    }
    const row = movie as Record<string, unknown>;
    const physicalMedia = row.physical_media ?? row.physicalMedia;
    const id = row.id != null ? String(row.id) : "";
    if (!id || physicalMedia == null) {
      continue;
    }
    rows.push({
      id,
      tmdbId: row.tmdb_id != null ? Number(row.tmdb_id) : row.tmdbId != null ? Number(row.tmdbId) : null,
      physicalMedia
    });
  }
  return rows;
};

export const restorePhysicalMediaFromSnapshot = async (req: Request, snapshotId: string) => {
  const found = await query(
    `SELECT id, label, trigger, payload, movie_count FROM catalog_snapshots WHERE id = $1`,
    [snapshotId]
  );
  if (!found.rowCount) {
    throw new Error("Snapshot not found.");
  }
  const payload = found.rows[0].payload;
  if (!isCatalogPayload(payload)) {
    throw new Error("Snapshot payload is missing sources, movies, streaming, or links.");
  }
  const rows = physicalMediaFromSnapshotMovies(payload.movies);
  const safety = await takeSnapshot(req, {
    trigger: "before-physical-restore",
    label: `Before physical restore of ${String(found.rows[0].id).slice(0, 8)}`
  });
  let restoredCount = 0;
  for (const row of rows) {
    const result = await query(
      `UPDATE mov_movies SET physical_media = $2::jsonb, last_updated = NOW() WHERE id = $1`,
      [row.id, JSON.stringify(row.physicalMedia)]
    );
    restoredCount += result.rowCount ?? 0;
  }
  if (restoredCount > 0) {
    await bumpWatchedIt();
  }
  await recordAudit(req, "catalog.physical-restore", {
    snapshotId,
    safetySnapshotId: safety.id,
    restoredCount
  });
  return { snapshotId, safetySnapshotId: safety.id, restoredCount };
};

export type RevertHandlers = Record<
  RowTarget,
  {
    restore: (before: Record<string, unknown>, after: Record<string, unknown> | null) => Promise<void>;
    remove: (after: Record<string, unknown>) => Promise<void>;
  }
>;

export const revertAudit = async (req: Request, auditId: string, handlers: RevertHandlers) => {
  const found = await query(
    `SELECT id, action, before_state, after_state FROM admin_audit WHERE id = $1`,
    [auditId]
  );
  if (!found.rowCount) {
    throw new Error("Audit entry not found.");
  }
  const row = found.rows[0];
  const before = (row.before_state as Record<string, unknown> | null) ?? null;
  const after = (row.after_state as Record<string, unknown> | null) ?? null;
  const target = rowTargetFromAction(String(row.action));
  if (!target) {
    throw new Error("This change is not a single-row edit. Restore a snapshot instead.");
  }
  const kind = revertKind(before, after);
  if (kind === "restore" && before) {
    await handlers[target].restore(before, after);
  } else if (kind === "delete" && after) {
    await handlers[target].remove(after);
  } else {
    throw new Error("This audit entry has no reversible state.");
  }
  await recordAudit(req, "catalog.revert", { auditId, action: row.action }, after, before);
  return { reverted: row.action, kind };
};

export const snapshotIfNeeded = async (
  req: Request,
  trigger: string,
  options: { force?: boolean; label?: string | null } = {}
) => {
  if (!options.force) {
    const recent = await query(
      `
      SELECT created_at FROM catalog_snapshots
      WHERE app = 'watchedit' AND trigger = $1
      ORDER BY created_at DESC LIMIT 1
      `,
      [trigger]
    );
    if (recent.rowCount && shouldSkipDebouncedSnapshot(recent.rows[0].created_at as string)) {
      return null;
    }
  }
  return takeSnapshot(req, { trigger, label: options.label });
};
