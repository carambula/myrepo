/**
 * Episode List Tap Behavior Test Example
 * 
 * This example demonstrates and tests the correct tap behavior for episode lists.
 * Use this as a reference implementation or for manual testing.
 */

import React from 'react';
import { List, EpisodeListItem } from '@min-apps/design-system/components';
import { spacing } from '@min-apps/design-system/tokens';

const TEST_EPISODES = [
  {
    id: 1,
    title: 'Episode 1: Introduction',
    podcastName: 'Test Podcast',
    artwork: '/test-artwork-1.jpg',
    duration: '45:30',
    isPlaying: false,
  },
  {
    id: 2,
    title: 'Episode 2: Advanced Topics',
    podcastName: 'Test Podcast',
    artwork: '/test-artwork-2.jpg',
    duration: '52:15',
    isPlaying: false,
  },
  {
    id: 3,
    title: 'Episode 3: Q&A Session',
    podcastName: 'Test Podcast',
    artwork: '/test-artwork-3.jpg',
    duration: '38:45',
    isPlaying: true,
  },
];

function EpisodeListTestExample() {
  const [episodes, setEpisodes] = React.useState(TEST_EPISODES);
  const [currentlyPlaying, setCurrentlyPlaying] = React.useState(3);
  const [lastAction, setLastAction] = React.useState(null);

  /**
   * TEST: This should be called when clicking art, title, or row
   * Should NOT be called when clicking play button
   */
  const handleEpisodeClick = (episode) => {
    const action = {
      type: 'OPEN_PLAYER',
      episodeId: episode.id,
      episodeTitle: episode.title,
      timestamp: new Date().toISOString(),
    };
    setLastAction(action);
    console.log('✅ CORRECT: Opening episode player', action);
  };

  /**
   * TEST: This should ONLY be called when clicking play button
   * Should NOT be called when clicking art, title, or row
   */
  const handlePlayClick = (episode) => {
    const isPlaying = currentlyPlaying === episode.id;
    const action = {
      type: isPlaying ? 'PAUSE' : 'PLAY',
      episodeId: episode.id,
      episodeTitle: episode.title,
      timestamp: new Date().toISOString(),
    };
    setLastAction(action);
    console.log(`✅ CORRECT: ${isPlaying ? 'Pausing' : 'Playing'} episode`, action);

    // Update playing state
    if (isPlaying) {
      setCurrentlyPlaying(null);
      setEpisodes(episodes.map(ep => ({ ...ep, isPlaying: false })));
    } else {
      setCurrentlyPlaying(episode.id);
      setEpisodes(episodes.map(ep => ({
        ...ep,
        isPlaying: ep.id === episode.id,
      })));
    }
  };

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto', padding: spacing[4] }}>
      <h1>Episode List Tap Behavior Test</h1>
      
      {/* Test Instructions */}
      <div style={{
        padding: spacing[4],
        backgroundColor: 'var(--color-background-secondary)',
        borderRadius: '8px',
        marginBottom: spacing[4],
      }}>
        <h2 style={{ marginTop: 0 }}>Test Instructions</h2>
        <ol>
          <li>Click on episode <strong>artwork</strong> → Should open player</li>
          <li>Click on episode <strong>title</strong> → Should open player</li>
          <li>Click on episode <strong>row</strong> (empty space) → Should open player</li>
          <li>Click on <strong>play button</strong> → Should play/pause episode</li>
          <li>Verify play button does NOT open player</li>
        </ol>
        <p style={{ marginBottom: 0 }}>
          Last action will be displayed below. Check console for detailed logs.
        </p>
      </div>

      {/* Last Action Display */}
      {lastAction && (
        <div style={{
          padding: spacing[3],
          backgroundColor: lastAction.type === 'OPEN_PLAYER' 
            ? 'rgba(59, 130, 246, 0.1)' 
            : 'rgba(16, 185, 129, 0.1)',
          borderLeft: `4px solid ${
            lastAction.type === 'OPEN_PLAYER' 
              ? 'rgb(59, 130, 246)' 
              : 'rgb(16, 185, 129)'
          }`,
          borderRadius: '4px',
          marginBottom: spacing[4],
        }}>
          <h3 style={{ margin: '0 0 8px 0' }}>Last Action</h3>
          <p style={{ margin: 0 }}>
            <strong>Type:</strong> {lastAction.type}<br />
            <strong>Episode:</strong> {lastAction.episodeTitle}<br />
            <strong>Time:</strong> {new Date(lastAction.timestamp).toLocaleTimeString()}
          </p>
        </div>
      )}

      {/* Episode List */}
      <h2>Episodes</h2>
      <List spacing="default">
        {episodes.map(episode => (
          <EpisodeListItem
            key={episode.id}
            artwork={episode.artwork}
            artworkAlt={episode.title}
            title={episode.title}
            subtitle={episode.podcastName}
            duration={episode.duration}
            isPlaying={episode.isPlaying}
            onEpisodeClick={() => handleEpisodeClick(episode)}
            onPlayClick={() => handlePlayClick(episode)}
          />
        ))}
      </List>

      {/* Expected Behavior Reference */}
      <div style={{
        marginTop: spacing[6],
        padding: spacing[4],
        backgroundColor: 'var(--color-background-secondary)',
        borderRadius: '8px',
      }}>
        <h2 style={{ marginTop: 0 }}>Expected Behavior</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '1px solid var(--color-border-primary)' }}>
              <th style={{ padding: spacing[2] }}>User Action</th>
              <th style={{ padding: spacing[2] }}>Expected Result</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style={{ padding: spacing[2] }}>Click artwork</td>
              <td style={{ padding: spacing[2] }}>OPEN_PLAYER</td>
            </tr>
            <tr>
              <td style={{ padding: spacing[2] }}>Click title</td>
              <td style={{ padding: spacing[2] }}>OPEN_PLAYER</td>
            </tr>
            <tr>
              <td style={{ padding: spacing[2] }}>Click row</td>
              <td style={{ padding: spacing[2] }}>OPEN_PLAYER</td>
            </tr>
            <tr>
              <td style={{ padding: spacing[2] }}>Click play button</td>
              <td style={{ padding: spacing[2] }}>PLAY or PAUSE</td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* Anti-Pattern Warning */}
      <div style={{
        marginTop: spacing[4],
        padding: spacing[4],
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        borderLeft: '4px solid rgb(239, 68, 68)',
        borderRadius: '4px',
      }}>
        <h3 style={{ margin: '0 0 8px 0', color: 'rgb(239, 68, 68)' }}>
          ❌ Common Mistake
        </h3>
        <p style={{ margin: 0 }}>
          If clicking the play button shows "OPEN_PLAYER" in the last action,
          the <code>e.stopPropagation()</code> is missing or not working correctly.
          This is the bug that was fixed in this PR.
        </p>
      </div>
    </div>
  );
}

export default EpisodeListTestExample;
