/**
 * DismissButton Component
 * 
 * An animated dismiss button that slides in from the bottom left when scrolling
 * and expands when scrolled to the bottom. Used in show views to allow users
 * to dismiss/close the view.
 * 
 * Features:
 * - Slides in when user starts scrolling
 * - Compact size while scrolling (aligned with microplayer/search button)
 * - Expands to larger size when scrolled to bottom
 * - Always tappable to dismiss the view
 * 
 * Usage:
 * const [scrollState, setScrollState] = useState({ isScrolled: false, isAtBottom: false });
 * 
 * <DismissButton 
 *   isVisible={scrollState.isScrolled}
 *   isExpanded={scrollState.isAtBottom}
 *   onClick={handleDismiss}
 * />
 */

import { spacing, typography, borders, shadows, transitions, zIndex } from '../tokens/index.js';

export function DismissButton({
  isVisible = false,
  isExpanded = false,
  onClick,
  label = 'Close',
  icon = '↓',
  className = '',
  ...props
}) {
  // Button sizing
  const compactSize = '48px'; // Aligned with microplayer and search button
  const expandedSize = '56px';
  const currentSize = isExpanded ? expandedSize : compactSize;
  
  // Animation states
  const translateY = isVisible ? '0' : '80px'; // Slide from below
  const opacity = isVisible ? '1' : '0';
  
  const baseStyles = `
    position: fixed;
    bottom: ${spacing.page.marginBottom};
    left: ${spacing.page.marginLeft};
    width: ${currentSize};
    height: ${currentSize};
    border-radius: ${borders.radii.md};
    border: none;
    background-color: var(--color-surface-primary);
    color: var(--color-text-primary);
    cursor: pointer;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: ${spacing[1]};
    z-index: ${zIndex.fixed};
    box-shadow: ${shadows.buttonHover};
    
    /* Slide-in animation */
    transform: translateY(${translateY});
    opacity: ${opacity};
    transition: transform ${transitions.durations.normal} ${transitions.easings.easeOut},
                opacity ${transitions.durations.normal} ${transitions.easings.easeOut},
                width ${transitions.durations.normal} ${transitions.easings.easeOut},
                height ${transitions.durations.normal} ${transitions.easings.easeOut},
                background-color ${transitions.durations.fast} ${transitions.easings.easeOut};
    
    /* Prevent interaction when hidden */
    pointer-events: ${isVisible ? 'auto' : 'none'};
    
    &:hover {
      background-color: var(--color-hover-primary);
      box-shadow: ${shadows.card};
    }
    
    &:active {
      background-color: var(--color-active-primary);
      transform: translateY(${translateY}) scale(0.95);
    }
    
    @media (max-width: 767px) {
      bottom: ${spacing.page.marginBottomMobile};
      left: ${spacing.page.marginLeftMobile};
    }
  `;
  
  const iconStyles = `
    font-size: ${isExpanded ? typography.sizes.xl : typography.sizes.lg};
    line-height: 1;
    transition: font-size ${transitions.durations.normal} ${transitions.easings.easeOut};
  `;
  
  const labelStyles = `
    font-size: ${typography.sizes.xs};
    font-weight: ${typography.weights.medium};
    line-height: 1;
    margin: 0;
    opacity: ${isExpanded ? '1' : '0'};
    max-height: ${isExpanded ? '20px' : '0'};
    overflow: hidden;
    transition: opacity ${transitions.durations.normal} ${transitions.easings.easeOut},
                max-height ${transitions.durations.normal} ${transitions.easings.easeOut};
  `;

  return {
    element: 'button',
    type: 'button',
    'aria-label': label,
    onClick,
    className: `min-dismiss-button ${isExpanded ? 'min-dismiss-button--expanded' : 'min-dismiss-button--compact'} ${className}`.trim(),
    style: baseStyles,
    children: [
      {
        element: 'span',
        className: 'min-dismiss-button__icon',
        style: iconStyles,
        children: icon,
      },
      {
        element: 'span',
        className: 'min-dismiss-button__label',
        style: labelStyles,
        children: label,
      },
    ],
    ...props,
  };
}

export default DismissButton;
