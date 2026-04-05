/**
 * Deep Linking Module
 * 
 * Comprehensive deep linking system for min apps with bias towards
 * opening content in min apps first, respecting user preferences.
 */

// Core URL schemes and patterns
export {
  APP_IDS,
  URL_SCHEMES,
  CONTENT_TYPES,
  EXTERNAL_SERVICES,
  CONTENT_TYPE_TO_APPS,
  DEEP_LINK_PATTERNS,
  parseExternalUrl,
  buildDeepLink,
  buildUniversalLink,
  isMinAppDeepLink,
  extractAppIdFromDeepLink,
} from './urlSchemes.js';

// App preferences management
export {
  loadDeepLinkPreferences,
  saveDeepLinkPreferences,
  getPreferredApp,
  setPreferredApp,
  resetPreference,
  resetAllPreferences,
  getInstalledApps,
  setFallbackBehavior,
  setPreferMinApps,
  setExternalAppPreference,
  getPreferencesSummary,
  validatePreferences,
  exportPreferences,
  importPreferences,
} from './appPreferences.js';

// Link opening utilities
export {
  PLATFORMS,
  detectPlatform,
  canOpenURL,
  setCanOpenURLHandler,
  openURL,
  setOpenURLHandler,
  buildContentDeepLink,
  OPEN_RESULT,
  openLink,
  openLinks,
  previewLinkOpen,
  openContent,
  createShareableLink,
} from './linkOpener.js';

// Content mappers and ID utilities
export {
  ID_TYPES,
  extractIdFromUrl,
  normalizeId,
  convertId,
  URL_BUILDERS,
  buildServiceUrl,
  extractAllIdsFromText,
  validateId,
  getContentTypeForIdType,
  parseSearchQuery,
  createContentReference,
} from './contentMappers.js';

// React hooks
export {
  useDeepLinkPreferences,
  useOpenLink,
  useLinkPreview,
  useUrlParser,
  useShareableLink,
  useDeepLinkAnalytics,
  usePreferredApp,
} from './hooks.js';

// React components
export {
  DeepLink,
  LinkPreview,
  AppPreferenceSelector,
  DeepLinkPreferencesPanel,
  SmartLink,
  ContentButton,
  ShareButton,
  DeepLinkProvider,
  useDeepLinkContext,
} from './components.js';

// Default export with all utilities
export default {
  // Core
  APP_IDS,
  URL_SCHEMES,
  CONTENT_TYPES,
  
  // Functions
  parseExternalUrl,
  buildDeepLink,
  openLink,
  openContent,
  getPreferredApp,
  setPreferredApp,
  loadDeepLinkPreferences,
  saveDeepLinkPreferences,
  
  // Utilities
  extractIdFromUrl,
  buildServiceUrl,
  createShareableLink,
};
