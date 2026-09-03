import { createHash, randomBytes } from "node:crypto";
import { query } from "../db.js";
import { hashToken } from "./passwords.js";
import { ensurePodcast } from "./podcasts.js";
import { config } from "../config.js";

const UNDO_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export class AgentHttpError extends Error {
  code: string;
  status: number;
  extras: Record<string, unknown>;

  constructor(code: string, message: string, status = 400, extras: Record<string, unknown> = {}) {
    super(message);
    this.code = code;
    this.status = status;
    this.extras = extras;
  }

  toJSON() {
    return { error: this.code, message: this.message, ...this.extras };
  }
}

type Connection = {
  id: string;
  userId: string;
  name: string;
  scopes: string[];
  revokedAt: string | null;
};

type Movie = {
  id: string;
  title: string;
  year: number | null;
  tmdbId: number | null;
  overview: string;
  isSaved: boolean;
  isRewatched: boolean;
  isListened: boolean;
};

type Podcast = {
  id: string;
  title: string;
  author: string;
  feedURL: string;
  artworkURL: string | null;
  isFollowed: boolean;
};

type Listen = {
  episodeID: string;
  episodeTitle: string;
  podcastTitle: string;
  isPlayed: boolean;
  lastListenedAt: string;
};

type Library = {
  movies: Movie[];
  podcasts: Podcast[];
  listeningHistory: Listen[];
};

export const AGENT_TOOLS = [
  { name: "whoami", kind: "read", app: null, description: "Connection identity and granted scopes." },
  { name: "list_capabilities", kind: "read", app: null, description: "Tools this token may call." },
  { name: "undo", kind: "write", app: null, description: "Reverse the latest write, or a specific undoId." },
  { name: "list_undo_history", kind: "read", app: null, description: "Undo journal for this connection." },
  { name: "list_audit_log", kind: "read", app: null, description: "Redacted audit log for this connection." },
  { name: "list_movies", kind: "read", app: "mov", description: "List saved or rewatched movies." },
  { name: "search_movies", kind: "read", app: "mov", description: "Search the user's movie library." },
  { name: "get_movie", kind: "read", app: "mov", description: "Look up one movie by id or title." },
  { name: "set_movie_saved", kind: "write", app: "mov", description: "Save or unsaved a movie." },
  { name: "set_movie_rewatched", kind: "write", app: "mov", description: "Mark a movie rewatched." },
  { name: "set_movie_listened", kind: "write", app: "mov", description: "Mark a movie listened." },
  { name: "upsert_movie", kind: "write", app: "mov", description: "Add or update a movie and optional flags." },
  { name: "list_podcasts", kind: "read", app: "pod", description: "List followed podcasts." },
  { name: "search_podcasts", kind: "read", app: "pod", description: "Search followed podcasts." },
  { name: "follow_podcast", kind: "write", app: "pod", description: "Follow a podcast by title or feed URL." },
  { name: "unfollow_podcast", kind: "write", app: "pod", description: "Unfollow a podcast." },
  { name: "list_listening_history", kind: "read", app: "pod", description: "Recent episode listens." },
  { name: "record_podcast_listen", kind: "write", app: "pod", description: "Record that an episode was played." }
] as const;

const WRITE_TOOLS = new Set<string>(AGENT_TOOLS.filter((tool) => tool.kind === "write").map((tool) => tool.name));

export const parseInvoke = (body: Record<string, unknown>) => {
  const name = String(body.name || body.tool || "").trim();
  const raw = body.arguments ?? body.input ?? body.args ?? {};
  const args = raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};
  return { name, args };
};

const normalize = (value: unknown) =>
  String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

const includesQuery = (haystack: string, query: unknown) => {
  if (!query) return true;
  return normalize(haystack).includes(normalize(query));
};

const slugId = (prefix: string, title: unknown) => {
  const slug = normalize(title).replace(/\s+/g, "-") || "item";
  return `${prefix}-${slug}`;
};

const newId = () => randomBytes(8).toString("hex");

const mintToken = () => `minagt_${randomBytes(32).toString("base64url")}`;

const hashAgentToken = (token: string) => createHash("sha256").update(token.trim(), "utf8").digest("hex");

export const describeTools = () =>
  AGENT_TOOLS.map((tool) => ({
    name: tool.name,
    description: tool.description,
    kind: tool.kind,
    app: tool.app,
    inputSchema: { type: "object", additionalProperties: true }
  }));

const loadConnection = async (token: string | null): Promise<Connection> => {
  if (!token) {
    throw new AgentHttpError("unauthorized", "Missing or invalid agent token.", 401);
  }
  const hashed = hashAgentToken(token);
  const also = hashToken(token);
  const result = await query(
    `SELECT id, user_id, name, scopes, revoked_at
     FROM agent_connections
     WHERE token_hash IN ($1, $2)
     LIMIT 1`,
    [hashed, also]
  );
  const row = result.rows[0];
  if (!row) {
    throw new AgentHttpError("unauthorized", "Missing or invalid agent token.", 401);
  }
  if (row.revoked_at) {
    throw new AgentHttpError("revoked", "This agent connection has been revoked.", 403);
  }
  return {
    id: String(row.id),
    userId: String(row.user_id),
    name: String(row.name),
    scopes: (row.scopes as string[]) || [],
    revokedAt: row.revoked_at ? String(row.revoked_at) : null
  };
};

const loadLibrary = async (userId: string): Promise<Library> => {
  const movies = await query(
    `SELECT l.movie_id, l.is_saved, l.is_rewatched, l.is_listened,
            m.title, m.year, m.tmdb_id, m.overview
     FROM user_library_mov l
     LEFT JOIN mov_movies m ON m.id = l.movie_id
     WHERE l.user_id = $1`,
    [userId]
  );
  const podcasts = await query(
    `SELECT l.podcast_id, l.feed_url, l.title, l.artwork_url, l.is_followed,
            p.title AS catalog_title, p.author, p.feed_url AS catalog_feed, p.artwork_url AS catalog_art
     FROM user_library_pod l
     LEFT JOIN pod_podcasts p ON p.id = l.podcast_id
     WHERE l.user_id = $1`,
    [userId]
  );
  const extra = await query(`SELECT listening_history FROM agent_user_state WHERE user_id = $1`, [userId]);
  return {
    movies: movies.rows.map((row) => ({
      id: String(row.movie_id),
      title: String(row.title || row.movie_id),
      year: row.year == null ? null : Number(row.year),
      tmdbId: row.tmdb_id == null ? null : Number(row.tmdb_id),
      overview: String(row.overview || ""),
      isSaved: Boolean(row.is_saved),
      isRewatched: Boolean(row.is_rewatched),
      isListened: Boolean(row.is_listened)
    })),
    podcasts: podcasts.rows.map((row) => ({
      id: String(row.podcast_id),
      title: String(row.catalog_title || row.title || row.podcast_id),
      author: String(row.author || ""),
      feedURL: String(row.catalog_feed || row.feed_url || ""),
      artworkURL: (row.catalog_art || row.artwork_url || null) as string | null,
      isFollowed: row.is_followed !== false
    })),
    listeningHistory: Array.isArray(extra.rows[0]?.listening_history)
      ? (extra.rows[0].listening_history as Listen[])
      : []
  };
};

const persistLibrary = async (userId: string, library: Library) => {
  for (const movie of library.movies) {
    await query(
      `INSERT INTO mov_movies (id, tmdb_id, title, year, overview, last_updated)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (id) DO UPDATE SET
         title = COALESCE(NULLIF(EXCLUDED.title, ''), mov_movies.title),
         year = COALESCE(EXCLUDED.year, mov_movies.year),
         tmdb_id = COALESCE(EXCLUDED.tmdb_id, mov_movies.tmdb_id),
         overview = COALESCE(NULLIF(EXCLUDED.overview, ''), mov_movies.overview),
         last_updated = NOW()`,
      [movie.id, movie.tmdbId, movie.title, movie.year, movie.overview]
    );
    await query(
      `INSERT INTO user_library_mov (
         user_id, movie_id, is_watched, is_saved, is_rewatched, is_listened, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
       ON CONFLICT (user_id, movie_id) DO UPDATE SET
         is_watched = EXCLUDED.is_watched,
         is_saved = EXCLUDED.is_saved,
         is_rewatched = EXCLUDED.is_rewatched,
         is_listened = EXCLUDED.is_listened,
         updated_at = NOW()`,
      [userId, movie.id, movie.isRewatched || movie.isSaved, movie.isSaved, movie.isRewatched, movie.isListened]
    );
  }
  for (const podcast of library.podcasts) {
    let podcastId = podcast.id;
    if (podcast.feedURL) {
      podcastId = await ensurePodcast({
        podcastId: podcast.id,
        feedUrl: podcast.feedURL,
        title: podcast.title,
        artworkUrl: podcast.artworkURL
      });
    }
    await query(
      `INSERT INTO user_library_pod (
         user_id, podcast_id, feed_url, title, artwork_url, is_followed, notifications_enabled, playback, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, FALSE, '{}'::jsonb, NOW())
       ON CONFLICT (user_id, podcast_id) DO UPDATE SET
         feed_url = EXCLUDED.feed_url,
         title = EXCLUDED.title,
         artwork_url = EXCLUDED.artwork_url,
         is_followed = EXCLUDED.is_followed,
         updated_at = NOW()`,
      [userId, podcastId, podcast.feedURL || null, podcast.title, podcast.artworkURL, podcast.isFollowed]
    );
  }
  await query(
    `INSERT INTO agent_user_state (user_id, listening_history, updated_at)
     VALUES ($1, $2::jsonb, NOW())
     ON CONFLICT (user_id) DO UPDATE SET
       listening_history = EXCLUDED.listening_history,
       updated_at = NOW()`,
    [userId, JSON.stringify(library.listeningHistory)]
  );
};

const uniqueMatch = <T,>(items: T[], matcher: (item: T) => boolean, label: string) => {
  const matches = items.filter(matcher);
  if (matches.length === 1) return matches[0];
  if (matches.length === 0) {
    throw new AgentHttpError("not_found", `No ${label} matched.`, 404);
  }
  throw new AgentHttpError("ambiguous", `Multiple ${label}s matched. Be more specific.`, 409, {
    candidates: matches.slice(0, 8)
  });
};

const movieMatches = (movie: Movie, input: Record<string, unknown>) => {
  if (input.id && (movie.id === input.id || String(movie.tmdbId ?? "") === String(input.id))) return true;
  if (input.title) {
    const titleHit =
      normalize(movie.title) === normalize(input.title) || normalize(movie.title).includes(normalize(input.title));
    if (!titleHit) return false;
    if (input.year != null && movie.year != null && Number(movie.year) !== Number(input.year)) return false;
    return true;
  }
  return false;
};

const findMovie = async (library: Library, input: Record<string, unknown>) => {
  if (!input.id && !input.title) {
    throw new AgentHttpError("invalid_input", "Provide id or title.");
  }
  const local = library.movies.filter((movie) => movieMatches(movie, input));
  if (local.length === 1) return local[0];
  if (local.length > 1) {
    throw new AgentHttpError("ambiguous", "Multiple movies matched. Be more specific.", 409, {
      candidates: local.slice(0, 8)
    });
  }
  const catalog = await query(
    `SELECT id, title, year, tmdb_id, overview
     FROM mov_movies
     WHERE ($1::text IS NOT NULL AND (id = $1 OR tmdb_id::text = $1))
        OR ($2::text IS NOT NULL AND lower(title) = lower($2))
        OR ($2::text IS NOT NULL AND lower(title) LIKE lower($2) || '%')
     LIMIT 8`,
    [input.id ? String(input.id) : null, input.title ? String(input.title) : null]
  );
  const mapped = catalog.rows
    .filter((row) => input.year == null || row.year == null || Number(row.year) === Number(input.year))
    .map((row) => ({
      id: String(row.id),
      title: String(row.title),
      year: row.year == null ? null : Number(row.year),
      tmdbId: row.tmdb_id == null ? null : Number(row.tmdb_id),
      overview: String(row.overview || ""),
      isSaved: false,
      isRewatched: false,
      isListened: false
    }));
  const movie = uniqueMatch(mapped, () => true, "movie");
  library.movies.push(movie);
  return movie;
};

const podcastMatches = (podcast: Podcast, input: Record<string, unknown>) => {
  if (input.id && podcast.id === input.id) return true;
  if (input.feedURL && podcast.feedURL === input.feedURL) return true;
  if (
    input.title &&
    (normalize(podcast.title) === normalize(input.title) || normalize(podcast.title).includes(normalize(input.title)))
  ) {
    return true;
  }
  return false;
};

const redactInput = (input: Record<string, unknown>) => {
  const copy = { ...input };
  for (const key of Object.keys(copy)) {
    if (/token|secret|password|authorization/i.test(key)) copy[key] = "[redacted]";
  }
  return copy;
};

const writeAudit = async (
  connection: Connection,
  tool: string,
  app: string | null,
  input: Record<string, unknown>,
  ok: boolean,
  error: string | null,
  undoId: string | null
) => {
  await query(
    `INSERT INTO agent_audit (id, connection_id, connection_name, tool, app, input, ok, error, undo_id)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9)`,
    [newId(), connection.id, connection.name, tool, app, JSON.stringify(redactInput(input)), ok, error, undoId]
  );
};

const dispatch = async (connection: Connection, name: string, input: Record<string, unknown>) => {
  const library = await loadLibrary(connection.userId);
  const tool = AGENT_TOOLS.find((item) => item.name === name);
  if (!tool) {
    throw new AgentHttpError("unknown_tool", `Unknown tool "${name}".`, 404);
  }

  if (name === "whoami") {
    return {
      ok: true,
      connection: { id: connection.id, name: connection.name, scopes: connection.scopes },
      tools: AGENT_TOOLS.map((item) => item.name)
    };
  }
  if (name === "list_capabilities") {
    return { ok: true, tools: describeTools() };
  }
  if (name === "list_undo_history") {
    const limit = Number(input.limit ?? 20);
    const rows = await query(
      `SELECT id, tool, app, summary, created_at, expires_at, undone_at
       FROM agent_undo WHERE connection_id = $1
       ORDER BY created_at DESC LIMIT $2`,
      [connection.id, limit]
    );
    return { ok: true, undo: rows.rows };
  }
  if (name === "list_audit_log") {
    const limit = Number(input.limit ?? 25);
    const rows = await query(
      `SELECT id, tool, app, input, ok, error, undo_id, created_at
       FROM agent_audit WHERE connection_id = $1
       ORDER BY created_at DESC LIMIT $2`,
      [connection.id, limit]
    );
    return { ok: true, audit: rows.rows };
  }
  if (name === "undo") {
    const picked = input.undoId
      ? await query(
          `SELECT * FROM agent_undo WHERE id = $1 AND connection_id = $2 AND undone_at IS NULL`,
          [String(input.undoId), connection.id]
        )
      : await query(
          `SELECT * FROM agent_undo WHERE connection_id = $1 AND undone_at IS NULL
           ORDER BY created_at DESC LIMIT 1`,
          [connection.id]
        );
    const record = picked.rows[0];
    if (!record) {
      throw new AgentHttpError("not_found", "No undoable write found.", 404);
    }
    const before = record.before as { movies?: Movie[]; podcasts?: Podcast[]; listeningHistory?: Listen[] };
    if (before.movies) {
      for (const movie of before.movies) {
        const current = library.movies.find((item) => item.id === movie.id);
        if (current) Object.assign(current, movie);
      }
    }
    if (before.podcasts) {
      for (const podcast of before.podcasts) {
        const current = library.podcasts.find((item) => item.id === podcast.id);
        if (current) Object.assign(current, podcast);
      }
    }
    if (before.listeningHistory) library.listeningHistory = before.listeningHistory;
    await persistLibrary(connection.userId, library);
    await query(`UPDATE agent_undo SET undone_at = NOW() WHERE id = $1`, [record.id]);
    return { ok: true, undone: { id: record.id, tool: record.tool, app: record.app, summary: record.summary } };
  }

  let output: Record<string, unknown> = {};
  let before: unknown = null;
  let after: unknown = null;
  let summary = name;

  if (name === "list_movies") {
    const { saved, rewatched, listened, query: q, limit = 50 } = input as Record<string, any>;
    let items = library.movies;
    const hasFilter = saved != null || rewatched != null || listened != null || q;
    if (!hasFilter) items = items.filter((movie) => movie.isSaved || movie.isRewatched);
    if (saved != null) items = items.filter((movie) => movie.isSaved === Boolean(saved));
    if (rewatched != null) items = items.filter((movie) => movie.isRewatched === Boolean(rewatched));
    if (listened != null) items = items.filter((movie) => movie.isListened === Boolean(listened));
    if (q) items = items.filter((movie) => includesQuery(`${movie.title} ${movie.year ?? ""} ${movie.id}`, q));
    output = { movies: items.slice(0, Number(limit)), total: items.length };
  } else if (name === "search_movies") {
    const items = library.movies.filter((movie) =>
      includesQuery(`${movie.title} ${movie.year ?? ""} ${movie.id} ${movie.overview}`, input.query)
    );
    output = { movies: items.slice(0, Number(input.limit ?? 10)), total: items.length };
  } else if (name === "get_movie") {
    output = { movie: await findMovie(library, input) };
  } else if (name === "set_movie_saved") {
    const movie = await findMovie(library, input);
    before = { movies: [{ ...movie }] };
    movie.isSaved = Boolean(input.saved);
    after = { movies: [{ ...movie }] };
    summary = input.saved ? `Saved ${movie.title}` : `Removed ${movie.title} from saved`;
    output = { movie };
  } else if (name === "set_movie_rewatched") {
    const movie = await findMovie(library, input);
    before = { movies: [{ ...movie }] };
    movie.isRewatched = Boolean(input.rewatched);
    after = { movies: [{ ...movie }] };
    summary = `Updated rewatched on ${movie.title}`;
    output = { movie };
  } else if (name === "set_movie_listened") {
    const movie = await findMovie(library, input);
    before = { movies: [{ ...movie }] };
    movie.isListened = Boolean(input.listened);
    after = { movies: [{ ...movie }] };
    summary = `Updated listened on ${movie.title}`;
    output = { movie };
  } else if (name === "upsert_movie") {
    if (!input.title && !input.id) throw new AgentHttpError("invalid_input", "Provide title or id.");
    const existing = library.movies.find(
      (movie) =>
        (input.id && movie.id === input.id) ||
        (input.tmdbId != null && movie.tmdbId === Number(input.tmdbId)) ||
        (normalize(movie.title) === normalize(input.title) && (input.year == null || movie.year === Number(input.year)))
    );
    if (existing) {
      before = { movies: [{ ...existing }] };
      if (input.saved != null) existing.isSaved = Boolean(input.saved);
      if (input.rewatched != null) existing.isRewatched = Boolean(input.rewatched);
      if (input.listened != null) existing.isListened = Boolean(input.listened);
      after = { movies: [{ ...existing }] };
      summary = `Updated ${existing.title}`;
      output = { movie: existing, created: false };
    } else {
      const movie: Movie = {
        id: String(input.id || slugId("mov", input.title)),
        title: String(input.title),
        year: input.year == null ? null : Number(input.year),
        tmdbId: input.tmdbId == null ? null : Number(input.tmdbId),
        overview: String(input.overview || ""),
        isSaved: input.saved == null ? true : Boolean(input.saved),
        isRewatched: Boolean(input.rewatched),
        isListened: Boolean(input.listened)
      };
      library.movies.push(movie);
      before = { movies: [] };
      after = { movies: [{ ...movie }] };
      summary = `Added ${movie.title}`;
      output = { movie, created: true };
    }
  } else if (name === "list_podcasts") {
    let items = library.podcasts.filter((podcast) => podcast.isFollowed !== false);
    if (input.query) {
      items = items.filter((podcast) => includesQuery(`${podcast.title} ${podcast.author} ${podcast.feedURL}`, input.query));
    }
    output = { podcasts: items.slice(0, Number(input.limit ?? 50)), total: items.length };
  } else if (name === "search_podcasts") {
    const items = library.podcasts.filter((podcast) => includesQuery(`${podcast.title} ${podcast.author}`, input.query));
    output = { podcasts: items.slice(0, Number(input.limit ?? 8)), total: items.length };
  } else if (name === "follow_podcast") {
    if (!input.id && !input.title && !input.feedURL) {
      throw new AgentHttpError("invalid_input", "Provide id, title, or feedURL.");
    }
    const existing = library.podcasts.find((podcast) => podcastMatches(podcast, input));
    if (existing) {
      before = { podcasts: [{ ...existing }] };
      existing.isFollowed = true;
      after = { podcasts: [{ ...existing }] };
      summary = `Followed ${existing.title}`;
      output = { podcast: existing, created: false };
    } else {
      const podcast: Podcast = {
        id: String(input.id || slugId("pod", input.title || input.feedURL)),
        title: String(input.title || input.feedURL || "Podcast"),
        author: String(input.author || ""),
        feedURL: String(input.feedURL || ""),
        artworkURL: input.artworkURL ? String(input.artworkURL) : null,
        isFollowed: true
      };
      library.podcasts.push(podcast);
      before = { podcasts: [] };
      after = { podcasts: [{ ...podcast }] };
      summary = `Added ${podcast.title}`;
      output = { podcast, created: true };
    }
  } else if (name === "unfollow_podcast") {
    const podcast = uniqueMatch(library.podcasts, (item) => podcastMatches(item, input), "podcast");
    before = { podcasts: [{ ...podcast }] };
    podcast.isFollowed = false;
    after = { podcasts: [{ ...podcast }] };
    summary = `Unfollowed ${podcast.title}`;
    output = { podcast };
  } else if (name === "list_listening_history") {
    let items = [...library.listeningHistory].sort((a, b) => String(b.lastListenedAt).localeCompare(String(a.lastListenedAt)));
    if (input.query) {
      items = items.filter((entry) => includesQuery(`${entry.episodeTitle} ${entry.podcastTitle}`, input.query));
    }
    output = { history: items.slice(0, Number(input.limit ?? 25)), total: items.length };
  } else if (name === "record_podcast_listen") {
    const episodeID = String(input.episodeID || slugId("ep", input.episodeTitle));
    const existing = library.listeningHistory.find((entry) => entry.episodeID === episodeID);
    before = { listeningHistory: library.listeningHistory.map((entry) => ({ ...entry })) };
    if (existing) {
      existing.isPlayed = input.isPlayed == null ? true : Boolean(input.isPlayed);
      existing.lastListenedAt = new Date().toISOString();
    } else {
      library.listeningHistory.push({
        episodeID,
        episodeTitle: String(input.episodeTitle || episodeID),
        podcastTitle: String(input.podcastTitle || ""),
        isPlayed: input.isPlayed == null ? true : Boolean(input.isPlayed),
        lastListenedAt: new Date().toISOString()
      });
    }
    after = { listeningHistory: library.listeningHistory.map((entry) => ({ ...entry })) };
    summary = `Recorded listen ${input.episodeTitle || episodeID}`;
    output = { recorded: true };
  } else {
    throw new AgentHttpError("unknown_tool", `Unknown tool "${name}".`, 404);
  }

  let undoId: string | null = null;
  if (WRITE_TOOLS.has(name)) {
    await persistLibrary(connection.userId, library);
    undoId = newId();
    await query(
      `INSERT INTO agent_undo (id, connection_id, tool, app, before, after, summary, expires_at)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, $8)`,
      [
        undoId,
        connection.id,
        name,
        tool.app,
        JSON.stringify(before || {}),
        JSON.stringify(after || {}),
        summary,
        new Date(Date.now() + UNDO_TTL_MS).toISOString()
      ]
    );
  }

  await query(`UPDATE agent_connections SET last_used_at = NOW() WHERE id = $1`, [connection.id]);
  return { ok: true, ...output, ...(summary && WRITE_TOOLS.has(name) ? { summary } : {}), ...(undoId ? { undoId } : {}) };
};

export const listToolsForToken = async (token: string | null) => {
  await loadConnection(token);
  const tools = describeTools();
  return { ok: true, tools, names: tools.map((tool) => tool.name) };
};

export const invokeForToken = async (token: string | null, name: string, args: Record<string, unknown>) => {
  const connection = await loadConnection(token);
  if (!name) {
    throw new AgentHttpError("invalid_input", "Provide name (or tool) and optional arguments.");
  }
  try {
    const result = await dispatch(connection, name, args);
    await writeAudit(connection, name, AGENT_TOOLS.find((tool) => tool.name === name)?.app ?? null, args, true, null, (result as { undoId?: string }).undoId ?? null);
    return result;
  } catch (error) {
    const message = error instanceof Error ? error.message : "error";
    await writeAudit(connection, name, AGENT_TOOLS.find((tool) => tool.name === name)?.app ?? null, args, false, message, null).catch(() => undefined);
    throw error;
  }
};

export const createAgentConnection = async (input: { userId: string; name?: string }) => {
  const token = mintToken();
  const id = newId();
  const name = (input.name || "VM agent").trim() || "VM agent";
  await query(
    `INSERT INTO agent_connections (id, user_id, name, token_hash, scopes)
     VALUES ($1, $2, $3, $4, $5)`,
    [id, input.userId, name, hashAgentToken(token), ["mov.read", "mov.write", "pod.read", "pod.write", "undo", "audit"]]
  );
  return {
    token,
    connection: { id, name, userId: input.userId },
    warning: "Copy this token now. It is stored as a hash and cannot be shown again."
  };
};

export const ensureBootstrapAgent = async () => {
  const token = config.agentToken.trim();
  if (!token) return;
  const hashed = hashAgentToken(token);
  const existing = await query(`SELECT id FROM agent_connections WHERE token_hash = $1`, [hashed]);
  if (existing.rowCount) return;
  const email = config.agentUserEmail.trim().toLowerCase();
  const user = email
    ? await query(`SELECT id FROM users WHERE lower(email) = $1`, [email])
    : await query(`SELECT id FROM users WHERE is_admin = TRUE ORDER BY created_at ASC LIMIT 1`);
  const userId = user.rows[0]?.id;
  if (!userId) return;
  await query(
    `INSERT INTO agent_connections (id, user_id, name, token_hash, scopes)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (token_hash) DO NOTHING`,
    [newId(), userId, "Bootstrap VM agent", hashed, ["mov.read", "mov.write", "pod.read", "pod.write", "undo", "audit"]]
  );
};
