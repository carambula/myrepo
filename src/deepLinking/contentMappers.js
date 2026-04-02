/**
 * Content Type Mappers
 * 
 * Utilities for mapping between different content identifier systems
 * (e.g., TMDB IDs, IMDb IDs, Apple Podcast IDs, etc.)
 */

import { CONTENT_TYPES, EXTERNAL_SERVICES } from './urlSchemes.js';

/**
 * ID type enumeration
 */
export const ID_TYPES = {
  // Movie/TV IDs
  TMDB_MOVIE: 'tmdb_movie',
  TMDB_TV: 'tmdb_tv',
  TMDB_PERSON: 'tmdb_person',
  IMDB: 'imdb',
  
  // Podcast IDs
  APPLE_PODCAST: 'apple_podcast',
  SPOTIFY_SHOW: 'spotify_show',
  SPOTIFY_EPISODE: 'spotify_episode',
  RSS_FEED: 'rss_feed',
  
  // Video IDs
  YOUTUBE_VIDEO: 'youtube_video',
  YOUTUBE_CHANNEL: 'youtube_channel',
  YOUTUBE_PLAYLIST: 'youtube_playlist',
  
  // Cycling IDs
  PCS_RACE: 'pcs_race',
  PCS_RIDER: 'pcs_rider',
  PCS_TEAM: 'pcs_team',
  UCI_CODE: 'uci_code',
};

/**
 * Extract ID and type from a URL
 */
export function extractIdFromUrl(url) {
  if (!url) return null;

  // TMDB
  const tmdbMovieMatch = url.match(/themoviedb\.org\/movie\/(\d+)/);
  if (tmdbMovieMatch) {
    return {
      type: ID_TYPES.TMDB_MOVIE,
      id: tmdbMovieMatch[1],
      contentType: CONTENT_TYPES.MOVIE,
    };
  }

  const tmdbTvMatch = url.match(/themoviedb\.org\/tv\/(\d+)/);
  if (tmdbTvMatch) {
    return {
      type: ID_TYPES.TMDB_TV,
      id: tmdbTvMatch[1],
      contentType: CONTENT_TYPES.TV_SHOW,
    };
  }

  const tmdbPersonMatch = url.match(/themoviedb\.org\/person\/(\d+)/);
  if (tmdbPersonMatch) {
    return {
      type: ID_TYPES.TMDB_PERSON,
      id: tmdbPersonMatch[1],
      contentType: CONTENT_TYPES.PERSON,
    };
  }

  // IMDb
  const imdbMatch = url.match(/imdb\.com\/(title|name)\/(tt\d+|nm\d+)/);
  if (imdbMatch) {
    return {
      type: ID_TYPES.IMDB,
      id: imdbMatch[2],
      contentType: imdbMatch[1] === 'title' ? CONTENT_TYPES.MOVIE : CONTENT_TYPES.PERSON,
    };
  }

  // Apple Podcasts
  const applePodcastMatch = url.match(/podcasts\.apple\.com\/[a-z]{2}\/podcast\/(?:[^/]+\/)?id(\d+)/);
  if (applePodcastMatch) {
    return {
      type: ID_TYPES.APPLE_PODCAST,
      id: applePodcastMatch[1],
      contentType: CONTENT_TYPES.PODCAST,
    };
  }

  // Spotify
  const spotifyShowMatch = url.match(/open\.spotify\.com\/show\/([a-zA-Z0-9]+)/);
  if (spotifyShowMatch) {
    return {
      type: ID_TYPES.SPOTIFY_SHOW,
      id: spotifyShowMatch[1],
      contentType: CONTENT_TYPES.PODCAST,
    };
  }

  const spotifyEpisodeMatch = url.match(/open\.spotify\.com\/episode\/([a-zA-Z0-9]+)/);
  if (spotifyEpisodeMatch) {
    return {
      type: ID_TYPES.SPOTIFY_EPISODE,
      id: spotifyEpisodeMatch[1],
      contentType: CONTENT_TYPES.PODCAST_EPISODE,
    };
  }

  // YouTube
  const youtubeVideoMatch = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]+)/);
  if (youtubeVideoMatch) {
    return {
      type: ID_TYPES.YOUTUBE_VIDEO,
      id: youtubeVideoMatch[1],
      contentType: CONTENT_TYPES.VIDEO,
    };
  }

  const youtubeChannelMatch = url.match(/youtube\.com\/channel\/([a-zA-Z0-9_-]+)/);
  if (youtubeChannelMatch) {
    return {
      type: ID_TYPES.YOUTUBE_CHANNEL,
      id: youtubeChannelMatch[1],
      contentType: CONTENT_TYPES.CHANNEL,
    };
  }

  const youtubeHandleMatch = url.match(/youtube\.com\/@([a-zA-Z0-9_-]+)/);
  if (youtubeHandleMatch) {
    return {
      type: ID_TYPES.YOUTUBE_CHANNEL,
      id: youtubeHandleMatch[1],
      contentType: CONTENT_TYPES.CHANNEL,
      isHandle: true,
    };
  }

  const youtubePlaylistMatch = url.match(/youtube\.com\/playlist\?list=([a-zA-Z0-9_-]+)/);
  if (youtubePlaylistMatch) {
    return {
      type: ID_TYPES.YOUTUBE_PLAYLIST,
      id: youtubePlaylistMatch[1],
      contentType: CONTENT_TYPES.PLAYLIST,
    };
  }

  // ProCyclingStats
  const pcsRaceMatch = url.match(/procyclingstats\.com\/race\/([^/]+)/);
  if (pcsRaceMatch) {
    return {
      type: ID_TYPES.PCS_RACE,
      id: pcsRaceMatch[1],
      contentType: CONTENT_TYPES.RACE,
    };
  }

  const pcsRiderMatch = url.match(/procyclingstats\.com\/rider\/([^/]+)/);
  if (pcsRiderMatch) {
    return {
      type: ID_TYPES.PCS_RIDER,
      id: pcsRiderMatch[1],
      contentType: CONTENT_TYPES.RIDER,
    };
  }

  const pcsTeamMatch = url.match(/procyclingstats\.com\/team\/([^/]+)/);
  if (pcsTeamMatch) {
    return {
      type: ID_TYPES.PCS_TEAM,
      id: pcsTeamMatch[1],
      contentType: CONTENT_TYPES.TEAM,
    };
  }

  return null;
}

/**
 * Normalize different ID formats to a common format
 */
export function normalizeId(id, fromType) {
  if (!id || !fromType) return null;

  // Most IDs are already in a good format
  // This is where you'd add normalization logic if needed
  
  switch (fromType) {
    case ID_TYPES.IMDB:
      // Ensure IMDb IDs have the correct prefix
      if (!id.startsWith('tt') && !id.startsWith('nm')) {
        return null;
      }
      return id;
      
    case ID_TYPES.TMDB_MOVIE:
    case ID_TYPES.TMDB_TV:
    case ID_TYPES.TMDB_PERSON:
    case ID_TYPES.APPLE_PODCAST:
      // Ensure these are numeric
      return /^\d+$/.test(id) ? id : null;
      
    case ID_TYPES.YOUTUBE_VIDEO:
    case ID_TYPES.YOUTUBE_CHANNEL:
    case ID_TYPES.YOUTUBE_PLAYLIST:
    case ID_TYPES.SPOTIFY_SHOW:
    case ID_TYPES.SPOTIFY_EPISODE:
      // Alphanumeric with underscores and hyphens
      return /^[a-zA-Z0-9_-]+$/.test(id) ? id : null;
      
    default:
      return id;
  }
}

/**
 * Convert between ID types (if possible)
 * This would require API calls in a real implementation
 */
export async function convertId(id, fromType, toType, options = {}) {
  const { apiHandler = null } = options;
  
  // If no API handler is provided, we can't do conversions
  if (!apiHandler) {
    console.warn('No API handler provided for ID conversion');
    return null;
  }

  // This is where you'd implement actual conversion logic
  // For example, converting IMDb ID to TMDB ID via TMDB's find API
  
  try {
    return await apiHandler(id, fromType, toType);
  } catch (error) {
    console.error('Error converting ID:', error);
    return null;
  }
}

/**
 * Build URLs for different services from IDs
 */
export const URL_BUILDERS = {
  [ID_TYPES.TMDB_MOVIE]: (id) => `https://www.themoviedb.org/movie/${id}`,
  [ID_TYPES.TMDB_TV]: (id) => `https://www.themoviedb.org/tv/${id}`,
  [ID_TYPES.TMDB_PERSON]: (id) => `https://www.themoviedb.org/person/${id}`,
  [ID_TYPES.IMDB]: (id) => {
    const prefix = id.startsWith('nm') ? 'name' : 'title';
    return `https://www.imdb.com/${prefix}/${id}`;
  },
  [ID_TYPES.APPLE_PODCAST]: (id) => `https://podcasts.apple.com/us/podcast/id${id}`,
  [ID_TYPES.SPOTIFY_SHOW]: (id) => `https://open.spotify.com/show/${id}`,
  [ID_TYPES.SPOTIFY_EPISODE]: (id) => `https://open.spotify.com/episode/${id}`,
  [ID_TYPES.YOUTUBE_VIDEO]: (id) => `https://www.youtube.com/watch?v=${id}`,
  [ID_TYPES.YOUTUBE_CHANNEL]: (id) => {
    // If it looks like a handle (no UC prefix), use @ format
    if (!id.startsWith('UC')) {
      return `https://www.youtube.com/@${id}`;
    }
    return `https://www.youtube.com/channel/${id}`;
  },
  [ID_TYPES.YOUTUBE_PLAYLIST]: (id) => `https://www.youtube.com/playlist?list=${id}`,
  [ID_TYPES.PCS_RACE]: (id) => `https://www.procyclingstats.com/race/${id}`,
  [ID_TYPES.PCS_RIDER]: (id) => `https://www.procyclingstats.com/rider/${id}`,
  [ID_TYPES.PCS_TEAM]: (id) => `https://www.procyclingstats.com/team/${id}`,
};

/**
 * Build a URL for a specific service
 */
export function buildServiceUrl(id, idType) {
  const builder = URL_BUILDERS[idType];
  if (!builder) {
    throw new Error(`No URL builder for ID type: ${idType}`);
  }
  
  const normalizedId = normalizeId(id, idType);
  if (!normalizedId) {
    throw new Error(`Invalid ID format: ${id} for type ${idType}`);
  }
  
  return builder(normalizedId);
}

/**
 * Extract all IDs from a piece of text (useful for parsing messages, etc.)
 */
export function extractAllIdsFromText(text) {
  if (!text) return [];

  const ids = [];
  const urlRegex = /https?:\/\/[^\s<>"]+/g;
  const urls = text.match(urlRegex) || [];

  for (const url of urls) {
    const extracted = extractIdFromUrl(url);
    if (extracted) {
      ids.push({
        ...extracted,
        url,
      });
    }
  }

  return ids;
}

/**
 * Validate an ID format
 */
export function validateId(id, idType) {
  const normalized = normalizeId(id, idType);
  return normalized !== null;
}

/**
 * Get the content type for an ID type
 */
export function getContentTypeForIdType(idType) {
  switch (idType) {
    case ID_TYPES.TMDB_MOVIE:
    case ID_TYPES.IMDB:
      return CONTENT_TYPES.MOVIE;
      
    case ID_TYPES.TMDB_TV:
      return CONTENT_TYPES.TV_SHOW;
      
    case ID_TYPES.TMDB_PERSON:
      return CONTENT_TYPES.PERSON;
      
    case ID_TYPES.APPLE_PODCAST:
    case ID_TYPES.SPOTIFY_SHOW:
      return CONTENT_TYPES.PODCAST;
      
    case ID_TYPES.SPOTIFY_EPISODE:
      return CONTENT_TYPES.PODCAST_EPISODE;
      
    case ID_TYPES.YOUTUBE_VIDEO:
      return CONTENT_TYPES.VIDEO;
      
    case ID_TYPES.YOUTUBE_CHANNEL:
      return CONTENT_TYPES.CHANNEL;
      
    case ID_TYPES.YOUTUBE_PLAYLIST:
      return CONTENT_TYPES.PLAYLIST;
      
    case ID_TYPES.PCS_RACE:
      return CONTENT_TYPES.RACE;
      
    case ID_TYPES.PCS_RIDER:
      return CONTENT_TYPES.RIDER;
      
    case ID_TYPES.PCS_TEAM:
      return CONTENT_TYPES.TEAM;
      
    default:
      return null;
  }
}

/**
 * Parse a search query to detect potential content references
 */
export function parseSearchQuery(query) {
  if (!query) return null;

  const results = {
    originalQuery: query,
    detectedIds: [],
    detectedUrls: [],
    cleanQuery: query,
  };

  // Extract URLs
  const urlRegex = /https?:\/\/[^\s<>"]+/g;
  const urls = query.match(urlRegex) || [];
  
  for (const url of urls) {
    const extracted = extractIdFromUrl(url);
    if (extracted) {
      results.detectedUrls.push(url);
      results.detectedIds.push(extracted);
      results.cleanQuery = results.cleanQuery.replace(url, '').trim();
    }
  }

  // Detect IMDb IDs in text
  const imdbRegex = /(tt\d{7,8}|nm\d{7,8})/g;
  const imdbMatches = query.match(imdbRegex) || [];
  
  for (const imdbId of imdbMatches) {
    results.detectedIds.push({
      type: ID_TYPES.IMDB,
      id: imdbId,
      contentType: imdbId.startsWith('nm') ? CONTENT_TYPES.PERSON : CONTENT_TYPES.MOVIE,
    });
    results.cleanQuery = results.cleanQuery.replace(imdbId, '').trim();
  }

  return results;
}

/**
 * Create a content reference object (useful for storing in databases)
 */
export function createContentReference(contentType, id, idType, metadata = {}) {
  return {
    contentType,
    id,
    idType,
    normalizedId: normalizeId(id, idType),
    url: buildServiceUrl(id, idType),
    metadata: {
      ...metadata,
      createdAt: new Date().toISOString(),
    },
  };
}
