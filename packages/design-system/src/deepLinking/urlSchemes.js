/**
 * URL Schemes and Deep Link Definitions for Min Apps
 * 
 * This module defines all supported URL schemes, patterns, and mappings
 * for deep linking across the min apps ecosystem.
 */

/**
 * App identifiers matching the notification system
 */
export const APP_IDS = {
  CYCLISMO: 'cyclismo',
  PODLINK: 'podlink',
  WATCHEDIT: 'watchedit',
  YOURTUBE: 'yourtube'
};

/**
 * URL schemes for each min app
 */
export const URL_SCHEMES = {
  [APP_IDS.WATCHEDIT]: {
    scheme: 'watchedit://',
    appScheme: 'watchedit',
    universalLinkDomains: ['watchedit.app', 'www.watchedit.app'],
    name: 'WatchedIt',
    description: 'Movie and TV tracking app'
  },
  [APP_IDS.PODLINK]: {
    scheme: 'podlink://',
    appScheme: 'podlink',
    universalLinkDomains: ['podlink.app', 'www.podlink.app'],
    name: 'Podlink',
    description: 'Podcast queue and management app'
  },
  [APP_IDS.YOURTUBE]: {
    scheme: 'yourtube://',
    appScheme: 'yourtube',
    universalLinkDomains: ['yourtube.app', 'www.yourtube.app'],
    name: 'Yourtube',
    description: 'YouTube video queue and management app'
  },
  [APP_IDS.CYCLISMO]: {
    scheme: 'cyclismo://',
    appScheme: 'cyclismo',
    universalLinkDomains: ['cyclismo.app', 'www.cyclismo.app'],
    name: 'Cyclismo Guide',
    description: 'Cycling race tracking and guide app'
  }
};

/**
 * Content types that can be deep linked
 */
export const CONTENT_TYPES = {
  MOVIE: 'movie',
  TV_SHOW: 'tv_show',
  PERSON: 'person',
  PODCAST: 'podcast',
  PODCAST_EPISODE: 'podcast_episode',
  VIDEO: 'video',
  CHANNEL: 'channel',
  PLAYLIST: 'playlist',
  RACE: 'race',
  RIDER: 'rider',
  TEAM: 'team',
  STAGE: 'stage'
};

/**
 * External service URL patterns
 */
export const EXTERNAL_SERVICES = {
  // Movie/TV services
  TMDB: {
    name: 'The Movie Database',
    patterns: [
      /^https?:\/\/(www\.)?themoviedb\.org\/movie\/(\d+)/,
      /^https?:\/\/(www\.)?themoviedb\.org\/tv\/(\d+)/,
      /^https?:\/\/(www\.)?themoviedb\.org\/person\/(\d+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/movie/')) return CONTENT_TYPES.MOVIE;
      if (url.includes('/tv/')) return CONTENT_TYPES.TV_SHOW;
      if (url.includes('/person/')) return CONTENT_TYPES.PERSON;
      return null;
    }
  },
  IMDB: {
    name: 'IMDb',
    patterns: [
      /^https?:\/\/(www\.)?imdb\.com\/title\/(tt\d+)/,
      /^https?:\/\/(www\.)?imdb\.com\/name\/(nm\d+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/title/')) return CONTENT_TYPES.MOVIE;
      if (url.includes('/name/')) return CONTENT_TYPES.PERSON;
      return null;
    }
  },
  
  // Podcast services
  APPLE_PODCASTS: {
    name: 'Apple Podcasts',
    patterns: [
      /^https?:\/\/podcasts\.apple\.com\/[a-z]{2}\/podcast\/[^/]+\/id(\d+)/,
      /^https?:\/\/podcasts\.apple\.com\/[a-z]{2}\/podcast\/id(\d+)/
    ],
    contentTypeExtractor: () => CONTENT_TYPES.PODCAST
  },
  SPOTIFY_PODCAST: {
    name: 'Spotify Podcasts',
    patterns: [
      /^https?:\/\/open\.spotify\.com\/show\/([a-zA-Z0-9]+)/,
      /^https?:\/\/open\.spotify\.com\/episode\/([a-zA-Z0-9]+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/show/')) return CONTENT_TYPES.PODCAST;
      if (url.includes('/episode/')) return CONTENT_TYPES.PODCAST_EPISODE;
      return null;
    }
  },
  OVERCAST: {
    name: 'Overcast',
    patterns: [
      /^https?:\/\/overcast\.fm\/\+([a-zA-Z0-9]+)/,
      /^https?:\/\/overcast\.fm\/itunes(\d+)/
    ],
    contentTypeExtractor: () => CONTENT_TYPES.PODCAST
  },
  POCKET_CASTS: {
    name: 'Pocket Casts',
    patterns: [
      /^https?:\/\/(www\.)?pocketcasts\.com\/podcast\/([a-z0-9-]+)/
    ],
    contentTypeExtractor: () => CONTENT_TYPES.PODCAST
  },
  
  // YouTube/Video services
  YOUTUBE: {
    name: 'YouTube',
    patterns: [
      /^https?:\/\/(www\.)?youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/,
      /^https?:\/\/youtu\.be\/([a-zA-Z0-9_-]+)/,
      /^https?:\/\/(www\.)?youtube\.com\/channel\/([a-zA-Z0-9_-]+)/,
      /^https?:\/\/(www\.)?youtube\.com\/@([a-zA-Z0-9_-]+)/,
      /^https?:\/\/(www\.)?youtube\.com\/playlist\?list=([a-zA-Z0-9_-]+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/watch?') || url.includes('youtu.be/')) return CONTENT_TYPES.VIDEO;
      if (url.includes('/channel/') || url.includes('/@')) return CONTENT_TYPES.CHANNEL;
      if (url.includes('/playlist?')) return CONTENT_TYPES.PLAYLIST;
      return null;
    }
  },
  
  // Cycling services
  PROCYCLINGSTATS: {
    name: 'ProCyclingStats',
    patterns: [
      /^https?:\/\/(www\.)?procyclingstats\.com\/race\/([^/]+)/,
      /^https?:\/\/(www\.)?procyclingstats\.com\/rider\/([^/]+)/,
      /^https?:\/\/(www\.)?procyclingstats\.com\/team\/([^/]+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/race/')) return CONTENT_TYPES.RACE;
      if (url.includes('/rider/')) return CONTENT_TYPES.RIDER;
      if (url.includes('/team/')) return CONTENT_TYPES.TEAM;
      return null;
    }
  },
  CYCLINGNEWS: {
    name: 'CyclingNews',
    patterns: [
      /^https?:\/\/(www\.)?cyclingnews\.com\/races\/([^/]+)/,
      /^https?:\/\/(www\.)?cyclingnews\.com\/riders\/([^/]+)/
    ],
    contentTypeExtractor: (url) => {
      if (url.includes('/races/')) return CONTENT_TYPES.RACE;
      if (url.includes('/riders/')) return CONTENT_TYPES.RIDER;
      return null;
    }
  }
};

/**
 * Mapping of content types to the apps that can handle them
 */
export const CONTENT_TYPE_TO_APPS = {
  [CONTENT_TYPES.MOVIE]: [APP_IDS.WATCHEDIT],
  [CONTENT_TYPES.TV_SHOW]: [APP_IDS.WATCHEDIT],
  [CONTENT_TYPES.PERSON]: [APP_IDS.WATCHEDIT],
  [CONTENT_TYPES.PODCAST]: [APP_IDS.PODLINK],
  [CONTENT_TYPES.PODCAST_EPISODE]: [APP_IDS.PODLINK],
  [CONTENT_TYPES.VIDEO]: [APP_IDS.YOURTUBE],
  [CONTENT_TYPES.CHANNEL]: [APP_IDS.YOURTUBE],
  [CONTENT_TYPES.PLAYLIST]: [APP_IDS.YOURTUBE],
  [CONTENT_TYPES.RACE]: [APP_IDS.CYCLISMO],
  [CONTENT_TYPES.RIDER]: [APP_IDS.CYCLISMO],
  [CONTENT_TYPES.TEAM]: [APP_IDS.CYCLISMO],
  [CONTENT_TYPES.STAGE]: [APP_IDS.CYCLISMO]
};

/**
 * Deep link path patterns for each app
 */
export const DEEP_LINK_PATTERNS = {
  [APP_IDS.WATCHEDIT]: {
    movie: '/movie/:id',
    tvShow: '/tv/:id',
    person: '/person/:id',
    search: '/search?q=:query',
    discover: '/discover',
    library: '/library',
    settings: '/settings'
  },
  [APP_IDS.PODLINK]: {
    podcast: '/podcast/:id',
    episode: '/episode/:id',
    queue: '/queue',
    discover: '/discover',
    library: '/library',
    settings: '/settings'
  },
  [APP_IDS.YOURTUBE]: {
    video: '/video/:id',
    channel: '/channel/:id',
    playlist: '/playlist/:id',
    queue: '/queue',
    discover: '/discover',
    library: '/library',
    settings: '/settings'
  },
  [APP_IDS.CYCLISMO]: {
    race: '/race/:id',
    rider: '/rider/:id',
    team: '/team/:id',
    stage: '/stage/:raceId/:stageId',
    calendar: '/calendar',
    favorites: '/favorites',
    settings: '/settings'
  }
};

/**
 * Parse a URL to extract service information and content details
 */
export function parseExternalUrl(url) {
  if (!url) return null;

  for (const [serviceKey, service] of Object.entries(EXTERNAL_SERVICES)) {
    for (const pattern of service.patterns) {
      const match = url.match(pattern);
      if (match) {
        const contentType = service.contentTypeExtractor(url);
        return {
          service: serviceKey,
          serviceName: service.name,
          contentType,
          url,
          match,
          extractedId: match[2] || match[1],
          canHandle: contentType ? CONTENT_TYPE_TO_APPS[contentType] : []
        };
      }
    }
  }

  return null;
}

/**
 * Build a deep link URL for a specific app and content
 */
export function buildDeepLink(appId, path, params = {}) {
  const appConfig = URL_SCHEMES[appId];
  if (!appConfig) {
    throw new Error(`Unknown app ID: ${appId}`);
  }

  let deepLinkPath = path;
  
  // Replace path parameters
  Object.entries(params).forEach(([key, value]) => {
    deepLinkPath = deepLinkPath.replace(`:${key}`, encodeURIComponent(value));
  });

  return `${appConfig.scheme}${deepLinkPath.replace(/^\//, '')}`;
}

/**
 * Build a universal link for a specific app and content
 */
export function buildUniversalLink(appId, path, params = {}) {
  const appConfig = URL_SCHEMES[appId];
  if (!appConfig) {
    throw new Error(`Unknown app ID: ${appId}`);
  }

  let universalPath = path;
  
  // Replace path parameters
  Object.entries(params).forEach(([key, value]) => {
    universalPath = universalPath.replace(`:${key}`, encodeURIComponent(value));
  });

  const domain = appConfig.universalLinkDomains[0];
  return `https://${domain}${universalPath}`;
}

/**
 * Check if a URL is a deep link for any min app
 */
export function isMinAppDeepLink(url) {
  if (!url) return false;
  
  for (const appConfig of Object.values(URL_SCHEMES)) {
    if (url.startsWith(appConfig.scheme)) return true;
    for (const domain of appConfig.universalLinkDomains) {
      if (url.includes(domain)) return true;
    }
  }
  
  return false;
}

/**
 * Extract app ID from a deep link URL
 */
export function extractAppIdFromDeepLink(url) {
  if (!url) return null;
  
  for (const [appId, appConfig] of Object.entries(URL_SCHEMES)) {
    if (url.startsWith(appConfig.scheme)) return appId;
    for (const domain of appConfig.universalLinkDomains) {
      if (url.includes(domain)) return appId;
    }
  }
  
  return null;
}
