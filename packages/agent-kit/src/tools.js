import { AgentError } from './protocol.js';

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function includesQuery(haystack, query) {
  if (!query) return true;
  return normalize(haystack).includes(normalize(query));
}

function slugId(prefix, title) {
  const slug = normalize(title).replace(/\s+/g, '-') || 'item';
  return `${prefix}-${slug}`;
}

function requireOne(input, keys) {
  const found = keys.find((key) => input[key] != null && String(input[key]).trim() !== '');
  if (!found) {
    throw new AgentError('invalid_input', `Provide ${keys.join(' or ')}.`);
  }
}

function uniqueMatch(items, matcher, label) {
  const matches = items.filter(matcher);
  if (matches.length === 1) return matches[0];
  if (matches.length === 0) {
    throw new AgentError('not_found', `No ${label} matched.`, 404);
  }
  throw new AgentError('ambiguous', `Multiple ${label}s matched. Be more specific.`, 409, {
    candidates: matches.slice(0, 8),
  });
}

function movieMatches(movie, input) {
  if (input.id && (movie.id === input.id || String(movie.tmdbId ?? '') === String(input.id))) {
    return true;
  }
  if (input.title) {
    const titleHit = normalize(movie.title) === normalize(input.title)
      || normalize(movie.title).includes(normalize(input.title));
    if (!titleHit) return false;
    if (input.year != null && movie.year != null && Number(movie.year) !== Number(input.year)) {
      return false;
    }
    return true;
  }
  if (input.year != null && movie.year != null && Number(movie.year) === Number(input.year) && !input.id) {
    return false;
  }
  return false;
}

function findMovie(library, input) {
  requireOne(input, ['id', 'title']);
  return uniqueMatch(library.movies, (movie) => movieMatches(movie, input), 'movie');
}

function podcastMatches(podcast, input) {
  if (input.id && podcast.id === input.id) return true;
  if (input.feedURL && podcast.feedURL === input.feedURL) return true;
  if (input.title && (normalize(podcast.title) === normalize(input.title)
    || normalize(podcast.title).includes(normalize(input.title)))) {
    return true;
  }
  return false;
}

export const toolHandlers = {
  list_movies(library, input = {}) {
    const { saved, rewatched, listened, query, limit = 50 } = input;
    const hasFilter = saved != null || rewatched != null || listened != null || query;
    let items = library.movies;
    if (!hasFilter) {
      items = items.filter((movie) => movie.isSaved || movie.isRewatched);
    }
    if (saved != null) items = items.filter((movie) => movie.isSaved === saved);
    if (rewatched != null) items = items.filter((movie) => movie.isRewatched === rewatched);
    if (listened != null) items = items.filter((movie) => movie.isListened === listened);
    if (query) {
      items = items.filter((movie) => includesQuery(`${movie.title} ${movie.year ?? ''} ${movie.id}`, query));
    }
    return { movies: items.slice(0, limit), total: items.length };
  },

  search_movies(library, input = {}) {
    const { query, limit = 10 } = input;
    const items = library.movies.filter((movie) =>
      includesQuery(`${movie.title} ${movie.year ?? ''} ${movie.id} ${movie.overview ?? ''}`, query)
    );
    return { movies: items.slice(0, limit), total: items.length };
  },

  get_movie(library, input = {}) {
    return { movie: findMovie(library, input) };
  },

  set_movie_saved(library, input = {}) {
    const movie = findMovie(library, input);
    const before = { ...movie };
    movie.isSaved = Boolean(input.saved);
    return {
      result: { movie },
      before: { movies: [before] },
      after: { movies: [{ ...movie }] },
      summary: input.saved ? `Saved ${movie.title}` : `Removed ${movie.title} from saved`,
    };
  },

  set_movie_rewatched(library, input = {}) {
    const movie = findMovie(library, input);
    const before = { ...movie };
    movie.isRewatched = Boolean(input.rewatched);
    return {
      result: { movie },
      before: { movies: [before] },
      after: { movies: [{ ...movie }] },
      summary: input.rewatched ? `Marked ${movie.title} rewatched` : `Cleared rewatched on ${movie.title}`,
    };
  },

  set_movie_listened(library, input = {}) {
    const movie = findMovie(library, input);
    const before = { ...movie };
    movie.isListened = Boolean(input.listened);
    return {
      result: { movie },
      before: { movies: [before] },
      after: { movies: [{ ...movie }] },
      summary: input.listened ? `Marked ${movie.title} listened` : `Cleared listened on ${movie.title}`,
    };
  },

  upsert_movie(library, input = {}) {
    const existing = library.movies.find((movie) =>
      (input.id && movie.id === input.id)
      || (input.tmdbId != null && movie.tmdbId === input.tmdbId)
      || (normalize(movie.title) === normalize(input.title) && (input.year == null || movie.year === input.year))
    );
    if (existing) {
      const before = { ...existing };
      if (input.overview != null) existing.overview = input.overview;
      if (input.year != null) existing.year = input.year;
      if (input.tmdbId != null) existing.tmdbId = input.tmdbId;
      if (input.saved != null) existing.isSaved = Boolean(input.saved);
      if (input.rewatched != null) existing.isRewatched = Boolean(input.rewatched);
      if (input.listened != null) existing.isListened = Boolean(input.listened);
      return {
        result: { movie: existing, created: false },
        before: { movies: [before] },
        after: { movies: [{ ...existing }] },
        summary: `Updated ${existing.title}`,
      };
    }
    const movie = {
      id: input.id || slugId('mov', input.title),
      title: input.title,
      year: input.year ?? null,
      tmdbId: input.tmdbId ?? null,
      overview: input.overview ?? '',
      isSaved: input.saved ?? true,
      isRewatched: input.rewatched ?? false,
      isListened: input.listened ?? false,
    };
    library.movies.push(movie);
    return {
      result: { movie, created: true },
      before: { movies: [] },
      after: { movies: [{ ...movie }] },
      summary: `Added ${movie.title}`,
    };
  },

  list_podcasts(library, input = {}) {
    let items = library.podcasts.filter((podcast) => podcast.isFollowed !== false);
    if (input.query) {
      items = items.filter((podcast) =>
        includesQuery(`${podcast.title} ${podcast.author ?? ''} ${podcast.feedURL ?? ''}`, input.query)
      );
    }
    return { podcasts: items.slice(0, input.limit ?? 50), total: items.length };
  },

  list_listening_history(library, input = {}) {
    let items = [...library.listeningHistory].sort((a, b) =>
      String(b.lastListenedAt || '').localeCompare(String(a.lastListenedAt || ''))
    );
    if (input.query) {
      items = items.filter((entry) =>
        includesQuery(`${entry.episodeTitle} ${entry.podcastTitle}`, input.query)
      );
    }
    return { history: items.slice(0, input.limit ?? 25), total: items.length };
  },

  search_podcasts(library, input = {}) {
    const items = library.podcasts.filter((podcast) =>
      includesQuery(`${podcast.title} ${podcast.author ?? ''}`, input.query)
    );
    return { podcasts: items.slice(0, input.limit ?? 8), total: items.length };
  },

  follow_podcast(library, input = {}) {
    requireOne(input, ['id', 'title', 'feedURL']);
    const existing = library.podcasts.find((podcast) => podcastMatches(podcast, input));
    if (existing) {
      const before = { ...existing };
      existing.isFollowed = true;
      return {
        result: { podcast: existing, created: false },
        before: { podcasts: [before] },
        after: { podcasts: [{ ...existing }] },
        summary: `Followed ${existing.title}`,
      };
    }
    const podcast = {
      id: input.id || slugId('pod', input.title || input.feedURL),
      title: input.title || input.feedURL || 'Podcast',
      author: input.author || '',
      feedURL: input.feedURL || '',
      artworkURL: input.artworkURL || null,
      isFollowed: true,
    };
    library.podcasts.push(podcast);
    return {
      result: { podcast, created: true },
      before: { podcasts: [] },
      after: { podcasts: [{ ...podcast }] },
      summary: `Added ${podcast.title}`,
    };
  },

  unfollow_podcast(library, input = {}) {
    requireOne(input, ['id', 'title', 'feedURL']);
    const podcast = uniqueMatch(library.podcasts, (item) => podcastMatches(item, input), 'podcast');
    const before = { ...podcast };
    podcast.isFollowed = false;
    return {
      result: { podcast },
      before: { podcasts: [before] },
      after: { podcasts: [{ ...podcast }] },
      summary: `Unfollowed ${podcast.title}`,
    };
  },

  record_podcast_listen(library, input = {}) {
    const episodeID = input.episodeID || slugId('ep', input.episodeTitle);
    const existing = library.listeningHistory.find((entry) => entry.episodeID === episodeID);
    const incoming = {
      episodeID,
      podcastID: input.podcastID || '',
      episodeTitle: input.episodeTitle,
      podcastTitle: input.podcastTitle || '',
      feedURL: input.feedURL || '',
      duration: input.duration ?? 0,
      playbackPosition: input.playbackPosition ?? 0,
      isPlayed: input.isPlayed ?? true,
      lastListenedAt: new Date().toISOString(),
    };
    if (existing) {
      const before = { ...existing };
      Object.assign(existing, incoming);
      return {
        result: { entry: existing },
        before: { listeningHistory: [before] },
        after: { listeningHistory: [{ ...existing }] },
        summary: `Updated listen for ${incoming.episodeTitle}`,
      };
    }
    library.listeningHistory.push(incoming);
    return {
      result: { entry: incoming },
      before: { listeningHistory: [] },
      after: { listeningHistory: [{ ...incoming }] },
      summary: `Recorded listen for ${incoming.episodeTitle}`,
    };
  },

  list_video_subscriptions(library, input = {}) {
    let items = library.channels.filter((channel) => channel.isUserSubscribed !== false);
    if (input.query) {
      items = items.filter((channel) => includesQuery(`${channel.title} ${channel.channelID}`, input.query));
    }
    return { channels: items.slice(0, input.limit ?? 50), total: items.length };
  },

  subscribe_channel(library, input = {}) {
    requireOne(input, ['channelID', 'title']);
    const existing = library.channels.find((channel) =>
      (input.channelID && channel.channelID === input.channelID)
      || (input.title && normalize(channel.title) === normalize(input.title))
    );
    if (existing) {
      const before = { ...existing };
      existing.isUserSubscribed = true;
      return {
        result: { channel: existing },
        before: { channels: [before] },
        after: { channels: [{ ...existing }] },
        summary: `Subscribed to ${existing.title}`,
      };
    }
    const channel = {
      channelID: input.channelID || slugId('yt', input.title),
      title: input.title || input.channelID,
      thumbnailURL: input.thumbnailURL || '',
      isUserSubscribed: true,
    };
    library.channels.push(channel);
    return {
      result: { channel, created: true },
      before: { channels: [] },
      after: { channels: [{ ...channel }] },
      summary: `Subscribed to ${channel.title}`,
    };
  },

  unsubscribe_channel(library, input = {}) {
    requireOne(input, ['channelID', 'title']);
    const channel = uniqueMatch(
      library.channels,
      (item) =>
        (input.channelID && item.channelID === input.channelID)
        || (input.title && normalize(item.title).includes(normalize(input.title))),
      'channel'
    );
    const before = { ...channel };
    channel.isUserSubscribed = false;
    return {
      result: { channel },
      before: { channels: [before] },
      after: { channels: [{ ...channel }] },
      summary: `Unsubscribed from ${channel.title}`,
    };
  },

  set_video_watch_state(library, input = {}) {
    requireOne(input, ['videoID', 'title']);
    const videoID = input.videoID || slugId('vid', input.title);
    const existing = library.watchState.find((item) => item.videoID === videoID);
    const incoming = {
      videoID,
      title: input.title || existing?.title || videoID,
      channelID: input.channelID || existing?.channelID || '',
      progressSeconds: input.progressSeconds ?? existing?.progressSeconds ?? 0,
      isCompleted: input.isCompleted ?? true,
      lastWatchedAt: new Date().toISOString(),
    };
    if (existing) {
      const before = { ...existing };
      Object.assign(existing, incoming);
      return {
        result: { watchState: existing },
        before: { watchState: [before] },
        after: { watchState: [{ ...existing }] },
        summary: `Updated watch state for ${incoming.title}`,
      };
    }
    library.watchState.push(incoming);
    return {
      result: { watchState: incoming },
      before: { watchState: [] },
      after: { watchState: [{ ...incoming }] },
      summary: `Marked ${incoming.title} watched`,
    };
  },

  list_races(library, input = {}) {
    let items = library.races;
    const hasStatusFilter = input.saved != null || input.watched != null || input.listened != null;
    if (!hasStatusFilter && !input.query) {
      items = items.filter((race) => race.isSaved || race.isWatched || race.isListened);
    }
    if (input.saved != null) items = items.filter((race) => race.isSaved === input.saved);
    if (input.watched != null) items = items.filter((race) => race.isWatched === input.watched);
    if (input.listened != null) items = items.filter((race) => race.isListened === input.listened);
    if (input.query) {
      items = items.filter((race) => includesQuery(`${race.name} ${race.raceId} ${race.series ?? ''}`, input.query));
    }
    return { races: items.slice(0, input.limit ?? 50), total: items.length };
  },

  set_race_status(library, input = {}) {
    requireOne(input, ['raceId', 'name']);
    let race = library.races.find((item) =>
      (input.raceId && item.raceId === input.raceId)
      || (input.name && normalize(item.name) === normalize(input.name))
    );
    const before = race ? { ...race } : null;
    if (!race) {
      race = {
        raceId: input.raceId || slugId('race', input.name),
        name: input.name || input.raceId,
        series: '',
        isSaved: false,
        isWatched: false,
        isListened: false,
      };
      library.races.push(race);
    }
    if (input.saved != null) race.isSaved = Boolean(input.saved);
    if (input.watched != null) race.isWatched = Boolean(input.watched);
    if (input.listened != null) race.isListened = Boolean(input.listened);
    return {
      result: { race },
      before: { races: before ? [before] : [] },
      after: { races: [{ ...race }] },
      summary: `Updated ${race.name}`,
    };
  },

  list_bikes(library, input = {}) {
    let items = library.bikes;
    if (input.query) {
      items = items.filter((bike) => includesQuery(`${bike.name} ${bike.id}`, input.query));
    }
    return { bikes: items };
  },

  list_rides(library, input = {}) {
    const items = [...library.rides].sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
    return { rides: items.slice(0, input.limit ?? 20), total: items.length };
  },

  log_ride(library, input = {}) {
    const ride = {
      id: slugId('ride', `${input.date || 'now'}-${input.distanceKm}`),
      distanceKm: Number(input.distanceKm),
      date: input.date || new Date().toISOString(),
      bikeId: input.bikeId || null,
      notes: input.notes || '',
    };
    library.rides.push(ride);
    return {
      result: { ride },
      before: { rides: [] },
      after: { rides: [{ ...ride }] },
      summary: `Logged ${ride.distanceKm} km ride`,
    };
  },

  calculate_tire_pressure(_library, input = {}) {
    const weight = Number(input.riderWeightKg);
    const width = Number(input.tireWidthMM);
    const terrain = input.terrain || 'mixed';
    const bikeType = input.bikeType || 'road';
    const terrainMul = { smooth: 1, mixed: 0.95, rough: 0.9, technical: 0.7 }[terrain] ?? 0.95;
    const split = { road: 0.48, gravel: 0.47, mountain: 0.465, fat: 0.45 }[bikeType] ?? 0.48;
    const base = (weight * 0.7) / Math.max(width / 25, 0.6);
    const front = Math.round(base * split * terrainMul * 10) / 10;
    const rear = Math.round(base * (1 - split) * terrainMul * 10) / 10;
    return {
      result: {
        bikeType,
        terrain,
        frontPsi: front,
        rearPsi: rear,
        note: 'Estimate only. Confirm against tire and rim manufacturer limits.',
      },
    };
  },

  list_timers(library, input = {}) {
    let items = library.timers;
    if (input.query) {
      items = items.filter((timer) => includesQuery(`${timer.title} ${timer.id}`, input.query));
    }
    return { timers: items, activeTimerId: library.activeTimerId };
  },

  create_timer(library, input = {}) {
    const timer = {
      id: slugId('timer', input.title || `${input.workSeconds || 45}s`),
      title: input.title || `${input.reps || 3} × ${input.workSeconds || 45}s`,
      reps: input.reps ?? 3,
      workSeconds: input.workSeconds ?? 45,
      restSeconds: input.restSeconds ?? 15,
      intervalType: input.intervalType || 'fixed',
      completedCount: 0,
    };
    library.timers.push(timer);
    return {
      result: { timer },
      before: { timers: [] },
      after: { timers: [{ ...timer }] },
      summary: `Created timer ${timer.title}`,
    };
  },

  start_timer(library, input = {}) {
    requireOne(input, ['id', 'title']);
    const timer = uniqueMatch(
      library.timers,
      (item) =>
        (input.id && item.id === input.id)
        || (input.title && normalize(item.title).includes(normalize(input.title))),
      'timer'
    );
    const previous = library.activeTimerId;
    library.activeTimerId = timer.id;
    return {
      result: { timer, started: true },
      before: { activeTimerId: previous },
      after: { activeTimerId: timer.id },
      summary: `Started ${timer.title}`,
    };
  },

  delete_timer(library, input = {}) {
    if (input.confirm !== true) {
      throw new AgentError(
        'confirmation_required',
        'Deleting a timer requires confirm=true. The delete stays undoable for 7 days.'
      );
    }
    requireOne(input, ['id', 'title']);
    const index = library.timers.findIndex((item) =>
      (input.id && item.id === input.id)
      || (input.title && normalize(item.title) === normalize(input.title))
    );
    if (index < 0) {
      throw new AgentError('not_found', 'No timer matched.', 404);
    }
    const [timer] = library.timers.splice(index, 1);
    const previousActive = library.activeTimerId;
    if (library.activeTimerId === timer.id) library.activeTimerId = null;
    return {
      result: { deleted: timer },
      before: { timers: [timer], activeTimerId: previousActive },
      after: { timers: [], activeTimerId: library.activeTimerId },
      summary: `Deleted timer ${timer.title}`,
    };
  },
};

export function applyUndoPatch(library, patch, side) {
  if (!patch) return;
  if (patch.movies) applyCollection(library.movies, patch.movies, 'id', side);
  if (patch.podcasts) applyCollection(library.podcasts, patch.podcasts, 'id', side);
  if (patch.listeningHistory) applyCollection(library.listeningHistory, patch.listeningHistory, 'episodeID', side);
  if (patch.channels) applyCollection(library.channels, patch.channels, 'channelID', side);
  if (patch.watchState) applyCollection(library.watchState, patch.watchState, 'videoID', side);
  if (patch.races) applyCollection(library.races, patch.races, 'raceId', side);
  if (patch.bikes) applyCollection(library.bikes, patch.bikes, 'id', side);
  if (patch.rides) applyCollection(library.rides, patch.rides, 'id', side);
  if (patch.timers) applyCollection(library.timers, patch.timers, 'id', side);
  if (Object.prototype.hasOwnProperty.call(patch, 'activeTimerId')) {
    library.activeTimerId = side === 'before' ? patch.activeTimerId : patch.activeTimerId;
  }
}

function applyCollection(collection, records, idKey, side) {
  for (const record of records) {
    const index = collection.findIndex((item) => item[idKey] === record[idKey]);
    if (side === 'before') {
      if (index >= 0) collection[index] = { ...record };
      else collection.push({ ...record });
    } else if (side === 'clear-after') {
      if (index >= 0 && records.length === 0) {
        // no-op
      }
    }
  }
}

export function revertWrite(library, record) {
  const before = record.before || {};
  const after = record.after || {};

  revertCollection(library.movies, before.movies, after.movies, 'id');
  revertCollection(library.podcasts, before.podcasts, after.podcasts, 'id');
  revertCollection(library.listeningHistory, before.listeningHistory, after.listeningHistory, 'episodeID');
  revertCollection(library.channels, before.channels, after.channels, 'channelID');
  revertCollection(library.watchState, before.watchState, after.watchState, 'videoID');
  revertCollection(library.races, before.races, after.races, 'raceId');
  revertCollection(library.bikes, before.bikes, after.bikes, 'id');
  revertCollection(library.rides, before.rides, after.rides, 'id');
  revertCollection(library.timers, before.timers, after.timers, 'id');

  if (Object.prototype.hasOwnProperty.call(before, 'activeTimerId')
    || Object.prototype.hasOwnProperty.call(after, 'activeTimerId')) {
    library.activeTimerId = before.activeTimerId ?? null;
  }
}

function revertCollection(collection, beforeItems = [], afterItems = [], idKey) {
  const beforeById = new Map((beforeItems || []).map((item) => [item[idKey], item]));
  const afterById = new Map((afterItems || []).map((item) => [item[idKey], item]));

  for (const [id] of afterById) {
    const index = collection.findIndex((item) => item[idKey] === id);
    if (beforeById.has(id)) {
      if (index >= 0) collection[index] = { ...beforeById.get(id) };
      else collection.push({ ...beforeById.get(id) });
    } else if (index >= 0) {
      collection.splice(index, 1);
    }
  }

  for (const [id, item] of beforeById) {
    if (afterById.has(id)) continue;
    const index = collection.findIndex((row) => row[idKey] === id);
    if (index >= 0) collection[index] = { ...item };
    else collection.push({ ...item });
  }
}
