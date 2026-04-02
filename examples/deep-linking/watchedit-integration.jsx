/**
 * WatchedIt Deep Linking Integration Example
 * 
 * This example shows how to integrate the deep linking system into WatchedIt
 * to ensure all movie/TV links open in the app with proper deep linking.
 */

import React from 'react';
import {
  DeepLink,
  useOpenLink,
  DeepLinkPreferencesPanel,
  openContent,
  CONTENT_TYPES,
  APP_IDS,
} from '@min-apps/design-system/deepLinking';
import { borders } from '@min-apps/design-system/tokens';

/**
 * Example: Movie List Component
 * Shows how to make all TMDB/IMDb links open in WatchedIt
 */
function MovieList({ movies }) {
  return (
    <div className="movie-list">
      {movies.map(movie => (
        <div key={movie.id} className="movie-item">
          <h3>{movie.title}</h3>
          
          {/* Deep link to TMDB - will open in WatchedIt */}
          <DeepLink href={movie.tmdbUrl}>
            View on TMDB
          </DeepLink>
          
          {/* Deep link to IMDb - will open in WatchedIt */}
          {movie.imdbId && (
            <DeepLink href={`https://www.imdb.com/title/${movie.imdbId}`}>
              View on IMDb
            </DeepLink>
          )}
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Movie Details Component
 * Shows how to open specific movies by ID
 */
function MovieDetails({ movieId }) {
  const { openContent, isOpening } = useOpenLink();
  
  const handleOpenMovie = async () => {
    await openContent(CONTENT_TYPES.MOVIE, movieId, {
      appId: APP_IDS.WATCHEDIT,
    });
  };
  
  return (
    <div className="movie-details">
      <button 
        onClick={handleOpenMovie}
        disabled={isOpening}
      >
        {isOpening ? 'Opening...' : 'Open Full Details'}
      </button>
    </div>
  );
}

/**
 * Example: Search Results
 * Shows how to handle search results with deep linking
 */
function SearchResults({ results }) {
  const { open } = useOpenLink();
  
  return (
    <div className="search-results">
      {results.map(result => (
        <div 
          key={result.id} 
          className="search-result"
          onClick={() => {
            // Build TMDB URL and open it
            const tmdbUrl = `https://www.themoviedb.org/${result.type}/${result.id}`;
            open(tmdbUrl);
          }}
        >
          <img 
            src={result.poster} 
            alt={result.title}
            style={{ borderRadius: borders.radii.artTile }}
          />
          <h4>{result.title}</h4>
          <p>{result.overview}</p>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Actor/Person Links
 * Shows how to link to actor/person pages
 */
function ActorCredits({ actor }) {
  return (
    <div className="actor-credits">
      <h2>{actor.name}</h2>
      
      {/* Link to actor's TMDB page */}
      <DeepLink href={`https://www.themoviedb.org/person/${actor.tmdbId}`}>
        View Full Filmography
      </DeepLink>
      
      {/* Link to actor's IMDb page */}
      {actor.imdbId && (
        <DeepLink href={`https://www.imdb.com/name/${actor.imdbId}`}>
          View on IMDb
        </DeepLink>
      )}
      
      {/* List of movies */}
      <div className="credits-list">
        {actor.credits.map(credit => (
          <DeepLink 
            key={credit.id}
            href={`https://www.themoviedb.org/movie/${credit.id}`}
          >
            {credit.title}
          </DeepLink>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Share Movie Feature
 * Shows how to create shareable deep links
 */
function ShareMovieButton({ movieId, movieTitle }) {
  const [shared, setShared] = React.useState(false);
  
  const handleShare = async () => {
    const { createShareableLink } = await import('@min-apps/design-system/deepLinking');
    
    const link = createShareableLink(CONTENT_TYPES.MOVIE, movieId);
    
    if (navigator.share) {
      await navigator.share({
        title: movieTitle,
        text: `Check out ${movieTitle}`,
        url: link,
      });
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(link);
      setShared(true);
      setTimeout(() => setShared(false), 2000);
    }
  };
  
  return (
    <button onClick={handleShare}>
      {shared ? 'Link Copied!' : 'Share Movie'}
    </button>
  );
}

/**
 * Example: Settings Page
 * Shows how to add deep linking preferences to settings
 */
function WatcheditSettings() {
  return (
    <div className="settings-page">
      <h1>Settings</h1>
      
      <section>
        <h2>Appearance</h2>
        {/* Other settings */}
      </section>
      
      <section>
        <h2>Deep Linking</h2>
        <DeepLinkPreferencesPanel title="Movie & TV Preferences" />
        <p className="help-text">
          Choose which app opens when you click movie or TV show links from 
          external sources like TMDB or IMDb.
        </p>
      </section>
    </div>
  );
}

/**
 * Example: Notification Deep Links
 * Shows how to handle deep links from notifications
 */
function handleNotificationDeepLink(notificationData) {
  const { openLink } = require('@min-apps/design-system/deepLinking');
  
  // Notification might contain a TMDB URL
  if (notificationData.movieUrl) {
    openLink(notificationData.movieUrl);
  } 
  // Or a movie ID
  else if (notificationData.movieId) {
    openContent(CONTENT_TYPES.MOVIE, notificationData.movieId, {
      appId: APP_IDS.WATCHEDIT,
    });
  }
}

/**
 * Example: Related Content
 * Shows how to link to related movies/shows
 */
function RelatedContent({ related }) {
  return (
    <div className="related-content">
      <h3>You might also like</h3>
      <div className="related-grid">
        {related.map(item => (
          <DeepLink 
            key={item.id}
            href={`https://www.themoviedb.org/${item.type}/${item.id}`}
            className="related-item"
          >
            <img 
              src={item.poster} 
              alt={item.title}
              style={{ borderRadius: borders.radii.artTile }}
            />
            <p>{item.title}</p>
          </DeepLink>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: External Links Parser
 * Shows how to parse and convert external links in user-generated content
 */
function UserReview({ review }) {
  const { extractAllIdsFromText } = require('@min-apps/design-system/deepLinking');
  
  // Extract all movie/TV links from review text
  const ids = extractAllIdsFromText(review.text);
  
  return (
    <div className="user-review">
      <p>{review.text}</p>
      
      {/* Show all referenced movies/shows */}
      {ids.length > 0 && (
        <div className="referenced-content">
          <h4>Referenced in this review:</h4>
          {ids.map((item, index) => (
            <DeepLink key={index} href={item.url}>
              View {item.contentType}
            </DeepLink>
          ))}
        </div>
      )}
    </div>
  );
}

/**
 * Example: Watchlist Import
 * Shows how to handle importing from external URLs
 */
function WatchlistImport() {
  const [importUrl, setImportUrl] = React.useState('');
  const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
  
  const handleImport = () => {
    const parsed = parseExternalUrl(importUrl);
    
    if (parsed && parsed.contentType === CONTENT_TYPES.MOVIE) {
      // Add to watchlist using the extracted ID
      addToWatchlist(parsed.extractedId);
    }
  };
  
  return (
    <div className="watchlist-import">
      <input
        type="text"
        value={importUrl}
        onChange={(e) => setImportUrl(e.target.value)}
        placeholder="Paste TMDB or IMDb URL"
      />
      <button onClick={handleImport}>Import</button>
    </div>
  );
}

// Example data for demonstration
const exampleMovies = [
  {
    id: 550,
    title: 'Fight Club',
    tmdbUrl: 'https://www.themoviedb.org/movie/550',
    imdbId: 'tt0137523',
  },
  {
    id: 13,
    title: 'Forrest Gump',
    tmdbUrl: 'https://www.themoviedb.org/movie/13',
    imdbId: 'tt0109830',
  },
];

export {
  MovieList,
  MovieDetails,
  SearchResults,
  ActorCredits,
  ShareMovieButton,
  WatcheditSettings,
  handleNotificationDeepLink,
  RelatedContent,
  UserReview,
  WatchlistImport,
  exampleMovies,
};
