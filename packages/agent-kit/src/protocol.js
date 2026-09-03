/**
 * Shared agent protocol for the min apps suite.
 *
 * Apps: mov (WatchedIt), pod (PodLink), vid (YourTube),
 *       cyc (Cyclismo), spin (SpinMin), fit (fit min timers).
 *
 * Scopes are granted per connection. Write always implies read
 * for the same app. Destructive tools still require write and
 * always emit an undo record.
 */

export const AGENT_TOKEN_PREFIX = 'minagt_';

export const APPS = {
  mov: {
    id: 'mov',
    name: 'mov min',
    product: 'WatchedIt',
    description: 'Movie tracking — watched, saved, and listened titles',
  },
  pod: {
    id: 'pod',
    name: 'pod min',
    product: 'PodLink',
    description: 'Podcasts — followed shows and listening history',
  },
  vid: {
    id: 'vid',
    name: 'vid min',
    product: 'YourTube',
    description: 'Videos — channel subscriptions and watch state',
  },
  cyc: {
    id: 'cyc',
    name: 'cyc min',
    product: 'Cyclismo',
    description: 'Cycling races — saved, watched, and listened',
  },
  spin: {
    id: 'spin',
    name: 'spin min',
    product: 'SpinMin',
    description: 'Bikes, rides, and tire-pressure calculations',
  },
  fit: {
    id: 'fit',
    name: 'fit min',
    product: 'fit min',
    description: 'Interval timers — list, create, and start',
  },
};

export const APP_IDS = Object.keys(APPS);

export function readScope(appId) {
  return `${appId}.read`;
}

export function writeScope(appId) {
  return `${appId}.write`;
}

export const META_SCOPES = {
  undo: 'undo',
  audit: 'audit',
};

export function allScopes({ write = true } = {}) {
  const scopes = [META_SCOPES.undo, META_SCOPES.audit];
  for (const appId of APP_IDS) {
    scopes.push(readScope(appId));
    if (write) scopes.push(writeScope(appId));
  }
  return scopes;
}

export function expandScopes(scopes) {
  const set = new Set(scopes);
  for (const appId of APP_IDS) {
    if (set.has(writeScope(appId))) set.add(readScope(appId));
  }
  return [...set];
}

export function isWriteTool(tool) {
  return tool.kind === 'write';
}

export const UNDO_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export const TOOLS = [
  {
    name: 'whoami',
    app: null,
    kind: 'read',
    scopes: [],
    description: 'Show the connected agent identity, granted scopes, and available apps.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'list_capabilities',
    app: null,
    kind: 'read',
    scopes: [],
    description: 'List tools this connection is allowed to call, grouped by app.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'undo',
    app: null,
    kind: 'write',
    scopes: [META_SCOPES.undo],
    description:
      'Reverse a previous write. Pass undoId, or omit it to undo the most recent unused write from this connection.',
    inputSchema: {
      type: 'object',
      properties: {
        undoId: { type: 'string', description: 'Undo record id from a previous write.' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'list_undo_history',
    app: null,
    kind: 'read',
    scopes: [META_SCOPES.undo],
    description: 'List recent reversible writes and whether they have already been undone.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'list_audit_log',
    app: null,
    kind: 'read',
    scopes: [META_SCOPES.audit],
    description: 'Read the recent agent action log (tokens are never recorded).',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 25 },
        app: { type: 'string', enum: APP_IDS },
      },
      additionalProperties: false,
    },
  },

  // mov min
  {
    name: 'list_movies',
    app: 'mov',
    kind: 'read',
    scopes: [readScope('mov')],
    description:
      'List movies in the user library. Filter by saved, rewatched (watched), or listened. Defaults to saved + rewatched.',
    inputSchema: {
      type: 'object',
      properties: {
        saved: { type: 'boolean' },
        rewatched: { type: 'boolean' },
        listened: { type: 'boolean' },
        query: { type: 'string', description: 'Optional title or id search.' },
        limit: { type: 'integer', minimum: 1, maximum: 200, default: 50 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'search_movies',
    app: 'mov',
    kind: 'read',
    scopes: [readScope('mov')],
    description: 'Search the movie catalog by title, year, or id.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: ['query'],
      additionalProperties: false,
    },
  },
  {
    name: 'get_movie',
    app: 'mov',
    kind: 'read',
    scopes: [readScope('mov')],
    description: 'Get one movie by id, TMDB id, or exact title.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        year: { type: 'integer' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'set_movie_saved',
    app: 'mov',
    kind: 'write',
    scopes: [writeScope('mov')],
    description: 'Save or unsave a movie (watchlist bookmark). Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        year: { type: 'integer' },
        saved: { type: 'boolean' },
      },
      required: ['saved'],
      additionalProperties: false,
    },
  },
  {
    name: 'set_movie_rewatched',
    app: 'mov',
    kind: 'write',
    scopes: [writeScope('mov')],
    description: 'Mark a movie as rewatched (the watched signal in mov min). Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        year: { type: 'integer' },
        rewatched: { type: 'boolean' },
      },
      required: ['rewatched'],
      additionalProperties: false,
    },
  },
  {
    name: 'set_movie_listened',
    app: 'mov',
    kind: 'write',
    scopes: [writeScope('mov')],
    description: 'Mark the associated podcast episode as listened. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        year: { type: 'integer' },
        listened: { type: 'boolean' },
      },
      required: ['listened'],
      additionalProperties: false,
    },
  },
  {
    name: 'upsert_movie',
    app: 'mov',
    kind: 'write',
    scopes: [writeScope('mov')],
    description:
      'Add or update a movie in the library and optionally mark it saved or rewatched. Use when the title is not already in the catalog.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        year: { type: 'integer' },
        tmdbId: { type: 'integer' },
        overview: { type: 'string' },
        saved: { type: 'boolean' },
        rewatched: { type: 'boolean' },
        listened: { type: 'boolean' },
      },
      required: ['title'],
      additionalProperties: false,
    },
  },

  // pod min
  {
    name: 'list_podcasts',
    app: 'pod',
    kind: 'read',
    scopes: [readScope('pod')],
    description: 'List followed podcasts.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 200, default: 50 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'list_listening_history',
    app: 'pod',
    kind: 'read',
    scopes: [readScope('pod')],
    description: 'List recent listening history (played and in-progress episodes).',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 25 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'search_podcasts',
    app: 'pod',
    kind: 'read',
    scopes: [readScope('pod')],
    description: 'Search followed shows and any locally known catalog entries.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 25, default: 8 },
      },
      required: ['query'],
      additionalProperties: false,
    },
  },
  {
    name: 'follow_podcast',
    app: 'pod',
    kind: 'write',
    scopes: [writeScope('pod')],
    description: 'Follow a podcast by id, title, or RSS feed URL. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        author: { type: 'string' },
        feedURL: { type: 'string' },
        artworkURL: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'unfollow_podcast',
    app: 'pod',
    kind: 'write',
    scopes: [writeScope('pod')],
    description: 'Unfollow a podcast. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        feedURL: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'record_podcast_listen',
    app: 'pod',
    kind: 'write',
    scopes: [writeScope('pod')],
    description: 'Record that an episode was listened to (or update progress). Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        episodeID: { type: 'string' },
        podcastID: { type: 'string' },
        episodeTitle: { type: 'string' },
        podcastTitle: { type: 'string' },
        feedURL: { type: 'string' },
        duration: { type: 'number' },
        playbackPosition: { type: 'number' },
        isPlayed: { type: 'boolean' },
      },
      required: ['episodeTitle'],
      additionalProperties: false,
    },
  },

  // vid min
  {
    name: 'list_video_subscriptions',
    app: 'vid',
    kind: 'read',
    scopes: [readScope('vid')],
    description: 'List subscribed YouTube channels.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 200, default: 50 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'subscribe_channel',
    app: 'vid',
    kind: 'write',
    scopes: [writeScope('vid')],
    description: 'Subscribe to a channel by id or title. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        channelID: { type: 'string' },
        title: { type: 'string' },
        thumbnailURL: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'unsubscribe_channel',
    app: 'vid',
    kind: 'write',
    scopes: [writeScope('vid')],
    description: 'Unsubscribe from a channel. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        channelID: { type: 'string' },
        title: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'set_video_watch_state',
    app: 'vid',
    kind: 'write',
    scopes: [writeScope('vid')],
    description: 'Mark a video watched/completed or update progress. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        videoID: { type: 'string' },
        title: { type: 'string' },
        channelID: { type: 'string' },
        progressSeconds: { type: 'number' },
        isCompleted: { type: 'boolean' },
      },
      additionalProperties: false,
    },
  },

  // cyc min
  {
    name: 'list_races',
    app: 'cyc',
    kind: 'read',
    scopes: [readScope('cyc')],
    description: 'List races, optionally filtered to saved / watched / listened.',
    inputSchema: {
      type: 'object',
      properties: {
        saved: { type: 'boolean' },
        watched: { type: 'boolean' },
        listened: { type: 'boolean' },
        query: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 200, default: 50 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'set_race_status',
    app: 'cyc',
    kind: 'write',
    scopes: [writeScope('cyc')],
    description: 'Set saved, watched, or listened status for a race. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        raceId: { type: 'string' },
        name: { type: 'string' },
        saved: { type: 'boolean' },
        watched: { type: 'boolean' },
        listened: { type: 'boolean' },
      },
      additionalProperties: false,
    },
  },

  // spin min
  {
    name: 'list_bikes',
    app: 'spin',
    kind: 'read',
    scopes: [readScope('spin')],
    description: 'List saved bikes and wheelsets.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'list_rides',
    app: 'spin',
    kind: 'read',
    scopes: [readScope('spin')],
    description: 'List recent logged rides.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'log_ride',
    app: 'spin',
    kind: 'write',
    scopes: [writeScope('spin')],
    description: 'Log a ride (distance, date, optional bike). Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        distanceKm: { type: 'number' },
        date: { type: 'string', description: 'ISO-8601 date. Defaults to now.' },
        bikeId: { type: 'string' },
        notes: { type: 'string' },
      },
      required: ['distanceKm'],
      additionalProperties: false,
    },
  },
  {
    name: 'calculate_tire_pressure',
    app: 'spin',
    kind: 'read',
    scopes: [readScope('spin')],
    description: 'Calculate recommended front/rear tire pressure without writing data.',
    inputSchema: {
      type: 'object',
      properties: {
        riderWeightKg: { type: 'number' },
        bikeType: { type: 'string', enum: ['road', 'gravel', 'mountain', 'fat'] },
        tireWidthMM: { type: 'number' },
        terrain: { type: 'string', enum: ['smooth', 'mixed', 'rough', 'technical'] },
      },
      required: ['riderWeightKg', 'tireWidthMM'],
      additionalProperties: false,
    },
  },

  // fit min
  {
    name: 'list_timers',
    app: 'fit',
    kind: 'read',
    scopes: [readScope('fit')],
    description: 'List saved interval timers.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'create_timer',
    app: 'fit',
    kind: 'write',
    scopes: [writeScope('fit')],
    description: 'Create an interval timer. Reversible via undo.',
    inputSchema: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        reps: { type: 'integer', minimum: 1, maximum: 100 },
        workSeconds: { type: 'integer', minimum: 1 },
        restSeconds: { type: 'integer', minimum: 1 },
        intervalType: { type: 'string', enum: ['fixed', 'ladder', 'pyramid', 'wave'] },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'start_timer',
    app: 'fit',
    kind: 'write',
    scopes: [writeScope('fit')],
    description: 'Start a saved timer by id or title. Reversible via undo (cancels the pending start).',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'delete_timer',
    app: 'fit',
    kind: 'write',
    scopes: [writeScope('fit')],
    description:
      'Delete a timer. Requires confirm=true. Reversible via undo within 7 days.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        confirm: { type: 'boolean' },
      },
      required: ['confirm'],
      additionalProperties: false,
    },
  },
];

export function toolByName(name) {
  return TOOLS.find((tool) => tool.name === name) ?? null;
}

export function toolsForScopes(scopes) {
  const granted = new Set(expandScopes(scopes));
  return TOOLS.filter((tool) => tool.scopes.every((scope) => granted.has(scope)));
}

export function assertAppId(appId) {
  if (!APP_IDS.includes(appId)) {
    throw new AgentError('unknown_app', `Unknown app "${appId}".`);
  }
}

export class AgentError extends Error {
  constructor(code, message, status = 400, extras = {}) {
    super(message);
    this.name = 'AgentError';
    this.code = code;
    this.status = status;
    this.extras = extras;
  }

  toJSON() {
    return { error: this.code, message: this.message, ...this.extras };
  }
}
