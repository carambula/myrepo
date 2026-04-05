/**
 * Link Opener Utility
 * 
 * Handles opening links with a bias towards deep linking and using user's preferred apps.
 * Always attempts to open in a min app first before falling back to external apps or web.
 */

import {
  parseExternalUrl,
  buildDeepLink,
  buildUniversalLink,
  isMinAppDeepLink,
  DEEP_LINK_PATTERNS,
  APP_IDS,
  URL_SCHEMES,
  CONTENT_TYPES,
} from './urlSchemes.js';

import {
  loadDeepLinkPreferences,
  getPreferredApp,
} from './appPreferences.js';

/**
 * Platform detection
 */
export const PLATFORMS = {
  IOS: 'ios',
  ANDROID: 'android',
  WEB: 'web',
  UNKNOWN: 'unknown',
};

/**
 * Detect current platform
 */
export function detectPlatform() {
  if (typeof navigator === 'undefined') {
    return PLATFORMS.UNKNOWN;
  }

  const userAgent = navigator.userAgent || navigator.vendor || window.opera;

  if (/android/i.test(userAgent)) {
    return PLATFORMS.ANDROID;
  }

  if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
    return PLATFORMS.IOS;
  }

  return PLATFORMS.WEB;
}

/**
 * Check if an app can be opened (platform-specific)
 * This should be overridden by the host app with native implementations
 */
let canOpenURLHandler = null;

export function setCanOpenURLHandler(handler) {
  canOpenURLHandler = handler;
}

export async function canOpenURL(url) {
  if (canOpenURLHandler) {
    return await canOpenURLHandler(url);
  }

  // Default implementation for web
  // On native platforms, this should be overridden with Linking.canOpenURL
  return true;
}

/**
 * Open a URL (platform-specific)
 * This should be overridden by the host app with native implementations
 */
let openURLHandler = null;

export function setOpenURLHandler(handler) {
  openURLHandler = handler;
}

export async function openURL(url, target = '_blank') {
  if (openURLHandler) {
    return await openURLHandler(url, target);
  }

  // Default implementation for web
  if (typeof window !== 'undefined') {
    window.open(url, target);
    return true;
  }

  return false;
}

/**
 * Content type specific deep link builders
 */
const CONTENT_BUILDERS = {
  [CONTENT_TYPES.MOVIE]: (id, appId = APP_IDS.WATCHEDIT) => ({
    path: DEEP_LINK_PATTERNS[appId].movie,
    params: { id },
  }),
  
  [CONTENT_TYPES.TV_SHOW]: (id, appId = APP_IDS.WATCHEDIT) => ({
    path: DEEP_LINK_PATTERNS[appId].tvShow,
    params: { id },
  }),
  
  [CONTENT_TYPES.PERSON]: (id, appId = APP_IDS.WATCHEDIT) => ({
    path: DEEP_LINK_PATTERNS[appId].person,
    params: { id },
  }),
  
  [CONTENT_TYPES.PODCAST]: (id, appId = APP_IDS.PODLINK) => ({
    path: DEEP_LINK_PATTERNS[appId].podcast,
    params: { id },
  }),
  
  [CONTENT_TYPES.PODCAST_EPISODE]: (id, appId = APP_IDS.PODLINK) => ({
    path: DEEP_LINK_PATTERNS[appId].episode,
    params: { id },
  }),
  
  [CONTENT_TYPES.VIDEO]: (id, appId = APP_IDS.YOURTUBE) => ({
    path: DEEP_LINK_PATTERNS[appId].video,
    params: { id },
  }),
  
  [CONTENT_TYPES.CHANNEL]: (id, appId = APP_IDS.YOURTUBE) => ({
    path: DEEP_LINK_PATTERNS[appId].channel,
    params: { id },
  }),
  
  [CONTENT_TYPES.PLAYLIST]: (id, appId = APP_IDS.YOURTUBE) => ({
    path: DEEP_LINK_PATTERNS[appId].playlist,
    params: { id },
  }),
  
  [CONTENT_TYPES.RACE]: (id, appId = APP_IDS.CYCLISMO) => ({
    path: DEEP_LINK_PATTERNS[appId].race,
    params: { id },
  }),
  
  [CONTENT_TYPES.RIDER]: (id, appId = APP_IDS.CYCLISMO) => ({
    path: DEEP_LINK_PATTERNS[appId].rider,
    params: { id },
  }),
  
  [CONTENT_TYPES.TEAM]: (id, appId = APP_IDS.CYCLISMO) => ({
    path: DEEP_LINK_PATTERNS[appId].team,
    params: { id },
  }),
  
  [CONTENT_TYPES.STAGE]: (raceId, stageId, appId = APP_IDS.CYCLISMO) => ({
    path: DEEP_LINK_PATTERNS[appId].stage,
    params: { raceId, stageId },
  }),
};

/**
 * Build a deep link for specific content
 */
export function buildContentDeepLink(contentType, contentId, appId = null) {
  const preferredApp = appId || getPreferredApp(contentType);
  if (!preferredApp) {
    throw new Error(`No app available for content type: ${contentType}`);
  }

  const builder = CONTENT_BUILDERS[contentType];
  if (!builder) {
    throw new Error(`No builder for content type: ${contentType}`);
  }

  const { path, params } = builder(contentId, preferredApp);
  return buildDeepLink(preferredApp, path, params);
}

/**
 * Result of attempting to open a link
 */
export const OPEN_RESULT = {
  SUCCESS: 'success',
  FALLBACK_TO_WEB: 'fallback_to_web',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
};

/**
 * Main function to open any link with deep linking preference
 */
export async function openLink(url, options = {}) {
  const {
    forceWeb = false,
    forceApp = null,
    skipDeepLink = false,
    onBeforeOpen = null,
    onFallback = null,
    target = '_blank',
  } = options;

  // Call before open hook
  if (onBeforeOpen) {
    const shouldContinue = await onBeforeOpen(url);
    if (shouldContinue === false) {
      return { result: OPEN_RESULT.CANCELLED };
    }
  }

  // If it's already a min app deep link, just open it
  if (isMinAppDeepLink(url)) {
    await openURL(url, target);
    return { result: OPEN_RESULT.SUCCESS, method: 'deeplink', url };
  }

  // If forced to open in web, do that
  if (forceWeb) {
    await openURL(url, target);
    return { result: OPEN_RESULT.SUCCESS, method: 'web', url };
  }

  // If skip deep link, open directly
  if (skipDeepLink) {
    await openURL(url, target);
    return { result: OPEN_RESULT.SUCCESS, method: 'direct', url };
  }

  // Try to parse the URL and find a min app that can handle it
  const parsed = parseExternalUrl(url);
  
  if (!parsed || !parsed.contentType) {
    // Unknown URL type, just open it
    await openURL(url, target);
    return { result: OPEN_RESULT.SUCCESS, method: 'web', url };
  }

  // Get user preferences
  const preferences = loadDeepLinkPreferences();
  
  // Determine which app to use
  let targetApp = forceApp;
  if (!targetApp) {
    targetApp = getPreferredApp(parsed.contentType, preferences);
  }

  if (!targetApp) {
    // No app configured for this content type
    if (onFallback) {
      await onFallback(url, parsed);
    }
    await openURL(url, target);
    return { 
      result: OPEN_RESULT.FALLBACK_TO_WEB, 
      method: 'web', 
      url,
      reason: 'no_app_configured',
    };
  }

  // Build the deep link
  try {
    const deepLink = buildContentDeepLink(
      parsed.contentType,
      parsed.extractedId,
      targetApp
    );

    // Try to open the deep link
    const canOpen = await canOpenURL(deepLink);
    
    if (canOpen) {
      await openURL(deepLink, target);
      return { 
        result: OPEN_RESULT.SUCCESS, 
        method: 'deeplink', 
        url: deepLink,
        originalUrl: url,
        appId: targetApp,
      };
    } else {
      // Deep link failed, fall back to web
      if (onFallback) {
        await onFallback(url, parsed);
      }
      await openURL(url, target);
      return { 
        result: OPEN_RESULT.FALLBACK_TO_WEB, 
        method: 'web', 
        url,
        reason: 'app_not_installed',
        attemptedDeepLink: deepLink,
      };
    }
  } catch (error) {
    console.error('Error building deep link:', error);
    
    if (onFallback) {
      await onFallback(url, parsed);
    }
    
    await openURL(url, target);
    return { 
      result: OPEN_RESULT.FALLBACK_TO_WEB, 
      method: 'web', 
      url,
      reason: 'deep_link_error',
      error: error.message,
    };
  }
}

/**
 * Batch open multiple links (useful for sharing or opening related content)
 */
export async function openLinks(urls, options = {}) {
  const results = [];
  
  for (const url of urls) {
    const result = await openLink(url, options);
    results.push(result);
    
    // Small delay between opens to avoid overwhelming the system
    if (urls.length > 1) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }
  
  return results;
}

/**
 * Preview what would happen when opening a link (without actually opening it)
 */
export async function previewLinkOpen(url) {
  const parsed = parseExternalUrl(url);
  
  if (!parsed) {
    return {
      url,
      canDeepLink: false,
      method: 'web',
      info: 'Unknown URL type, will open in browser',
    };
  }

  const targetApp = getPreferredApp(parsed.contentType);
  
  if (!targetApp) {
    return {
      url,
      canDeepLink: false,
      method: 'web',
      contentType: parsed.contentType,
      service: parsed.serviceName,
      info: 'No app configured for this content type',
    };
  }

  try {
    const deepLink = buildContentDeepLink(
      parsed.contentType,
      parsed.extractedId,
      targetApp
    );

    return {
      url,
      canDeepLink: true,
      method: 'deeplink',
      deepLink,
      appId: targetApp,
      appName: URL_SCHEMES[targetApp].name,
      contentType: parsed.contentType,
      service: parsed.serviceName,
      info: `Will open in ${URL_SCHEMES[targetApp].name}`,
    };
  } catch (error) {
    return {
      url,
      canDeepLink: false,
      method: 'web',
      error: error.message,
      info: 'Error building deep link, will open in browser',
    };
  }
}

/**
 * Utility to open content directly with content details
 */
export async function openContent(contentType, contentId, options = {}) {
  const { appId = null, ...otherOptions } = options;
  
  const targetApp = appId || getPreferredApp(contentType);
  if (!targetApp) {
    throw new Error(`No app available for content type: ${contentType}`);
  }

  const deepLink = buildContentDeepLink(contentType, contentId, targetApp);
  return await openLink(deepLink, otherOptions);
}

/**
 * Create a shareable link that will deep link when possible
 * This generates a universal link that works on all platforms
 */
export function createShareableLink(contentType, contentId, appId = null) {
  const targetApp = appId || getPreferredApp(contentType);
  if (!targetApp) {
    throw new Error(`No app available for content type: ${contentType}`);
  }

  const builder = CONTENT_BUILDERS[contentType];
  if (!builder) {
    throw new Error(`No builder for content type: ${contentType}`);
  }

  const { path, params } = builder(contentId, targetApp);
  return buildUniversalLink(targetApp, path, params);
}
