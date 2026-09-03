/**
 * Grid Component
 * Responsive grid layout
 */

import { spacing } from '../tokens/index.js';

export function Grid({
  children,
  columns = { xs: 1, sm: 2, md: 3, lg: 4 },
  gap = 'default',
  className = '',
  ...props
}) {
  const gapValues = {
    none: '0',
    small: spacing[2],
    default: spacing[4],
    large: spacing[6],
  };
  
  const styles = `
    display: grid;
    grid-template-columns: repeat(${columns.xs || 1}, 1fr);
    gap: ${gapValues[gap]};
    
    @media (min-width: 640px) {
      grid-template-columns: repeat(${columns.sm || columns.xs || 1}, 1fr);
    }
    
    @media (min-width: 768px) {
      grid-template-columns: repeat(${columns.md || columns.sm || columns.xs || 1}, 1fr);
    }
    
    @media (min-width: 1024px) {
      grid-template-columns: repeat(${columns.lg || columns.md || columns.sm || columns.xs || 1}, 1fr);
    }
  `;
  
  return {
    element: 'div',
    className: `min-grid ${className}`.trim(),
    style: styles,
    children,
    ...props,
  };
}

export default Grid;
