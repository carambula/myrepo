/**
 * Yourtube Deep Linking Integration Example
 * 
 * This example shows how to integrate the deep linking system into Yourtube
 * to ensure all YouTube video/channel links open in the app with proper deep linking.
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
import { MainAppLoading, AppHeader } from '@min-apps/design-system/components';
import { AppLayout } from '@min-apps/design-system/layouts';
import { borders, spacing } from '@min-apps/design-system/tokens';

/**
 * YourTube App shell — AppLayout applies mov min page margins.
 * Bootstrap loading matches WatchedIt (mov min).
 */
function YourtubeApp() {
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    initYourtubeData().then(() => setLoading(false));
  }, []);

  if (loading) {
    return <MainAppLoading />;
  }

  return (
    <AppLayout header={<AppHeader title="YourTube" />}>
      <YourtubeMainContent />
    </AppLayout>
  );
}

function initYourtubeData() {
  return new Promise((resolve) => setTimeout(resolve, 300));
}

function YourtubeMainContent() {
  return <>{/* app routes — no extra horizontal padding; AppLayout main provides page margins */}</>;
}

/**
 * Example: Video Queue Component
 * Shows how to make all YouTube links open in Yourtube app
 */
function VideoQueue({ videos }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
      {videos.map(video => (
        <div key={video.id} style={{
          display: 'flex', alignItems: 'center', gap: spacing.list.itemGap,
          padding: `${spacing.list.itemPaddingY} 0`,
        }}>
          <img 
            src={video.thumbnail} 
            alt={video.title}
            style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
          />
          <div style={{ flex: 1, minWidth: 0 }}>
            <h3 style={{ margin: 0 }}>{video.title}</h3>
            <p style={{ margin: 0, color: 'var(--color-text-secondary)' }}>{video.channel}</p>
            
            <DeepLink href={`https://www.youtube.com/watch?v=${video.id}`}>
              Watch on YouTube
            </DeepLink>
            {' '}
            <DeepLink href={`https://youtu.be/${video.id}`}>
              Share Short Link
            </DeepLink>
          </div>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Channel Subscriptions
 * Shows how to handle channel deep linking
 */
function ChannelSubscriptions({ channels }) {
  const { open } = useOpenLink();
  
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
      {channels.map(channel => (
        <div key={channel.id} style={{
          display: 'flex', alignItems: 'center', gap: spacing.list.itemGap,
          padding: `${spacing.list.itemPaddingY} 0`,
        }}>
          <img 
            src={channel.avatar} 
            alt={channel.name}
            style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
          />
          <h4 style={{ margin: 0 }}>{channel.name}</h4>
          
          {/* Support both channel ID and handle formats */}
          {channel.channelId ? (
            <DeepLink href={`https://www.youtube.com/channel/${channel.channelId}`}>
              Visit Channel
            </DeepLink>
          ) : (
            <DeepLink href={`https://www.youtube.com/@${channel.handle}`}>
              Visit @{channel.handle}
            </DeepLink>
          )}
          
          <button onClick={() => {
            const url = channel.channelId 
              ? `https://www.youtube.com/channel/${channel.channelId}`
              : `https://www.youtube.com/@${channel.handle}`;
            open(url);
          }}>
            Open in App
          </button>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Playlist Manager
 * Shows how to handle playlist deep linking
 */
function PlaylistManager({ playlists }) {
  return (
    <div>
      <h3>Your Playlists</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {playlists.map(playlist => (
          <div key={playlist.id} style={{
            display: 'flex', alignItems: 'center', gap: spacing.list.itemGap,
            padding: `${spacing.list.itemPaddingY} 0`,
          }}>
            <img 
              src={playlist.thumbnail} 
              alt={playlist.title}
              style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <h4 style={{ margin: 0 }}>{playlist.title}</h4>
              <span style={{ color: 'var(--color-text-secondary)', fontSize: 14 }}>{playlist.videoCount} videos</span>
              {' '}
              <DeepLink href={`https://www.youtube.com/playlist?list=${playlist.id}`}>
                Open Playlist
              </DeepLink>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Priority Channels
 * Shows how to handle priority channel notifications with deep linking
 */
function PriorityChannels({ priorityChannels }) {
  const { openContent } = useOpenLink();
  
  const handleOpenChannel = async (channelId) => {
    await openContent(CONTENT_TYPES.CHANNEL, channelId, {
      appId: APP_IDS.YOURTUBE,
    });
  };
  
  return (
    <div>
      <h3>Priority Channels</h3>
      <p style={{ color: 'var(--color-text-secondary)' }}>Get notified first when these channels upload</p>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {priorityChannels.map(channel => (
          <div key={channel.id} style={{
            display: 'flex', alignItems: 'center', gap: spacing.list.itemGap,
            padding: `${spacing.list.itemPaddingY} 0`,
          }}>
            <img src={channel.avatar} alt={channel.name}
              style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }} />
            <span style={{ flex: 1 }}>{channel.name}</span>
            <button onClick={() => handleOpenChannel(channel.id)}>
              Open
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Video Discovery
 * Shows how to handle video discovery with deep linking
 */
function VideoDiscovery({ recommendations }) {
  return (
    <div>
      <h2>Recommended Videos</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {recommendations.map(video => (
          <DeepLink
            key={video.id}
            href={`https://www.youtube.com/watch?v=${video.id}`}
            style={{ display: 'flex', alignItems: 'center', gap: spacing.list.itemGap, padding: `${spacing.list.itemPaddingY} 0`, textDecoration: 'none', color: 'inherit' }}
          >
            <img 
              src={video.thumbnail} 
              alt={video.title}
              style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <h4 style={{ margin: 0 }}>{video.title}</h4>
              <p style={{ margin: 0, color: 'var(--color-text-secondary)' }}>{video.channel}</p>
              <span style={{ fontSize: 14, color: 'var(--color-text-tertiary)' }}>{video.views} views</span>
            </div>
          </DeepLink>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Share Video Feature
 * Shows how to create shareable video deep links
 */
function ShareVideoButton({ videoId, videoTitle }) {
  const [copied, setCopied] = React.useState(false);
  
  const handleShare = async () => {
    const { createShareableLink } = await import('@min-apps/design-system/deepLinking');
    
    const link = createShareableLink(CONTENT_TYPES.VIDEO, videoId);
    
    if (navigator.share) {
      await navigator.share({
        title: videoTitle,
        text: `Watch ${videoTitle}`,
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
      {copied ? 'Link Copied!' : 'Share Video'}
    </button>
  );
}

/**
 * Example: Yourtube Settings
 * Shows how to add deep linking preferences
 */
function YourtubeSettings() {
  return (
    <AppLayout header={<AppHeader title="Settings" />}>
      <section style={{ marginBottom: spacing.section.marginBottom }}>
        <h2>Playback</h2>
        {/* Other settings */}
      </section>
      
      <section style={{ marginBottom: spacing.section.marginBottom }}>
        <h2>Deep Linking</h2>
        <DeepLinkPreferencesPanel title="Video Preferences" />
        <p style={{ color: 'var(--color-text-secondary)', fontSize: 14 }}>
          Choose which app opens when you click YouTube links from external sources.
        </p>
      </section>
    </AppLayout>
  );
}

/**
 * Example: Add to Queue from URL
 * Shows how to add videos to queue via YouTube URLs
 */
function AddToQueue() {
  const [videoUrl, setVideoUrl] = React.useState('');
  const { parseExternalUrl, extractIdFromUrl } = require('@min-apps/design-system/deepLinking');
  
  const handleAddToQueue = () => {
    const parsed = parseExternalUrl(videoUrl);
    
    if (parsed && parsed.contentType === CONTENT_TYPES.VIDEO) {
      addToVideoQueue(parsed.extractedId);
      setVideoUrl('');
    } else {
      alert('Please enter a valid YouTube video URL');
    }
  };
  
  return (
    <div>
      <h3>Add Video to Queue</h3>
      <div style={{ display: 'flex', gap: spacing.button.gap }}>
        <input
          type="text"
          value={videoUrl}
          onChange={(e) => setVideoUrl(e.target.value)}
          placeholder="Paste YouTube URL (youtube.com or youtu.be)"
          style={{ flex: 1 }}
        />
        <button onClick={handleAddToQueue}>Add to Queue</button>
      </div>
    </div>
  );
}

/**
 * Example: Comments with Video Links
 * Shows how to handle comments that might contain video links
 */
function VideoComments({ comments }) {
  const { extractAllIdsFromText } = require('@min-apps/design-system/deepLinking');
  
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
      {comments.map(comment => {
        const ids = extractAllIdsFromText(comment.text);
        
        return (
          <div key={comment.id} style={{ padding: `${spacing.list.itemPaddingY} 0` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: spacing[1] }}>
              <strong>{comment.author}</strong>
              <span style={{ color: 'var(--color-text-tertiary)', fontSize: 14 }}>{comment.timestamp}</span>
            </div>
            <p style={{ margin: 0 }}>{comment.text}</p>
            
            {ids.length > 0 && (
              <div style={{ marginTop: spacing[2] }}>
                <h4 style={{ margin: 0, fontSize: 14 }}>Videos mentioned:</h4>
                {ids.map((item, index) => (
                  <DeepLink key={index} href={item.url}>
                    Watch {item.contentType}
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
 * Example: Distraction-Free Mode Links
 * Shows how to open videos in distraction-free mode
 */
function DistractionFreeVideoList({ videos }) {
  const { open } = useOpenLink();
  
  const openInDistractionFreeMode = async (videoId) => {
    await open(`https://www.youtube.com/watch?v=${videoId}`, {
      forceApp: APP_IDS.YOURTUBE,
    });
  };
  
  return (
    <div>
      <h3>Watch Without Distractions</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {videos.map(video => (
          <div key={video.id} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: `${spacing.list.itemPaddingY} 0`,
          }}>
            <h4 style={{ margin: 0 }}>{video.title}</h4>
            <button onClick={() => openInDistractionFreeMode(video.id)}>
              Watch Focused
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Related Videos
 * Shows how to link to related videos
 */
function RelatedVideos({ related }) {
  return (
    <div>
      <h3>Related Videos</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {related.map(video => (
          <DeepLink
            key={video.id}
            href={`https://www.youtube.com/watch?v=${video.id}`}
            style={{ display: 'flex', alignItems: 'center', gap: spacing.list.itemGap, padding: `${spacing.list.itemPaddingY} 0`, textDecoration: 'none', color: 'inherit' }}
          >
            <img 
              src={video.thumbnail} 
              alt={video.title}
              style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ margin: 0 }}>{video.title}</p>
              <span style={{ fontSize: 14, color: 'var(--color-text-tertiary)' }}>{video.duration}</span>
            </div>
          </DeepLink>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Notification Handler
 * Shows how to handle deep links from notifications
 */
function handleVideoNotification(notificationData) {
  const { openLink, openContent } = require('@min-apps/design-system/deepLinking');
  
  if (notificationData.videoUrl) {
    openLink(notificationData.videoUrl);
  } else if (notificationData.videoId) {
    openContent(CONTENT_TYPES.VIDEO, notificationData.videoId, {
      appId: APP_IDS.YOURTUBE,
    });
  }
}

/**
 * Example: Trending Videos with Multiple Sources
 * Shows how to handle videos from different sources
 */
function TrendingVideos({ trending }) {
  const { open } = useOpenLink();
  
  return (
    <div>
      <h2>Trending Now</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: spacing.list.betweenItems }}>
        {trending.map(video => (
          <div 
            key={video.id}
            style={{
              display: 'flex', alignItems: 'center', gap: spacing.list.itemGap,
              padding: `${spacing.list.itemPaddingY} 0`, cursor: 'pointer',
            }}
            onClick={() => open(`https://www.youtube.com/watch?v=${video.id}`)}
          >
            <img 
              src={video.thumbnail} 
              alt={video.title}
              style={{ width: 48, height: 48, borderRadius: borders.radii.artTile, objectFit: 'cover', flexShrink: 0 }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <h4 style={{ margin: 0 }}>{video.title}</h4>
              <p style={{ margin: 0, color: 'var(--color-text-secondary)' }}>{video.channel}</p>
              <span style={{ fontSize: 14, color: 'var(--color-text-tertiary)' }}>
                {video.views} views{'   '}{video.uploadTime}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * Example: Import Playlist
 * Shows how to import playlists from YouTube URLs
 */
function ImportPlaylist() {
  const [playlistUrl, setPlaylistUrl] = React.useState('');
  const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
  
  const handleImport = () => {
    const parsed = parseExternalUrl(playlistUrl);
    
    if (parsed && parsed.contentType === CONTENT_TYPES.PLAYLIST) {
      importYouTubePlaylist(parsed.extractedId);
      setPlaylistUrl('');
    } else {
      alert('Please enter a valid YouTube playlist URL');
    }
  };
  
  return (
    <div>
      <h3>Import Playlist</h3>
      <div style={{ display: 'flex', gap: spacing.button.gap }}>
        <input
          type="text"
          value={playlistUrl}
          onChange={(e) => setPlaylistUrl(e.target.value)}
          placeholder="Paste YouTube playlist URL"
          style={{ flex: 1 }}
        />
        <button onClick={handleImport}>Import</button>
      </div>
    </div>
  );
}

// Example data
const exampleVideos = [
  {
    id: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    channel: 'Rick Astley',
    thumbnail: 'https://example.com/thumb1.jpg',
    views: '1.2B',
    duration: '3:33',
  },
];

const exampleChannels = [
  {
    id: 'UC-lHJZR3Gqxm24_Vd_AJ5Yw',
    name: 'PewDiePie',
    handle: 'pewdiepie',
    avatar: 'https://example.com/avatar1.jpg',
    channelId: 'UC-lHJZR3Gqxm24_Vd_AJ5Yw',
  },
];

// Placeholder functions
function addToVideoQueue(videoId) {
  console.log('Adding to queue:', videoId);
}

function importYouTubePlaylist(playlistId) {
  console.log('Importing playlist:', playlistId);
}

export {
  YourtubeApp,
  VideoQueue,
  ChannelSubscriptions,
  PlaylistManager,
  PriorityChannels,
  VideoDiscovery,
  ShareVideoButton,
  YourtubeSettings,
  AddToQueue,
  VideoComments,
  DistractionFreeVideoList,
  RelatedVideos,
  handleVideoNotification,
  TrendingVideos,
  ImportPlaylist,
  exampleVideos,
  exampleChannels,
};
