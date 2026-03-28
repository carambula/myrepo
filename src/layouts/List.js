/**
 * List Component
 * Container for list items with consistent spacing
 */

import { spacing } from '../tokens/index.js';

export function List({
  children,
  spacing: spacingProp = 'default',
  className = '',
  ...props
}) {
  const spacingValues = {
    compact: spacing[1],
    default: spacing.list.betweenItems,
    comfortable: spacing[4],
  };
  
  const styles = `
    display: flex;
    flex-direction: column;
    gap: ${spacingValues[spacingProp]};
    list-style: none;
    margin: 0;
    padding: 0;
  `;
  
  return {
    element: 'div',
    className: `min-list ${className}`.trim(),
    style: styles,
    children,
    ...props,
  };
}

export default List;
