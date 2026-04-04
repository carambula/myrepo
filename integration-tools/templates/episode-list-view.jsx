/**
 * Episode List View Template
 * 
 * This template shows how to create an episode list with proper tap behavior:
 * - Art and title open the episode detail/player view
 * - Play button plays/pauses the episode
 * 
 * CRITICAL: The play button must use e.stopPropagation() to prevent
 * triggering the row click handler.
 */

import React from 'react';
import { AppLayout } from '@min-apps/design-system/layouts';
import { List, EpisodeListItem, Input, AppHeader, MainAppLoading } from '@min-apps/design-system/components';
import { spacing, metadataSeparator } from '@min-apps/design-system/tokens';

// Example episode data structure
const EXAMPLE_EPISODES = [
  {
    id: 1,
    title: 'Episode 1: Getting Started',
    podcastName: 'Tech Talks Daily',
    description: 'An introduction to our podcast series',
    artworkUrl: '/episode-1.jpg',
    duration: '45:30',
    isPlaying: false,
  },
  {
    id: 2,
    title: 'Episode 2: Deep Dive into React',
    podcastName: 'Tech Talks Daily',
    description: 'Exploring React hooks and best practices',
    artworkUrl: '/episode-2.jpg',
    duration: '1:02:15',
    isPlaying: false,
  },
];

function EpisodeListView() {
  const [episodes, setEpisodes] = React.useState(null);
  const [searchQuery, setSearchQuery] = React.useState('');
  const [currentlyPlayingId, setCurrentlyPlayingId] = React.useState(null);
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    fetchEpisodes().then((data) => {
      setEpisodes(data);
      setIsLoading(false);
    });
  }, []);

  if (isLoading || !episodes) {
    return <MainAppLoading />;
  }

  /**
   * Opens the episode detail/player view
   * Triggered by clicking on the episode art, title, or row (but NOT the play button)
   */
  const openEpisodePlayer = (episode) => {
    console.log('Opening episode player for:', episode.title);
    // Navigate to episode detail/player view
    // Example: navigate(`/episode/${episode.id}`);
  };

  /**
   * Plays or pauses the episode
   * Triggered ONLY by clicking the play button
   * Uses e.stopPropagation() to prevent opening the player view
   */
  const handlePlayClick = (episode) => {
    console.log('Play/pause episode:', episode.title);
    
    if (currentlyPlayingId === episode.id) {
      // Pause if already playing
      setCurrentlyPlayingId(null);
    } else {
      // Play this episode
      setCurrentlyPlayingId(episode.id);
    }
    
    // Update episode playing state
    setEpisodes(episodes.map(ep => ({
      ...ep,
      isPlaying: ep.id === episode.id ? !ep.isPlaying : false,
    })));
  };

  const handleSearch = (e) => {
    setSearchQuery(e.target.value);
    // Filter episodes based on search
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title="Episodes"
          backButton
          onBack={() => console.log('Go back')}
        />
      }
    >
      {/* Sticky search — horizontal inset from AppLayout main only */}
      <div style={{ 
        paddingTop: 0,
        paddingBottom: spacing[2],
        paddingLeft: 0,
        paddingRight: 0,
        position: 'sticky',
        top: 0,
        backgroundColor: 'var(--color-background-primary)',
        zIndex: 10
      }}>
        <Input
          type="search"
          placeholder="Search episodes..."
          value={searchQuery}
          onChange={handleSearch}
          fullWidth
        />
      </div>

      {/* Episode list — no extra horizontal padding inside AppLayout main */}
      <div style={{ paddingBottom: spacing[4] }}>
        {isLoading ? (
          <div
            className="min-content-status min-content-status--loading"
            role="status"
            aria-live="polite"
          >
            <span className="min-content-status__spinner" aria-hidden="true" />
            <span className="min-content-status__label">Loading…</span>
          </div>
        ) : (
          <>
            <List spacing="default">
              {episodes.map(episode => (
                <EpisodeListItem
                  key={episode.id}
                  artwork={episode.artworkUrl}
                  artworkAlt={episode.title}
                  title={episode.title}
                  subtitle={episode.podcastName}
                  duration={episode.duration}
                  isPlaying={episode.isPlaying}
                  // Clicking art/title opens the episode player view
                  onEpisodeClick={() => openEpisodePlayer(episode)}
                  // Clicking play button plays the episode
                  // The component handles e.stopPropagation() internally
                  onPlayClick={() => handlePlayClick(episode)}
                />
              ))}
            </List>

            {/* Empty state — left-aligned; see docs/visual-specification.md */}
            {episodes.length === 0 && (
              <div className="min-content-status min-content-status--empty">
                <p className="min-content-status__message">No episodes found</p>
              </div>
            )}
          </>
        )}
      </div>
    </AppLayout>
  );
}

/**
 * Alternative: Using ListItem with manual play button
 * (if you need more customization than EpisodeListItem provides)
 */
function EpisodeListViewWithListItem() {
  const handlePlayClick = (episode, e) => {
    // CRITICAL: Must call stopPropagation to prevent row click
    e.stopPropagation();
    console.log('Play episode:', episode.title);
  };

  const openEpisodePlayer = (episode) => {
    console.log('Open player for:', episode.title);
  };

  return (
    <List spacing="default">
      {EXAMPLE_EPISODES.map(episode => (
        <ListItem
          key={episode.id}
          image={episode.artworkUrl}
          title={episode.title}
          subtitle={`${episode.podcastName}${metadataSeparator}${episode.duration}`}
          onClick={() => openEpisodePlayer(episode)}
          action={
            <button
              onClick={(e) => handlePlayClick(episode, e)}
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '50%',
                border: 'none',
                backgroundColor: 'var(--color-primary-main)',
                color: 'white',
                cursor: 'pointer',
              }}
              aria-label={`Play ${episode.title}`}
            >
              {episode.isPlaying ? '⏸' : '▶'}
            </button>
          }
        />
      ))}
    </List>
  );
}

function fetchEpisodes() {
  return new Promise((resolve) => setTimeout(() => resolve(EXAMPLE_EPISODES), 300));
}

export default EpisodeListView;
export { EpisodeListViewWithListItem };
