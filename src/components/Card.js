/**
 * Card Component
 * Standardized card container with consistent styling
 */

import { spacing, borders, shadows, transitions } from '../tokens/index.js';

export function Card({
  children,
  padding = 'medium',
  elevation = 'medium',
  hoverable = false,
  onClick,
  className = '',
  ...props
}) {
  const paddingValues = {
    none: '0',
    small: spacing[3],
    medium: spacing[4],
    large: spacing[6],
  };
  
  const elevationValues = {
    none: 'none',
    small: shadows.sm,
    medium: shadows.card,
    large: shadows.lg,
  };
  
  const baseStyles = `
    background-color: var(--color-surface-primary);
    border-radius: ${borders.radii.lg};
    box-shadow: ${elevationValues[elevation]};
    padding: ${paddingValues[padding]};
    transition: ${transitions.all};
    cursor: ${onClick || hoverable ? 'pointer' : 'default'};
  `;
  
  const hoverStyles = hoverable || onClick ? `
    &:hover {
      box-shadow: ${shadows.cardHover};
      transform: translateY(-2px);
    }
    
    &:active {
      transform: translateY(0);
      box-shadow: ${elevationValues[elevation]};
    }
  ` : '';
  
  return {
    element: 'div',
    className: `min-card ${className}`.trim(),
    style: baseStyles + hoverStyles,
    onClick,
    children,
    ...props,
  };
}

export default Card;
