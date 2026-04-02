/**
 * EpisodeListItem Component
 * Specialized list item for podcast episodes with proper tap behavior:
 * - Art and title open the episode detail/player view
 * - Play button plays/pauses the episode
 * 
 * This component enforces the correct interaction pattern for all episode lists
 * across all min apps (PodLink, etc.)
 */

import { spacing, typography, borders, shadows, transitions } from '../tokens/index.js';

export function EpisodeListItem({
  title,
  subtitle,
  artwork,
  artworkAlt = '',
  duration,
  isPlaying = false,
  onEpisodeClick,
  onPlayClick,
  className = '',
  ...props
}) {
  const styles = `
    display: flex;
    align-items: center;
    gap: ${spacing.list.itemGap};
    padding: ${spacing.list.itemPaddingY} ${spacing.list.itemPaddingX};
    background-color: var(--color-surface-primary);
    border-radius: ${borders.radii.md};
    transition: ${transitions.all};
    cursor: ${onEpisodeClick ? 'pointer' : 'default'};
    margin-bottom: ${spacing.list.betweenItems};
    
    &:hover {
      background-color: var(--color-hover-primary);
      box-shadow: ${shadows.card};
    }
    
    &:active {
      background-color: var(--color-active-primary);
    }
  `;
  
  const artworkStyles = `
    width: 64px;
    height: 64px;
    border-radius: ${borders.radii.sm};
    object-fit: cover;
    flex-shrink: 0;
  `;
  
  const contentStyles = `
    flex: 1;
    min-width: 0;
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.body.fontSize};
    font-weight: ${typography.weights.semibold};
    color: var(--color-text-primary);
    margin: 0 0 ${spacing[1]} 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `;
  
  const subtitleStyles = `
    font-size: ${typography.styles.bodySmall.fontSize};
    color: var(--color-text-secondary);
    margin: 0 0 ${spacing[1]} 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `;
  
  const durationStyles = `
    font-size: ${typography.styles.caption.fontSize};
    color: var(--color-text-tertiary);
    margin: 0;
  `;
  
  const playButtonStyles = `
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: none;
    background-color: var(--color-primary-main);
    color: white;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: ${transitions.all};
    font-size: 14px;
    
    &:hover {
      background-color: var(--color-primary-dark);
      transform: scale(1.05);
    }
    
    &:active {
      transform: scale(0.95);
    }
  `;

  return {
    element: 'div',
    className: `min-episode-list-item ${className}`.trim(),
    style: styles,
    onClick: onEpisodeClick,
    children: [
      artwork && {
        element: 'img',
        src: artwork,
        alt: artworkAlt,
        style: artworkStyles,
        className: 'min-episode-list-item__artwork',
      },
      {
        element: 'div',
        style: contentStyles,
        className: 'min-episode-list-item__content',
        children: [
          title && {
            element: 'h3',
            style: titleStyles,
            className: 'min-episode-list-item__title',
            children: title,
          },
          subtitle && {
            element: 'p',
            style: subtitleStyles,
            className: 'min-episode-list-item__subtitle',
            children: subtitle,
          },
          duration && {
            element: 'span',
            style: durationStyles,
            className: 'min-episode-list-item__duration',
            children: duration,
          },
        ].filter(Boolean),
      },
      onPlayClick && {
        element: 'button',
        type: 'button',
        'aria-label': isPlaying ? 'Pause episode' : 'Play episode',
        style: playButtonStyles,
        className: 'min-episode-list-item__play-button',
        onClick: (e) => {
          e.stopPropagation();
          onPlayClick(e);
        },
        children: isPlaying ? '⏸' : '▶',
      },
    ].filter(Boolean),
    ...props,
  };
}

export default EpisodeListItem;
