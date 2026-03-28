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
    default: spacing.container.paddingX,
    large: spacing[6],
  };
  
  const styles = `
    max-width: ${maxWidthValues[maxWidth]};
    margin-left: auto;
    margin-right: auto;
    padding-left: ${paddingValues[padding]};
    padding-right: ${paddingValues[padding]};
    width: 100%;
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
