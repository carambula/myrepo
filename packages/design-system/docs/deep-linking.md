# Deep Linking System

A comprehensive deep linking system for the min apps suite that ensures **every opportunity to open a website or app opens the min app first**, deep linking to content as much as possible, and respecting user preferences.

## Overview

The deep linking system provides:

- **Automatic deep link generation** from external URLs (TMDB, IMDb, YouTube, Spotify, etc.)
- **User preference management** for which apps handle which content types
- **Bias towards min apps** - always attempts to open in a min app first before falling back to web
- **Consistent API** across all platforms (iOS, Android, Web)
- **React hooks and components** for easy integration
- **Content type mapping** for accurate routing

## Key Principles

1. **Min Apps First**: Always attempt to deep link to a min app before opening external links
2. **Respect Preferences**: Honor user's chosen apps for different content types
3. **Graceful Fallback**: If a min app isn't installed, fall back to web
4. **Consistent Experience**: Same API across all platforms and apps
5. **Easy Integration**: Simple hooks and components for developers

## Quick Start

### Basic Link Opening

```javascript
import { openLink } from '@min-apps/design-system/deepLinking';

// Automatically detects content type and opens in appropriate min app
await openLink('https://www.themoviedb.org/movie/550');
// Opens in WatchedIt app with Fight Club movie

await openLink('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
// Opens in Yourtube app with the video

await openLink('https://podcasts.apple.com/us/podcast/example/id12345');
// Opens in Podlink app with the podcast
```

### React Component

```javascript
import { DeepLink } from '@min-apps/design-system/deepLinking';

function MovieLink() {
  return (
    <DeepLink href="https://www.themoviedb.org/movie/550">
      Check out Fight Club
    </DeepLink>
  );
}
```

### React Hook

```javascript
import { useOpenLink } from '@min-apps/design-system/deepLinking';

function MovieButton() {
  const { open, isOpening } = useOpenLink();
  
  return (
    <button 
      onClick={() => open('https://www.themoviedb.org/movie/550')}
      disabled={isOpening}
    >
      Open Movie
    </button>
  );
}
```

## Supported Services

### Movies & TV
- **The Movie Database (TMDB)**: Movies, TV shows, people
- **IMDb**: Movies, TV shows, people

### Podcasts
- **Apple Podcasts**: Shows and episodes
- **Spotify**: Shows and episodes
- **Overcast**: Shows
- **Pocket Casts**: Shows

### Videos
- **YouTube**: Videos, channels, playlists

### Cycling
- **ProCyclingStats**: Races, riders, teams
- **CyclingNews**: Races, riders

## User Preferences

### Managing Preferences

```javascript
import { 
  loadDeepLinkPreferences, 
  setPreferredApp,
  CONTENT_TYPES,
  APP_IDS 
} from '@min-apps/design-system/deepLinking';

// Set WatchedIt as preferred app for movies
setPreferredApp(CONTENT_TYPES.MOVIE, APP_IDS.WATCHEDIT);

// Load all preferences
const preferences = loadDeepLinkPreferences();
```

### React Preference UI

```javascript
import { DeepLinkPreferencesPanel } from '@min-apps/design-system/deepLinking';

function SettingsPage() {
  return (
    <div>
      <h1>Settings</h1>
      <DeepLinkPreferencesPanel title="Choose Your Apps" />
    </div>
  );
}
```

## Content Types

The system recognizes these content types:

```javascript
import { CONTENT_TYPES } from '@min-apps/design-system/deepLinking';

CONTENT_TYPES.MOVIE           // Movies
CONTENT_TYPES.TV_SHOW         // TV shows
CONTENT_TYPES.PERSON          // Actors, directors, etc.
CONTENT_TYPES.PODCAST         // Podcast shows
CONTENT_TYPES.PODCAST_EPISODE // Podcast episodes
CONTENT_TYPES.VIDEO           // YouTube videos
CONTENT_TYPES.CHANNEL         // YouTube channels
CONTENT_TYPES.PLAYLIST        // YouTube playlists
CONTENT_TYPES.RACE            // Cycling races
CONTENT_TYPES.RIDER           // Cyclists
CONTENT_TYPES.TEAM            // Cycling teams
CONTENT_TYPES.STAGE           // Race stages
```

## Advanced Usage

### Opening Content by ID

```javascript
import { openContent, CONTENT_TYPES } from '@min-apps/design-system/deepLinking';

// Open a specific movie in WatchedIt
await openContent(CONTENT_TYPES.MOVIE, '550');

// Open a specific video in Yourtube
await openContent(CONTENT_TYPES.VIDEO, 'dQw4w9WgXcQ');
```

### Preview Link Behavior

```javascript
import { previewLinkOpen } from '@min-apps/design-system/deepLinking';

const preview = await previewLinkOpen('https://www.themoviedb.org/movie/550');
console.log(preview);
// {
//   canDeepLink: true,
//   method: 'deeplink',
//   appId: 'watchedit',
//   appName: 'WatchedIt',
//   contentType: 'movie',
//   service: 'The Movie Database',
//   info: 'Will open in WatchedIt'
// }
```

### Creating Shareable Links

```javascript
import { createShareableLink, CONTENT_TYPES } from '@min-apps/design-system/deepLinking';

// Create a universal link that deep links when possible
const link = createShareableLink(CONTENT_TYPES.MOVIE, '550');
// Returns: https://watchedit.app/movie/550
```

### Custom Link Handlers

```javascript
import { openLink } from '@min-apps/design-system/deepLinking';

await openLink('https://www.themoviedb.org/movie/550', {
  forceApp: 'watchedit',  // Force specific app
  forceWeb: false,         // Don't force web
  onBeforeOpen: async (url) => {
    console.log('About to open:', url);
    return true; // Return false to cancel
  },
  onFallback: async (url, parsed) => {
    console.log('Falling back to web for:', url);
  }
});
```

### Batch Opening

```javascript
import { openLinks } from '@min-apps/design-system/deepLinking';

const urls = [
  'https://www.themoviedb.org/movie/550',
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  'https://podcasts.apple.com/us/podcast/example/id12345'
];

const results = await openLinks(urls);
results.forEach(result => {
  console.log(`${result.url}: ${result.result}`);
});
```

## Platform Integration

### Native iOS/Android

```javascript
import { setCanOpenURLHandler, setOpenURLHandler } from '@min-apps/design-system/deepLinking';
import { Linking } from 'react-native';

// Set up native handlers
setCanOpenURLHandler(async (url) => {
  return await Linking.canOpenURL(url);
});

setOpenURLHandler(async (url) => {
  await Linking.openURL(url);
});
```

### React Native Provider

```javascript
import { DeepLinkProvider } from '@min-apps/design-system/deepLinking';
import { Linking } from 'react-native';

function App() {
  return (
    <DeepLinkProvider
      canOpenURLHandler={(url) => Linking.canOpenURL(url)}
      openURLHandler={(url) => Linking.openURL(url)}
      onLinkOpen={(result) => {
        // Track analytics
        console.log('Link opened:', result);
      }}
    >
      <YourApp />
    </DeepLinkProvider>
  );
}
```

## React Hooks Reference

### `useOpenLink()`

Open links with deep linking support.

```javascript
const { open, openContent, isOpening, lastResult, error } = useOpenLink();
```

### `useDeepLinkPreferences()`

Access and modify user preferences.

```javascript
const { preferences, loading, reload, save, setPreferredApp, summary } = useDeepLinkPreferences();
```

### `useLinkPreview(url)`

Preview what will happen when a link is opened.

```javascript
const { preview, loading } = useLinkPreview('https://example.com');
```

### `useUrlParser(url)`

Parse a URL to extract content information.

```javascript
const parsed = useUrlParser('https://www.themoviedb.org/movie/550');
// { contentType: 'movie', extractedId: '550', service: 'The Movie Database', ... }
```

### `useShareableLink(contentType, contentId, appId)`

Create a shareable universal link.

```javascript
const { link, copyToClipboard } = useShareableLink(CONTENT_TYPES.MOVIE, '550');
```

### `usePreferredApp(contentType)`

Get the user's preferred app for a content type.

```javascript
const preferredApp = usePreferredApp(CONTENT_TYPES.MOVIE);
// Returns: 'watchedit'
```

### `useDeepLinkAnalytics()`

Track deep link usage analytics.

```javascript
const { analytics, trackOpen, reset } = useDeepLinkAnalytics();
```

## React Components Reference

### `<DeepLink>`

Automatically handles deep linking for any URL.

```javascript
<DeepLink 
  href="https://www.themoviedb.org/movie/550"
  forceWeb={false}
  forceApp="watchedit"
  onBeforeOpen={(url) => console.log('Opening:', url)}
  onAfterOpen={(result) => console.log('Opened:', result)}
>
  Click here
</DeepLink>
```

### `<LinkPreview>`

Shows what will happen when a link is clicked.

```javascript
<LinkPreview 
  url="https://www.themoviedb.org/movie/550" 
  showDetails={true}
/>
```

### `<SmartLink>`

Link with preview on hover.

```javascript
<SmartLink 
  href="https://www.themoviedb.org/movie/550"
  showPreviewOnHover={true}
>
  Hover to preview
</SmartLink>
```

### `<ContentButton>`

Button to open specific content.

```javascript
<ContentButton
  contentType={CONTENT_TYPES.MOVIE}
  contentId="550"
  appId="watchedit"
  onSuccess={(result) => console.log('Opened:', result)}
  onError={(error) => console.error('Error:', error)}
>
  Open Movie
</ContentButton>
```

### `<ShareButton>`

Button to share content via deep link.

```javascript
<ShareButton
  contentType={CONTENT_TYPES.MOVIE}
  contentId="550"
  onShare={(link) => console.log('Shared:', link)}
>
  Share
</ShareButton>
```

### `<AppPreferenceSelector>`

UI for selecting preferred app for a content type.

```javascript
<AppPreferenceSelector 
  contentType={CONTENT_TYPES.MOVIE}
  label="Movies open in..."
/>
```

### `<DeepLinkPreferencesPanel>`

Complete UI for managing all preferences.

```javascript
<DeepLinkPreferencesPanel title="Deep Link Preferences" />
```

## Content Mapping

### Extract IDs from URLs

```javascript
import { extractIdFromUrl } from '@min-apps/design-system/deepLinking';

const result = extractIdFromUrl('https://www.themoviedb.org/movie/550');
// { type: 'tmdb_movie', id: '550', contentType: 'movie' }
```

### Build Service URLs

```javascript
import { buildServiceUrl, ID_TYPES } from '@min-apps/design-system/deepLinking';

const url = buildServiceUrl('550', ID_TYPES.TMDB_MOVIE);
// Returns: https://www.themoviedb.org/movie/550
```

### Extract IDs from Text

```javascript
import { extractAllIdsFromText } from '@min-apps/design-system/deepLinking';

const text = "Check out this movie https://www.themoviedb.org/movie/550 and this video https://youtube.com/watch?v=abc123";
const ids = extractAllIdsFromText(text);
// Returns array of all found IDs with their types
```

## Best Practices

### 1. Always Use Deep Links

Whenever you display a link to external content, use the deep linking system:

```javascript
// ❌ Bad - Opens in browser
<a href="https://www.themoviedb.org/movie/550">Movie</a>

// ✅ Good - Opens in WatchedIt app
<DeepLink href="https://www.themoviedb.org/movie/550">Movie</DeepLink>
```

### 2. Respect User Preferences

Always check and respect user preferences:

```javascript
import { getPreferredApp } from '@min-apps/design-system/deepLinking';

const preferredApp = getPreferredApp(CONTENT_TYPES.MOVIE);
if (preferredApp) {
  // Use the preferred app
}
```

### 3. Provide Preference UI

Include preference UI in your app settings:

```javascript
import { DeepLinkPreferencesPanel } from '@min-apps/design-system/deepLinking';

function SettingsPage() {
  return <DeepLinkPreferencesPanel />;
}
```

### 4. Handle Fallbacks Gracefully

Always handle cases where deep linking fails:

```javascript
const result = await openLink(url, {
  onFallback: async (url, parsed) => {
    console.log('Deep link failed, opening in browser');
  }
});
```

### 5. Use Preview for Better UX

Show users what will happen before opening:

```javascript
<SmartLink href={url} showPreviewOnHover={true}>
  Hover to see where this opens
</SmartLink>
```

## Migration Guide

### For Existing Apps

1. **Install the design system** (if not already installed)
2. **Replace all external links** with `<DeepLink>` components
3. **Add preferences UI** to your settings page
4. **Set up platform handlers** (for React Native apps)
5. **Test deep linking** across all supported content types

### Example Migration

Before:
```javascript
function MovieList({ movies }) {
  return (
    <ul>
      {movies.map(movie => (
        <li key={movie.id}>
          <a href={movie.tmdbUrl}>{movie.title}</a>
        </li>
      ))}
    </ul>
  );
}
```

After:
```javascript
import { DeepLink } from '@min-apps/design-system/deepLinking';

function MovieList({ movies }) {
  return (
    <ul>
      {movies.map(movie => (
        <li key={movie.id}>
          <DeepLink href={movie.tmdbUrl}>{movie.title}</DeepLink>
        </li>
      ))}
    </ul>
  );
}
```

## Troubleshooting

### Links not opening in min app

1. Check that the min app is installed
2. Verify URL scheme is registered in app's Info.plist (iOS) or AndroidManifest.xml (Android)
3. Check user preferences: `loadDeepLinkPreferences()`
4. Use `previewLinkOpen()` to debug

### Deep link not recognized

1. Verify the URL pattern is supported (see Supported Services)
2. Check the URL parsing with `parseExternalUrl(url)`
3. Add custom URL patterns if needed

### Preference not saving

1. Check localStorage is available
2. Verify `saveDeepLinkPreferences()` returns `true`
3. Check browser/app permissions for storage

## API Reference

See the full API documentation in the source files:

- `urlSchemes.js` - URL parsing and scheme definitions
- `appPreferences.js` - Preference management
- `linkOpener.js` - Link opening utilities
- `contentMappers.js` - Content ID mapping
- `hooks.js` - React hooks
- `components.js` - React components

## Examples

See `/examples/deep-linking/` for complete working examples for each app.
