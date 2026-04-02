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
import { borders } from '@min-apps/design-system/tokens';

/**
 * Example: Video Queue Component
 * Shows how to make all YouTube links open in Yourtube app
 */
function VideoQueue({ videos }) {
  return (
    <div className="video-queue">
      {videos.map(video => (
        <div key={video.id} className="video-item">
          <img 
            src={video.thumbnail} 
            alt={video.title}
            style={{ borderRadius: borders.radii.artTile }}
          />
          <div className="video-info">
            <h3>{video.title}</h3>
            <p>{video.channel}</p>
            
            {/* Deep link to YouTube - will open in Yourtube app */}
            <DeepLink href={`https://www.youtube.com/watch?v=${video.id}`}>
              Watch on YouTube
            </DeepLink>
            
            {/* Short URL format also supported */}
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
    <div className="channel-subscriptions">
      {channels.map(channel => (
        <div key={channel.id} className="channel-item">
          <img 
            src={channel.avatar} 
            alt={channel.name}
            style={{ borderRadius: borders.radii.artTile }}
          />
          <h4>{channel.name}</h4>
          
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
    <div className="playlist-manager">
      <h3>Your Playlists</h3>
      {playlists.map(playlist => (
        <div key={playlist.id} className="playlist-item">
          <img 
            src={playlist.thumbnail} 
            alt={playlist.title}
            style={{ borderRadius: borders.radii.artTile }}
          />
          <div className="playlist-info">
            <h4>{playlist.title}</h4>
            <span>{playlist.videoCount} videos</span>
            
            <DeepLink href={`https://www.youtube.com/playlist?list=${playlist.id}`}>
              Open Playlist
            </DeepLink>
          </div>
        </div>
      ))}
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
    <div className="priority-channels">
      <h3>Priority Channels</h3>
      <p>Get notified first when these channels upload</p>
      
      {priorityChannels.map(channel => (
        <div key={channel.id} className="priority-channel">
          <img src={channel.avatar} alt={channel.name} />
          <span>{channel.name}</span>
          <button onClick={() => handleOpenChannel(channel.id)}>
            Open
          </button>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Video Discovery
 * Shows how to handle video discovery with deep linking
 */
function VideoDiscovery({ recommendations }) {
  return (
    <div className="video-discovery">
      <h2>Recommended Videos</h2>
      <div className="recommendations-grid">
        {recommendations.map(video => (
          <DeepLink
            key={video.id}
            href={`https://www.youtube.com/watch?v=${video.id}`}
            className="recommendation-card"
          >
            <img 
              src={video.thumbnail} 
              alt={video.title}
              style={{ borderRadius: borders.radii.artTile }}
            />
            <h4>{video.title}</h4>
            <p>{video.channel}</p>
            <span>{video.views} views</span>
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
    <div className="settings-page">
      <h1>Settings</h1>
      
      <section>
        <h2>Playback</h2>
        {/* Other settings */}
      </section>
      
      <section>
        <h2>Deep Linking</h2>
        <DeepLinkPreferencesPanel title="Video Preferences" />
        <p className="help-text">
          Choose which app opens when you click YouTube links from external sources.
        </p>
      </section>
    </div>
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
      // Add to queue using the extracted ID
      addToVideoQueue(parsed.extractedId);
      setVideoUrl('');
    } else {
      alert('Please enter a valid YouTube video URL');
    }
  };
  
  return (
    <div className="add-to-queue">
      <h3>Add Video to Queue</h3>
      <input
        type="text"
        value={videoUrl}
        onChange={(e) => setVideoUrl(e.target.value)}
        placeholder="Paste YouTube URL (youtube.com or youtu.be)"
      />
      <button onClick={handleAddToQueue}>Add to Queue</button>
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
    <div className="video-comments">
      {comments.map(comment => {
        const ids = extractAllIdsFromText(comment.text);
        
        return (
          <div key={comment.id} className="comment">
            <div className="comment-header">
              <strong>{comment.author}</strong>
              <span>{comment.timestamp}</span>
            </div>
            <p>{comment.text}</p>
            
            {/* Show all referenced videos */}
            {ids.length > 0 && (
              <div className="referenced-videos">
                <h4>Videos mentioned:</h4>
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
    // Open the video, and the app can handle showing it in distraction-free mode
    await open(`https://www.youtube.com/watch?v=${videoId}`, {
      forceApp: APP_IDS.YOURTUBE,
    });
  };
  
  return (
    <div className="distraction-free-list">
      <h3>Watch Without Distractions</h3>
      {videos.map(video => (
        <div key={video.id} className="video-item">
          <h4>{video.title}</h4>
          <button onClick={() => openInDistractionFreeMode(video.id)}>
            Watch Focused
          </button>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Related Videos
 * Shows how to link to related videos
 */
function RelatedVideos({ related }) {
  return (
    <div className="related-videos">
      <h3>Related Videos</h3>
      <div className="related-grid">
        {related.map(video => (
          <DeepLink
            key={video.id}
            href={`https://www.youtube.com/watch?v=${video.id}`}
            className="related-video"
          >
            <img 
              src={video.thumbnail} 
              alt={video.title}
              style={{ borderRadius: borders.radii.artTile }}
            />
            <p>{video.title}</p>
            <span>{video.duration}</span>
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
    <div className="trending-videos">
      <h2>Trending Now</h2>
      {trending.map(video => (
        <div 
          key={video.id} 
          className="trending-video"
          onClick={() => open(`https://www.youtube.com/watch?v=${video.id}`)}
        >
          <img 
            src={video.thumbnail} 
            alt={video.title}
            style={{ borderRadius: borders.radii.artTile }}
          />
          <div className="video-info">
            <h4>{video.title}</h4>
            <p>{video.channel}</p>
            <div className="video-stats">
              <span>{video.views} views</span>
              <span>{video.uploadTime}</span>
            </div>
          </div>
        </div>
      ))}
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
    <div className="import-playlist">
      <h3>Import Playlist</h3>
      <input
        type="text"
        value={playlistUrl}
        onChange={(e) => setPlaylistUrl(e.target.value)}
        placeholder="Paste YouTube playlist URL"
      />
      <button onClick={handleImport}>Import</button>
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
