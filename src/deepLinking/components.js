/**
 * React Components for Deep Linking
 * 
 * Ready-to-use components for deep linking functionality
 */

import React, { useState, useCallback } from 'react';
import { useOpenLink, useLinkPreview, useDeepLinkPreferences } from './hooks.js';
import { CONTENT_TYPES, URL_SCHEMES, APP_IDS } from './urlSchemes.js';

/**
 * DeepLink component - automatically handles deep linking for any URL
 */
export function DeepLink({ 
  href, 
  children, 
  forceWeb = false,
  forceApp = null,
  onBeforeOpen = null,
  onAfterOpen = null,
  className = '',
  style = {},
  ...props 
}) {
  const { open } = useOpenLink();

  const handleClick = useCallback(async (e) => {
    e.preventDefault();
    
    const result = await open(href, {
      forceWeb,
      forceApp,
      onBeforeOpen,
    });

    if (onAfterOpen) {
      onAfterOpen(result);
    }
  }, [href, forceWeb, forceApp, onBeforeOpen, onAfterOpen, open]);

  return (
    <a 
      href={href} 
      onClick={handleClick}
      className={className}
      style={style}
      {...props}
    >
      {children}
    </a>
  );
}

/**
 * LinkPreview component - shows what will happen when a link is clicked
 */
export function LinkPreview({ url, showDetails = true }) {
  const { preview, loading } = useLinkPreview(url);

  if (loading) {
    return (
      <div className="deep-link-preview">
        <div
          className="min-content-status min-content-status--loading"
          role="status"
          aria-live="polite"
        >
          <span className="min-content-status__spinner" aria-hidden="true" />
          <span className="min-content-status__label">Loading preview…</span>
        </div>
      </div>
    );
  }

  if (!preview) {
    return null;
  }

  return (
    <div className="deep-link-preview">
      {preview.canDeepLink && (
        <div className="deep-link-preview-badge">
          <span className="deep-link-preview-icon">🔗</span>
          <span className="deep-link-preview-text">
            Opens in {preview.appName}
          </span>
        </div>
      )}
      
      {showDetails && (
        <div className="deep-link-preview-details">
          <div className="deep-link-preview-method">
            Method: {preview.method}
          </div>
          {preview.contentType && (
            <div className="deep-link-preview-content-type">
              Type: {preview.contentType}
            </div>
          )}
          {preview.service && (
            <div className="deep-link-preview-service">
              From: {preview.service}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

/**
 * AppPreferenceSelector - UI for selecting preferred apps
 */
export function AppPreferenceSelector({ contentType, label = null }) {
  const { preferences, setPreferredApp } = useDeepLinkPreferences();
  const currentPreference = preferences.preferences[contentType];

  const handleChange = useCallback((e) => {
    const appId = e.target.value || null;
    setPreferredApp(contentType, appId);
  }, [contentType, setPreferredApp]);

  const contentTypeLabels = {
    [CONTENT_TYPES.MOVIE]: 'Movies',
    [CONTENT_TYPES.TV_SHOW]: 'TV Shows',
    [CONTENT_TYPES.PERSON]: 'People',
    [CONTENT_TYPES.PODCAST]: 'Podcasts',
    [CONTENT_TYPES.PODCAST_EPISODE]: 'Podcast Episodes',
    [CONTENT_TYPES.VIDEO]: 'Videos',
    [CONTENT_TYPES.CHANNEL]: 'Channels',
    [CONTENT_TYPES.PLAYLIST]: 'Playlists',
    [CONTENT_TYPES.RACE]: 'Races',
    [CONTENT_TYPES.RIDER]: 'Riders',
    [CONTENT_TYPES.TEAM]: 'Teams',
    [CONTENT_TYPES.STAGE]: 'Stages',
  };

  return (
    <div className="app-preference-selector">
      <label htmlFor={`pref-${contentType}`}>
        {label || contentTypeLabels[contentType] || contentType}
      </label>
      <select
        id={`pref-${contentType}`}
        value={currentPreference || ''}
        onChange={handleChange}
        className="app-preference-select"
      >
        <option value="">Default</option>
        {Object.entries(URL_SCHEMES).map(([appId, config]) => (
          <option key={appId} value={appId}>
            {config.name}
          </option>
        ))}
      </select>
    </div>
  );
}

/**
 * DeepLinkPreferencesPanel - Complete UI for managing all deep link preferences
 */
export function DeepLinkPreferencesPanel({ title = 'Deep Link Preferences' }) {
  const { preferences, setPreferredApp, summary } = useDeepLinkPreferences();

  const contentTypeGroups = {
    'Movies & TV': [CONTENT_TYPES.MOVIE, CONTENT_TYPES.TV_SHOW, CONTENT_TYPES.PERSON],
    'Podcasts': [CONTENT_TYPES.PODCAST, CONTENT_TYPES.PODCAST_EPISODE],
    'Videos': [CONTENT_TYPES.VIDEO, CONTENT_TYPES.CHANNEL, CONTENT_TYPES.PLAYLIST],
    'Cycling': [CONTENT_TYPES.RACE, CONTENT_TYPES.RIDER, CONTENT_TYPES.TEAM, CONTENT_TYPES.STAGE],
  };

  return (
    <div className="deep-link-preferences-panel">
      <h2>{title}</h2>
      
      <div className="deep-link-preferences-description">
        Choose which min app should open when you click links from external sources.
      </div>

      {Object.entries(contentTypeGroups).map(([groupName, contentTypes]) => (
        <div key={groupName} className="deep-link-preference-group">
          <h3>{groupName}</h3>
          {contentTypes.map(contentType => (
            <AppPreferenceSelector 
              key={contentType} 
              contentType={contentType}
            />
          ))}
        </div>
      ))}

      <div className="deep-link-preferences-summary">
        <h3>Summary</h3>
        <div>Configured: {summary.configured.length}</div>
        <div>Using defaults: {summary.defaults.length}</div>
      </div>
    </div>
  );
}

/**
 * SmartLink - Link that shows preview on hover and uses deep linking
 */
export function SmartLink({ 
  href, 
  children, 
  showPreviewOnHover = true,
  ...props 
}) {
  const [showPreview, setShowPreview] = useState(false);
  const { open } = useOpenLink();

  const handleClick = useCallback(async (e) => {
    e.preventDefault();
    await open(href);
  }, [href, open]);

  return (
    <span 
      className="smart-link-container"
      onMouseEnter={() => showPreviewOnHover && setShowPreview(true)}
      onMouseLeave={() => setShowPreview(false)}
    >
      <a href={href} onClick={handleClick} {...props}>
        {children}
      </a>
      {showPreview && <LinkPreview url={href} showDetails={false} />}
    </span>
  );
}

/**
 * ContentButton - Button to open specific content by ID
 */
export function ContentButton({
  contentType,
  contentId,
  appId = null,
  children,
  className = '',
  onSuccess = null,
  onError = null,
  ...props
}) {
  const { openContent, isOpening } = useOpenLink();

  const handleClick = useCallback(async () => {
    try {
      const result = await openContent(contentType, contentId, { appId });
      if (onSuccess) {
        onSuccess(result);
      }
    } catch (error) {
      if (onError) {
        onError(error);
      }
    }
  }, [contentType, contentId, appId, openContent, onSuccess, onError]);

  return (
    <button
      onClick={handleClick}
      disabled={isOpening}
      className={`content-button ${className}`}
      {...props}
    >
      {isOpening ? 'Opening...' : children}
    </button>
  );
}

/**
 * ShareButton - Button to share content via deep link
 */
export function ShareButton({
  contentType,
  contentId,
  appId = null,
  children = 'Share',
  className = '',
  onShare = null,
  ...props
}) {
  const [copied, setCopied] = useState(false);

  const handleShare = useCallback(async () => {
    try {
      const { createShareableLink } = await import('./linkOpener.js');
      const link = createShareableLink(contentType, contentId, appId);

      if (navigator.share) {
        await navigator.share({
          url: link,
          title: 'Check this out',
        });
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(link);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }

      if (onShare) {
        onShare(link);
      }
    } catch (error) {
      console.error('Error sharing:', error);
    }
  }, [contentType, contentId, appId, onShare]);

  return (
    <button
      onClick={handleShare}
      className={`share-button ${className}`}
      {...props}
    >
      {copied ? 'Copied!' : children}
    </button>
  );
}

/**
 * DeepLinkProvider - Context provider for deep linking configuration
 */
const DeepLinkContext = React.createContext(null);

export function DeepLinkProvider({ 
  children, 
  canOpenURLHandler = null,
  openURLHandler = null,
  onLinkOpen = null,
}) {
  const { setCanOpenURLHandler, setOpenURLHandler } = require('./linkOpener.js');

  React.useEffect(() => {
    if (canOpenURLHandler) {
      setCanOpenURLHandler(canOpenURLHandler);
    }
    if (openURLHandler) {
      setOpenURLHandler(openURLHandler);
    }
  }, [canOpenURLHandler, openURLHandler]);

  const contextValue = React.useMemo(() => ({
    onLinkOpen,
  }), [onLinkOpen]);

  return (
    <DeepLinkContext.Provider value={contextValue}>
      {children}
    </DeepLinkContext.Provider>
  );
}

export function useDeepLinkContext() {
  const context = React.useContext(DeepLinkContext);
  if (!context) {
    console.warn('useDeepLinkContext must be used within DeepLinkProvider');
  }
  return context;
}
