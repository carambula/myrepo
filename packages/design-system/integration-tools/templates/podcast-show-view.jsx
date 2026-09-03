/**
 * Podcast Show View Template
 * 
 * This template shows how to create a podcast show detail view with:
 * - Podcast artwork and metadata
 * - Episode list with scroll
 * - Animated dismiss button that slides in when scrolling
 * - Dismiss button expands when scrolled to bottom
 * - Button is always tappable to close the show view
 * - Aligned with microplayer and search button positioning
 * 
 * CRITICAL BEHAVIOR:
 * - Dismiss button is hidden initially
 * - Slides in from bottom left when user scrolls into episode list
 * - Compact size (48px) while scrolling - aligned with microplayer/search
 * - Expands to larger size (56px) when scrolled to bottom
 * - Tapping at any time closes the show view
 */

import React, { useRef } from 'react';
import { AppLayout } from '@min-apps/design-system/layouts';
import { 
  List, 
  EpisodeListItem, 
  Input, 
  AppHeader, 
  Card,
  DismissButton,
  MainContentTitle,
  MainAppLoading,
} from '@min-apps/design-system/components';
import { useScrollDismiss } from '@min-apps/design-system/hooks';
import { spacing, metadataSeparator } from '@min-apps/design-system/tokens';

// Example podcast data
const EXAMPLE_PODCAST = {
  id: 1,
  title: 'Tech Talks Daily',
  author: 'The Tech Team',
  description: 'Your daily dose of technology news, interviews, and insights. Join us as we explore the latest in software development, AI, gadgets, and more.',
  artworkUrl: '/podcast-artwork.jpg',
  episodeCount: 245,
  category: 'Technology',
  language: 'English',
  isSubscribed: false,
};

// Example episodes
const EXAMPLE_EPISODES = [
  {
    id: 1,
    title: 'The Future of AI in Software Development',
    podcastName: 'Tech Talks Daily',
    description: 'Exploring how AI is transforming the way we write code',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '45:30',
    publishDate: '2024-01-15',
    isPlaying: false,
  },
  {
    id: 2,
    title: 'Building Scalable Web Applications',
    podcastName: 'Tech Talks Daily',
    description: 'Best practices for handling millions of users',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '1:02:15',
    publishDate: '2024-01-14',
    isPlaying: false,
  },
  {
    id: 3,
    title: 'Interview with React Core Team',
    podcastName: 'Tech Talks Daily',
    description: 'Deep dive into React 19 and the future of the library',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '52:45',
    publishDate: '2024-01-13',
    isPlaying: false,
  },
  {
    id: 4,
    title: 'Mobile Development in 2024',
    podcastName: 'Tech Talks Daily',
    description: 'Native vs cross-platform: what should you choose?',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '38:20',
    publishDate: '2024-01-12',
    isPlaying: false,
  },
  {
    id: 5,
    title: 'Cybersecurity Essentials for Developers',
    podcastName: 'Tech Talks Daily',
    description: 'Protecting your apps and users from common threats',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '41:15',
    publishDate: '2024-01-11',
    isPlaying: false,
  },
  {
    id: 6,
    title: 'The Rise of Edge Computing',
    podcastName: 'Tech Talks Daily',
    description: 'Why edge computing is changing the cloud landscape',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '48:30',
    publishDate: '2024-01-10',
    isPlaying: false,
  },
  {
    id: 7,
    title: 'GraphQL vs REST: The Debate Continues',
    podcastName: 'Tech Talks Daily',
    description: 'When to use GraphQL and when to stick with REST',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '55:10',
    publishDate: '2024-01-09',
    isPlaying: false,
  },
  {
    id: 8,
    title: 'Database Design Patterns',
    podcastName: 'Tech Talks Daily',
    description: 'Common patterns for designing efficient databases',
    artworkUrl: '/podcast-artwork.jpg',
    duration: '44:25',
    publishDate: '2024-01-08',
    isPlaying: false,
  },
];

function PodcastShowView() {
  const scrollContainerRef = useRef(null);
  const [podcast, setPodcast] = React.useState(null);
  const [episodes, setEpisodes] = React.useState(null);
  const [searchQuery, setSearchQuery] = React.useState('');
  const [currentlyPlayingId, setCurrentlyPlayingId] = React.useState(null);
  const [isSubscribed, setIsSubscribed] = React.useState(false);
  const [episodesLoading, setEpisodesLoading] = React.useState(true);

  React.useEffect(() => {
    fetchShowData().then(({ show, eps }) => {
      setPodcast(show);
      setEpisodes(eps);
      setIsSubscribed(show.isSubscribed);
      setEpisodesLoading(false);
    });
  }, []);

  if (episodesLoading || !podcast) {
    return <MainAppLoading />;
  }

  // Track scroll state for dismiss button
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef, {
    scrollThreshold: 100,  // Show button after scrolling 100px
    bottomThreshold: 50,   // Expand when within 50px of bottom
  });

  /**
   * Dismisses/closes the show view
   * Called when dismiss button is tapped (works at any scroll position)
   */
  const handleDismiss = () => {
    console.log('Closing show view');
    // Navigate back or close modal
    // Example: navigate(-1) or closeModal()
  };

  /**
   * Opens the episode detail/player view
   */
  const openEpisodePlayer = (episode) => {
    console.log('Opening episode player for:', episode.title);
    // Navigate to episode detail/player view
  };

  /**
   * Plays or pauses the episode
   */
  const handlePlayClick = (episode) => {
    console.log('Play/pause episode:', episode.title);
    
    if (currentlyPlayingId === episode.id) {
      setCurrentlyPlayingId(null);
    } else {
      setCurrentlyPlayingId(episode.id);
    }
    
    setEpisodes(episodes.map(ep => ({
      ...ep,
      isPlaying: ep.id === episode.id ? !ep.isPlaying : false,
    })));
  };

  const handleSubscribe = () => {
    setIsSubscribed(!isSubscribed);
    setPodcast({ ...podcast, isSubscribed: !isSubscribed });
  };

  const handleSearch = (e) => {
    setSearchQuery(e.target.value);
  };

  const handleShare = () => {
    console.log('Share podcast');
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title={podcast.title}
          backButton
          onBack={handleDismiss}
        />
      }
    >
      {/* Scrollable container - ref needed for scroll tracking */}
      <div 
        ref={scrollContainerRef}
        style={{ 
          height: '100%',
          overflowY: 'auto',
          paddingBottom: spacing[20], // Extra space for microplayer if present
        }}
      >
        {/* Podcast header — AppLayout main already applies page margins (mov min); no extra horizontal inset */}
        <div style={{ 
          paddingTop: 0,
          paddingBottom: spacing[6],
          paddingLeft: 0,
          paddingRight: 0,
        }}>
          <div style={{ 
            display: 'flex',
            gap: spacing[6],
            marginBottom: spacing[6],
          }}>
            {/* Podcast Artwork */}
            <div style={{ flexShrink: 0 }}>
              <img 
                src={podcast.artworkUrl}
                alt={podcast.title}
                style={{
                  width: '160px',
                  height: '160px',
                  borderRadius: '12px',
                  boxShadow: 'var(--shadow-md)',
                  objectFit: 'cover',
                }}
              />
            </div>

            {/* Podcast Info */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <MainContentTitle>{podcast.title}</MainContentTitle>
              
              <p style={{ 
                fontSize: '1rem',
                marginBottom: spacing[3],
                color: 'var(--color-text-secondary)',
              }}>
                {podcast.author}
              </p>

              <div style={{ 
                display: 'flex',
                gap: spacing[2],
                marginBottom: spacing[4],
                flexWrap: 'wrap',
                fontSize: '0.875rem',
                color: 'var(--color-text-tertiary)',
              }}>
                <span>{podcast.episodeCount} episodes</span>
                {metadataSeparator}
                <span>{podcast.category}</span>
                {metadataSeparator}
                <span>{podcast.language}</span>
              </div>

              {/* Action Buttons */}
              <div style={{ 
                display: 'flex',
                gap: spacing[3],
              }}>
                <button
                  onClick={handleSubscribe}
                  style={{
                    padding: `${spacing[3]} ${spacing[6]}`,
                    borderRadius: '8px',
                    border: 'none',
                    backgroundColor: isSubscribed 
                      ? 'var(--color-secondary-main)' 
                      : 'var(--color-primary-main)',
                    color: 'white',
                    fontWeight: '600',
                    cursor: 'pointer',
                    transition: 'all 0.2s',
                  }}
                >
                  {isSubscribed ? '✓ Subscribed' : 'Subscribe'}
                </button>
                
                <button
                  onClick={handleShare}
                  style={{
                    padding: `${spacing[3]} ${spacing[4]}`,
                    borderRadius: '8px',
                    border: '2px solid var(--color-primary-main)',
                    backgroundColor: 'transparent',
                    color: 'var(--color-primary-main)',
                    fontWeight: '600',
                    cursor: 'pointer',
                    transition: 'all 0.2s',
                  }}
                >
                  Share
                </button>
              </div>
            </div>
          </div>

          {/* Description */}
          <p style={{ 
            lineHeight: 1.6,
            color: 'var(--color-text-primary)',
            marginBottom: spacing[6],
          }}>
            {podcast.description}
          </p>
        </div>

        {/* Episodes section — vertical rhythm only; horizontal aligns with page grid */}
        <div style={{ 
          paddingTop: spacing[4],
          paddingBottom: spacing[3],
          paddingLeft: 0,
          paddingRight: 0,
          borderTop: '1px solid var(--color-border-primary)',
        }}>
          <h2 style={{ 
            fontSize: '1.25rem',
            fontWeight: '600',
            marginBottom: spacing[4],
            color: 'var(--color-text-primary)',
          }}>
            Episodes
          </h2>

          {/* Search bar */}
          <div style={{ marginBottom: spacing[4] }}>
            <Input
              type="search"
              placeholder="Search episodes..."
              value={searchQuery}
              onChange={handleSearch}
              fullWidth
            />
          </div>
        </div>

        {/* Episode list */}
        <div style={{ paddingBottom: spacing[4] }}>
          {episodesLoading ? (
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
                    subtitle={`${episode.publishDate}${metadataSeparator}${episode.duration}`}
                    duration={episode.duration}
                    isPlaying={episode.isPlaying}
                    onEpisodeClick={() => openEpisodePlayer(episode)}
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
      </div>

      {/* 
        Dismiss Button
        - Slides in when scrolling starts (isScrolled = true)
        - Compact size while scrolling
        - Expands when at bottom (isAtBottom = true)
        - Always tappable to close the view
        - Positioned in lower left, aligned with microplayer
      */}
      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={handleDismiss}
        label="Close"
        icon="↓"
      />
    </AppLayout>
  );
}

/**
 * Alternative: Minimal implementation without search
 */
function MinimalPodcastShowView() {
  const scrollContainerRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef);

  const handleDismiss = () => {
    console.log('Closing show view');
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title="Podcast Title"
          backButton
          onBack={handleDismiss}
        />
      }
    >
      <div 
        ref={scrollContainerRef}
        style={{ 
          height: '100%',
          overflowY: 'auto',
          paddingTop: spacing[4],
          paddingBottom: spacing[4],
          paddingLeft: 0,
          paddingRight: 0,
        }}
      >
        {/* Your content here */}
        <MainContentTitle>Podcast Show Content</MainContentTitle>
        
        {/* ... episodes list ... */}
      </div>

      {/* Dismiss button with animation */}
      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={handleDismiss}
      />
    </AppLayout>
  );
}

function fetchShowData() {
  return new Promise((resolve) =>
    setTimeout(() => resolve({ show: EXAMPLE_PODCAST, eps: EXAMPLE_EPISODES }), 300)
  );
}

export default PodcastShowView;
export { MinimalPodcastShowView };
