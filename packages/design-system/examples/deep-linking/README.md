# Deep Linking Integration Examples

This directory contains comprehensive integration examples for each min app, demonstrating how to implement thorough and consistent deep linking throughout your application.

## Overview

These examples show how to ensure **every opportunity to open a website or app opens the min app first**, with proper deep linking to content and respect for user preferences.

## Examples by App

### WatchedIt (`watchedit-integration.jsx`)

Examples for integrating deep linking into WatchedIt:

- **MovieList**: Display movie lists with TMDB/IMDb deep links
- **MovieDetails**: Open specific movies by ID
- **SearchResults**: Handle search results with deep linking
- **ActorCredits**: Link to actor/person pages
- **ShareMovieButton**: Create shareable deep links
- **WatcheditSettings**: Add preference UI
- **RelatedContent**: Link related movies/shows
- **UserReview**: Parse and link content in user reviews
- **WatchlistImport**: Import from external URLs

**Key Features:**
- All TMDB and IMDb links open in WatchedIt
- Share movies with universal deep links
- Parse movie links in user-generated content
- Import movies from external URLs

### Podlink (`podlink-integration.jsx`)

Examples for integrating deep linking into Podlink:

- **PodcastList**: Display podcasts with Apple Podcasts/Spotify deep links
- **EpisodeList**: Handle episode deep linking
- **QueueManager**: Add podcasts to queue via URL
- **PodcastDiscovery**: Discover podcasts with deep linking
- **SharePodcastButton**: Create shareable podcast links
- **PodlinkSettings**: Add preference UI
- **PriorityPodcasts**: Handle priority podcast notifications
- **RSSFeedImport**: Import from RSS feeds
- **SmartQueueBuilder**: Build queue from various sources

**Key Features:**
- All Apple Podcasts, Spotify, Overcast links open in Podlink
- Smart queue building from multiple sources
- RSS feed import with deep linking
- Priority podcast handling

### Yourtube (`yourtube-integration.jsx`)

Examples for integrating deep linking into Yourtube:

- **VideoQueue**: Display video queue with YouTube deep links
- **ChannelSubscriptions**: Handle channel deep linking
- **PlaylistManager**: Manage playlists with deep links
- **PriorityChannels**: Priority channel notifications
- **VideoDiscovery**: Discover videos with deep linking
- **ShareVideoButton**: Create shareable video links
- **YourtubeSettings**: Add preference UI
- **AddToQueue**: Add videos via URL
- **VideoComments**: Parse video links in comments
- **DistractionFreeVideoList**: Open videos in focused mode

**Key Features:**
- All YouTube links (youtube.com and youtu.be) open in Yourtube app
- Support for channels, videos, and playlists
- Distraction-free mode integration
- Parse video links in comments

### Cyclismo Guide (`cyclismo-integration.jsx`)

Examples for integrating deep linking into Cyclismo Guide:

- **RaceCalendar**: Display races with ProCyclingStats/CyclingNews links
- **RiderProfiles**: Handle rider deep linking
- **TeamRosters**: Display teams with deep links
- **LiveRaceTracker**: Track live races
- **RaceAlerts**: Create race alerts
- **ShareRaceButton**: Share races with deep links
- **CyclismoSettings**: Add preference UI
- **StageResults**: Handle stage-specific linking
- **RaceRecaps**: Link to race recaps
- **GrandTourTracker**: Track Grand Tours

**Key Features:**
- All ProCyclingStats and CyclingNews links open in Cyclismo
- Live race tracking with deep links
- Grand Tour stage tracking
- Rider and team profile linking

## Common Patterns

### 1. Basic Link Replacement

Replace all `<a>` tags with `<DeepLink>`:

```jsx
// Before
<a href="https://www.themoviedb.org/movie/550">Fight Club</a>

// After
<DeepLink href="https://www.themoviedb.org/movie/550">Fight Club</DeepLink>
```

### 2. Click Handler with Deep Linking

Use the `useOpenLink` hook for programmatic opening:

```jsx
function Component() {
  const { open } = useOpenLink();
  
  return (
    <button onClick={() => open('https://www.themoviedb.org/movie/550')}>
      Open Movie
    </button>
  );
}
```

### 3. Opening Content by ID

Open content directly without constructing URLs:

```jsx
import { openContent, CONTENT_TYPES } from '@min-apps/design-system/deepLinking';

await openContent(CONTENT_TYPES.MOVIE, '550');
```

### 4. URL Parsing

Extract content information from URLs:

```jsx
import { parseExternalUrl } from '@min-apps/design-system/deepLinking';

const parsed = parseExternalUrl('https://www.themoviedb.org/movie/550');
// { contentType: 'movie', extractedId: '550', service: 'The Movie Database' }
```

### 5. Extracting Links from Text

Parse user-generated content for links:

```jsx
import { extractAllIdsFromText } from '@min-apps/design-system/deepLinking';

const text = "Check out https://www.themoviedb.org/movie/550";
const ids = extractAllIdsFromText(text);
// [{ contentType: 'movie', id: '550', url: 'https://...' }]
```

### 6. Adding Preference UI

Include preference panel in settings:

```jsx
import { DeepLinkPreferencesPanel } from '@min-apps/design-system/deepLinking';

function Settings() {
  return <DeepLinkPreferencesPanel title="Link Preferences" />;
}
```

## Implementation Checklist

Use this checklist when integrating deep linking into your app:

### Phase 1: Basic Integration
- [ ] Replace all external links with `<DeepLink>` components
- [ ] Add deep linking preference UI to settings
- [ ] Set up platform-specific handlers (React Native)
- [ ] Test basic link opening

### Phase 2: Content Import
- [ ] Add URL import functionality (add to queue, favorites, etc.)
- [ ] Implement URL parsing in search/input fields
- [ ] Handle paste events for URL detection
- [ ] Test various URL formats

### Phase 3: User-Generated Content
- [ ] Parse links in comments/reviews
- [ ] Extract and display referenced content
- [ ] Handle mixed content (multiple link types)
- [ ] Test edge cases

### Phase 4: Sharing
- [ ] Implement shareable link generation
- [ ] Add share buttons throughout app
- [ ] Test universal links on all platforms
- [ ] Verify fallback behavior

### Phase 5: Notifications
- [ ] Handle deep links in notifications
- [ ] Open correct content from notification taps
- [ ] Test notification deep linking
- [ ] Verify analytics tracking

## Testing

### Test Cases

For each app, test the following scenarios:

1. **Direct Link Click**
   - Click a deep link in the app
   - Verify it opens in the min app (not browser)
   - Check that correct content is displayed

2. **URL Import**
   - Paste a URL into input field
   - Verify URL is parsed correctly
   - Check content is imported/opened

3. **User Preferences**
   - Set preferred app for content type
   - Click link of that content type
   - Verify preferred app is used

4. **Fallback Behavior**
   - Uninstall the min app
   - Click a deep link
   - Verify it opens in browser

5. **Notification Deep Links**
   - Tap notification with deep link
   - Verify app opens to correct content
   - Check notification is marked as read

### Platform-Specific Testing

#### iOS
- Test URL schemes (e.g., `watchedit://movie/550`)
- Test universal links (e.g., `https://watchedit.app/movie/550`)
- Verify Associated Domains are configured
- Test handoff between apps

#### Android
- Test intent filters
- Test app links
- Verify Digital Asset Links are configured
- Test chooser dialog behavior

#### Web
- Test direct link opening
- Test browser compatibility
- Verify localStorage preferences work
- Test copy/paste functionality

## Troubleshooting

### Links not opening in min app

1. Check URL scheme registration (iOS Info.plist, Android AndroidManifest.xml)
2. Verify user preferences: `loadDeepLinkPreferences()`
3. Test with `previewLinkOpen(url)` to see what will happen
4. Check console for errors

### URL not being parsed

1. Verify URL format is supported
2. Use `parseExternalUrl(url)` to debug
3. Check URL scheme definitions in `urlSchemes.js`
4. Add custom patterns if needed

### Preferences not persisting

1. Check localStorage availability
2. Verify browser/app storage permissions
3. Test `saveDeepLinkPreferences()` return value
4. Check for quota errors

## Best Practices

1. **Always use deep links**: Replace every external link with a deep link
2. **Respect preferences**: Always check user preferences before opening
3. **Handle fallbacks**: Gracefully fall back to web when app isn't installed
4. **Parse user content**: Extract and enhance links in user-generated content
5. **Add preference UI**: Let users choose their preferred apps
6. **Test thoroughly**: Test all link types and edge cases
7. **Track analytics**: Monitor deep link usage to improve experience

## Migration Guide

### For Existing Apps

1. **Audit existing links**: Find all external links in your app
2. **Replace with DeepLink**: Convert `<a>` tags to `<DeepLink>`
3. **Add preferences UI**: Include `<DeepLinkPreferencesPanel>` in settings
4. **Set up handlers**: Configure platform-specific handlers (React Native)
5. **Test**: Thoroughly test all link types
6. **Deploy**: Roll out to users with release notes

### Example Migration

```jsx
// Before
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

// After
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

## Support

For questions or issues:
1. Check the [main documentation](/docs/deep-linking.md)
2. Review the examples in this directory
3. Search existing issues
4. Create a new issue with reproduction steps

## License

MIT
