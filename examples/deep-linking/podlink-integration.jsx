/**
 * Podlink Deep Linking Integration Example
 * 
 * This example shows how to integrate the deep linking system into Podlink
 * to ensure all podcast links open in the app with proper deep linking.
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

/**
 * Example: Podcast List Component
 * Shows how to make all Apple Podcasts/Spotify links open in Podlink
 */
function PodcastList({ podcasts }) {
  return (
    <div className="podcast-list">
      {podcasts.map(podcast => (
        <div key={podcast.id} className="podcast-item">
          <img src={podcast.artwork} alt={podcast.title} />
          <h3>{podcast.title}</h3>
          <p>{podcast.author}</p>
          
          {/* Deep link to Apple Podcasts - will open in Podlink */}
          {podcast.applePodcastsUrl && (
            <DeepLink href={podcast.applePodcastsUrl}>
              View on Apple Podcasts
            </DeepLink>
          )}
          
          {/* Deep link to Spotify - will open in Podlink */}
          {podcast.spotifyUrl && (
            <DeepLink href={podcast.spotifyUrl}>
              View on Spotify
            </DeepLink>
          )}
          
          {/* Deep link to Overcast */}
          {podcast.overcastUrl && (
            <DeepLink href={podcast.overcastUrl}>
              View on Overcast
            </DeepLink>
          )}
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Episode List
 * Shows how to handle episode deep linking
 */
function EpisodeList({ episodes }) {
  const { open } = useOpenLink();
  
  return (
    <div className="episode-list">
      {episodes.map(episode => (
        <div 
          key={episode.id} 
          className="episode-item"
          onClick={() => {
            // Open episode in Podlink
            if (episode.spotifyUrl) {
              open(episode.spotifyUrl);
            } else if (episode.applePodcastsUrl) {
              open(episode.applePodcastsUrl);
            }
          }}
        >
          <h4>{episode.title}</h4>
          <p>{episode.description}</p>
          <span>{episode.duration}</span>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Queue Management
 * Shows how to add podcasts to queue via deep links
 */
function QueueManager() {
  const [queueUrl, setQueueUrl] = React.useState('');
  const { parseExternalUrl, extractIdFromUrl } = require('@min-apps/design-system/deepLinking');
  
  const handleAddToQueue = () => {
    const parsed = parseExternalUrl(queueUrl);
    
    if (parsed && (
      parsed.contentType === CONTENT_TYPES.PODCAST ||
      parsed.contentType === CONTENT_TYPES.PODCAST_EPISODE
    )) {
      // Add to queue using the extracted ID
      addToQueue(parsed.extractedId, parsed.contentType);
      setQueueUrl('');
    } else {
      alert('Please enter a valid podcast URL');
    }
  };
  
  return (
    <div className="queue-manager">
      <h3>Add to Queue</h3>
      <input
        type="text"
        value={queueUrl}
        onChange={(e) => setQueueUrl(e.target.value)}
        placeholder="Paste Apple Podcasts, Spotify, or Overcast URL"
      />
      <button onClick={handleAddToQueue}>Add to Queue</button>
    </div>
  );
}

/**
 * Example: Podcast Discovery
 * Shows how to handle podcast discovery with deep linking
 */
function PodcastDiscovery({ recommendations }) {
  return (
    <div className="podcast-discovery">
      <h2>Recommended Podcasts</h2>
      <div className="recommendations-grid">
        {recommendations.map(podcast => (
          <DeepLink
            key={podcast.id}
            href={podcast.applePodcastsUrl || podcast.spotifyUrl}
            className="recommendation-card"
          >
            <img src={podcast.artwork} alt={podcast.title} />
            <h4>{podcast.title}</h4>
            <p>{podcast.category}</p>
          </DeepLink>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Share Podcast Feature
 * Shows how to create shareable podcast deep links
 */
function SharePodcastButton({ podcastId, podcastTitle }) {
  const [copied, setCopied] = React.useState(false);
  
  const handleShare = async () => {
    const { createShareableLink } = await import('@min-apps/design-system/deepLinking');
    
    const link = createShareableLink(CONTENT_TYPES.PODCAST, podcastId);
    
    if (navigator.share) {
      await navigator.share({
        title: podcastTitle,
        text: `Check out ${podcastTitle}`,
        url: link,
      });
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(link);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };
  
  return (
    <button onClick={handleShare}>
      {copied ? 'Link Copied!' : 'Share Podcast'}
    </button>
  );
}

/**
 * Example: Podcast Settings
 * Shows how to add deep linking preferences for podcasts
 */
function PodlinkSettings() {
  return (
    <div className="settings-page">
      <h1>Settings</h1>
      
      <section>
        <h2>Playback</h2>
        {/* Other settings */}
      </section>
      
      <section>
        <h2>Deep Linking</h2>
        <DeepLinkPreferencesPanel title="Podcast Preferences" />
        <p className="help-text">
          Choose which app opens when you click podcast links from external 
          sources like Apple Podcasts, Spotify, or Overcast.
        </p>
      </section>
    </div>
  );
}

/**
 * Example: Priority Podcasts
 * Shows how to handle priority podcast deep links
 */
function PriorityPodcasts({ priorityPodcasts }) {
  const { openContent } = useOpenLink();
  
  const handleOpenPodcast = async (podcastId) => {
    await openContent(CONTENT_TYPES.PODCAST, podcastId, {
      appId: APP_IDS.PODLINK,
    });
  };
  
  return (
    <div className="priority-podcasts">
      <h3>Priority Queue</h3>
      <p>These podcasts will be added to the top of your queue</p>
      
      {priorityPodcasts.map(podcast => (
        <div key={podcast.id} className="priority-podcast">
          <span>{podcast.title}</span>
          <button onClick={() => handleOpenPodcast(podcast.id)}>
            Open
          </button>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Podcast Notes with Links
 * Shows how to handle user notes that might contain podcast links
 */
function PodcastNotes({ notes }) {
  const { extractAllIdsFromText } = require('@min-apps/design-system/deepLinking');
  
  return (
    <div className="podcast-notes">
      {notes.map(note => {
        const ids = extractAllIdsFromText(note.text);
        
        return (
          <div key={note.id} className="note">
            <p>{note.text}</p>
            
            {/* Show all referenced podcasts */}
            {ids.length > 0 && (
              <div className="referenced-podcasts">
                <h4>Referenced podcasts:</h4>
                {ids.map((item, index) => (
                  <DeepLink key={index} href={item.url}>
                    Listen to {item.contentType}
                  </DeepLink>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

/**
 * Example: RSS Feed Import
 * Shows how to handle RSS feed imports
 */
function RSSFeedImport() {
  const [feedUrl, setFeedUrl] = React.useState('');
  
  const handleImport = async () => {
    // This would typically involve fetching the RSS feed
    // and extracting podcast information
    const podcastInfo = await fetchPodcastFromRSS(feedUrl);
    
    if (podcastInfo.applePodcastsUrl) {
      const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
      const parsed = parseExternalUrl(podcastInfo.applePodcastsUrl);
      
      if (parsed) {
        subscribeToPodcast(parsed.extractedId);
      }
    }
  };
  
  return (
    <div className="rss-import">
      <h3>Subscribe via RSS</h3>
      <input
        type="text"
        value={feedUrl}
        onChange={(e) => setFeedUrl(e.target.value)}
        placeholder="Enter RSS feed URL"
      />
      <button onClick={handleImport}>Subscribe</button>
    </div>
  );
}

/**
 * Example: Smart Queue Building
 * Shows how to build a smart queue from various podcast sources
 */
function SmartQueueBuilder() {
  const [sources, setSources] = React.useState([]);
  const { open } = useOpenLink();
  
  const addSource = (url) => {
    const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
    const parsed = parseExternalUrl(url);
    
    if (parsed) {
      setSources([...sources, parsed]);
    }
  };
  
  return (
    <div className="smart-queue-builder">
      <h3>Build Smart Queue</h3>
      <p>Add podcasts from any source to create your perfect queue</p>
      
      <div className="sources-list">
        {sources.map((source, index) => (
          <div key={index} className="source-item">
            <span>{source.serviceName}</span>
            <button onClick={() => open(source.url)}>Open</button>
          </div>
        ))}
      </div>
      
      <input
        type="text"
        placeholder="Paste podcast URL"
        onPaste={(e) => addSource(e.clipboardData.getData('text'))}
      />
    </div>
  );
}

/**
 * Example: Notification Handler
 * Shows how to handle deep links from notifications
 */
function handlePodcastNotification(notificationData) {
  const { openLink, openContent } = require('@min-apps/design-system/deepLinking');
  
  if (notificationData.episodeUrl) {
    // Direct URL from notification
    openLink(notificationData.episodeUrl);
  } else if (notificationData.episodeId) {
    // Episode ID from notification
    openContent(CONTENT_TYPES.PODCAST_EPISODE, notificationData.episodeId, {
      appId: APP_IDS.PODLINK,
    });
  }
}

/**
 * Example: Podcast Search with External Links
 * Shows how to handle search results that include external links
 */
function PodcastSearch({ searchResults }) {
  return (
    <div className="podcast-search">
      <h3>Search Results</h3>
      {searchResults.map(result => (
        <div key={result.id} className="search-result">
          <img src={result.artwork} alt={result.title} />
          <div className="result-info">
            <h4>{result.title}</h4>
            <p>{result.author}</p>
            
            {/* Multiple deep link options */}
            <div className="result-links">
              {result.applePodcastsUrl && (
                <DeepLink href={result.applePodcastsUrl}>Apple</DeepLink>
              )}
              {result.spotifyUrl && (
                <DeepLink href={result.spotifyUrl}>Spotify</DeepLink>
              )}
              {result.overcastUrl && (
                <DeepLink href={result.overcastUrl}>Overcast</DeepLink>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// Example data
const examplePodcasts = [
  {
    id: '123456',
    title: 'The Daily',
    author: 'The New York Times',
    artwork: 'https://example.com/daily.jpg',
    applePodcastsUrl: 'https://podcasts.apple.com/us/podcast/the-daily/id1200361736',
    spotifyUrl: 'https://open.spotify.com/show/3IM0lmZxpFAY7CwMuv9H4g',
  },
];

// Placeholder functions
function addToQueue(id, type) {
  console.log('Adding to queue:', id, type);
}

function subscribeToPodcast(id) {
  console.log('Subscribing to podcast:', id);
}

async function fetchPodcastFromRSS(url) {
  // Placeholder
  return { applePodcastsUrl: '' };
}

export {
  PodcastList,
  EpisodeList,
  QueueManager,
  PodcastDiscovery,
  SharePodcastButton,
  PodlinkSettings,
  PriorityPodcasts,
  PodcastNotes,
  RSSFeedImport,
  SmartQueueBuilder,
  handlePodcastNotification,
  PodcastSearch,
  examplePodcasts,
};
