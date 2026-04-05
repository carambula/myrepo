/**
 * ContentContainer Component
 * Centers content with max width and consistent padding
 */

import { spacing } from '../tokens/index.js';

export function ContentContainer({
  children,
  maxWidth = 'default',
  padding = 'default',
  className = '',
  ...props
}) {
  const maxWidthValues = {
    small: '640px',
    default: '1200px',
    large: '1400px',
    full: '100%',
  };
  
  const paddingValues = {
    none: '0',
    small: spacing[3],
    /* Horizontal default matches page grid (mov min); see docs/layout-margins-mov-min.md */
    default: spacing.page.marginLeft,
    large: spacing[6],
  };
  
  const horizontal = paddingValues[padding];
  const styles = `
    max-width: ${maxWidthValues[maxWidth]};
    margin-left: auto;
    margin-right: auto;
    padding-left: ${horizontal};
    padding-right: ${horizontal};
    width: 100%;
    
    ${
      padding === 'default'
        ? `@media (max-width: 767px) {
      padding-left: ${spacing.page.marginLeftMobile};
      padding-right: ${spacing.page.marginRightMobile};
    }`
        : ''
    }
  `;
  
  return {
    element: 'div',
    className: `min-content-container ${className}`.trim(),
    style: styles,
    children,
    ...props,
  };
}

export default ContentContainer;
