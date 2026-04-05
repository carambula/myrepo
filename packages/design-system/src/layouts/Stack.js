/**
 * Stack Component
 * Vertical or horizontal stack with consistent spacing
 */

import { spacing } from '../tokens/index.js';

export function Stack({
  children,
  direction = 'vertical',
  spacing: spacingProp = 'default',
  align = 'stretch',
  justify = 'flex-start',
  className = '',
  ...props
}) {
  const spacingValues = {
    none: '0',
    small: spacing.component.gapSmall,
    default: spacing.component.gap,
    large: spacing.component.gapLarge,
  };
  
  const styles = `
    display: flex;
    flex-direction: ${direction === 'vertical' ? 'column' : 'row'};
    gap: ${spacingValues[spacingProp]};
    align-items: ${align};
    justify-content: ${justify};
  `;
  
  return {
    element: 'div',
    className: `min-stack min-stack--${direction} ${className}`.trim(),
    style: styles,
    children,
    ...props,
  };
}

export default Stack;
