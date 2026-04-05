/**
 * React Hooks for Deep Linking
 * 
 * Easy-to-use React hooks for integrating deep linking into components
 */

import { useState, useEffect, useCallback, useMemo } from 'react';
import {
  loadDeepLinkPreferences,
  saveDeepLinkPreferences,
  getPreferredApp,
  setPreferredApp as setPreferredAppPref,
  getPreferencesSummary,
} from './appPreferences.js';
import {
  openLink,
  openContent,
  previewLinkOpen,
  createShareableLink,
} from './linkOpener.js';
import {
  parseExternalUrl,
} from './urlSchemes.js';

/**
 * Hook to access and manage deep link preferences
 */
export function useDeepLinkPreferences() {
  const [preferences, setPreferences] = useState(loadDeepLinkPreferences());
  const [loading, setLoading] = useState(false);

  const reload = useCallback(() => {
    setPreferences(loadDeepLinkPreferences());
  }, []);

  const save = useCallback((newPreferences) => {
    setLoading(true);
    const success = saveDeepLinkPreferences(newPreferences);
    if (success) {
      setPreferences(newPreferences);
    }
    setLoading(false);
    return success;
  }, []);

  const setPreferredAppForType = useCallback((contentType, appId) => {
    setLoading(true);
    const success = setPreferredAppPref(contentType, appId);
    if (success) {
      reload();
    }
    setLoading(false);
    return success;
  }, [reload]);

  const summary = useMemo(() => getPreferencesSummary(), [preferences]);

  return {
    preferences,
    loading,
    reload,
    save,
    setPreferredApp: setPreferredAppForType,
    summary,
  };
}

/**
 * Hook to open links with deep linking
 */
export function useOpenLink() {
  const [isOpening, setIsOpening] = useState(false);
  const [lastResult, setLastResult] = useState(null);
  const [error, setError] = useState(null);

  const open = useCallback(async (url, options = {}) => {
    setIsOpening(true);
    setError(null);
    
    try {
      const result = await openLink(url, options);
      setLastResult(result);
      return result;
    } catch (err) {
      setError(err);
      console.error('Error opening link:', err);
      return null;
    } finally {
      setIsOpening(false);
    }
  }, []);

  const openContentById = useCallback(async (contentType, contentId, options = {}) => {
    setIsOpening(true);
    setError(null);
    
    try {
      const result = await openContent(contentType, contentId, options);
      setLastResult(result);
      return result;
    } catch (err) {
      setError(err);
      console.error('Error opening content:', err);
      return null;
    } finally {
      setIsOpening(false);
    }
  }, []);

  return {
    open,
    openContent: openContentById,
    isOpening,
    lastResult,
    error,
  };
}

/**
 * Hook to preview what will happen when a link is opened
 */
export function useLinkPreview(url) {
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!url) {
      setPreview(null);
      return;
    }

    setLoading(true);
    previewLinkOpen(url)
      .then(setPreview)
      .catch(err => {
        console.error('Error previewing link:', err);
        setPreview(null);
      })
      .finally(() => setLoading(false));
  }, [url]);

  return {
    preview,
    loading,
  };
}

/**
 * Hook to parse external URLs
 */
export function useUrlParser(url) {
  const parsed = useMemo(() => {
    if (!url) return null;
    return parseExternalUrl(url);
  }, [url]);

  return parsed;
}

/**
 * Hook to generate shareable links
 */
export function useShareableLink(contentType, contentId, appId = null) {
  const link = useMemo(() => {
    if (!contentType || !contentId) return null;
    
    try {
      return createShareableLink(contentType, contentId, appId);
    } catch (err) {
      console.error('Error creating shareable link:', err);
      return null;
    }
  }, [contentType, contentId, appId]);

  const copyToClipboard = useCallback(async () => {
    if (!link) return false;

    try {
      if (navigator.clipboard) {
        await navigator.clipboard.writeText(link);
        return true;
      }
      return false;
    } catch (err) {
      console.error('Error copying to clipboard:', err);
      return false;
    }
  }, [link]);

  return {
    link,
    copyToClipboard,
  };
}

/**
 * Hook to track deep link analytics
 */
export function useDeepLinkAnalytics() {
  const [analytics, setAnalytics] = useState({
    totalOpens: 0,
    successfulDeepLinks: 0,
    fallbacksToWeb: 0,
    byApp: {},
    byContentType: {},
  });

  const trackOpen = useCallback((result) => {
    setAnalytics(prev => {
      const updated = { ...prev };
      updated.totalOpens++;

      if (result.result === 'success' && result.method === 'deeplink') {
        updated.successfulDeepLinks++;
        
        if (result.appId) {
          updated.byApp[result.appId] = (updated.byApp[result.appId] || 0) + 1;
        }
      } else if (result.result === 'fallback_to_web') {
        updated.fallbacksToWeb++;
      }

      return updated;
    });
  }, []);

  const reset = useCallback(() => {
    setAnalytics({
      totalOpens: 0,
      successfulDeepLinks: 0,
      fallbacksToWeb: 0,
      byApp: {},
      byContentType: {},
    });
  }, []);

  return {
    analytics,
    trackOpen,
    reset,
  };
}

/**
 * Hook to get the preferred app for a content type with auto-refresh
 */
export function usePreferredApp(contentType) {
  const [preferredApp, setPreferredApp] = useState(null);

  useEffect(() => {
    if (!contentType) {
      setPreferredApp(null);
      return;
    }

    const app = getPreferredApp(contentType);
    setPreferredApp(app);
  }, [contentType]);

  return preferredApp;
}
