/**
 * FeatureHighlight Component
 * Displays a feature with icon and description
 */

import { spacing, typography, borders } from '../tokens/index.js';

export function FeatureHighlight({
  icon,
  iconAlt = 'Feature icon',
  title,
  description,
  className = '',
  ...props
}) {
  const containerStyles = `
    display: flex;
    gap: ${spacing[4]};
    padding: ${spacing[4]};
    background-color: var(--color-surface-primary);
    border-radius: ${borders.radii.lg};
    border: 1px solid var(--color-border-primary);
    transition: all 0.3s ease;
    
    &:hover {
      background-color: var(--color-hover-primary);
      border-color: var(--color-primary-main);
    }
    
    @media (max-width: 767px) {
      padding: ${spacing[3]};
      gap: ${spacing[3]};
    }
  `;
  
  const iconContainerStyles = `
    flex-shrink: 0;
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-main));
    border-radius: ${borders.radii.md};
    
    @media (max-width: 767px) {
      width: 40px;
      height: 40px;
    }
  `;
  
  const iconStyles = `
    width: 24px;
    height: 24px;
    object-fit: contain;
    
    @media (max-width: 767px) {
      width: 20px;
      height: 20px;
    }
  `;
  
  const contentStyles = `
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: ${spacing[1]};
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.h6.fontSize};
    font-weight: ${typography.styles.h6.fontWeight};
    color: var(--color-text-primary);
    margin: 0;
  `;
  
  const descriptionStyles = `
    font-size: ${typography.styles.body.fontSize};
    line-height: 1.5;
    color: var(--color-text-secondary);
    margin: 0;
  `;
  
  return {
    element: 'div',
    className: `min-feature-highlight ${className}`.trim(),
    style: containerStyles,
    children: [
      icon && {
        element: 'div',
        className: 'min-feature-highlight__icon-container',
        style: iconContainerStyles,
        children: {
          element: 'img',
          src: icon,
          alt: iconAlt,
          style: iconStyles,
          className: 'min-feature-highlight__icon',
        },
      },
      {
        element: 'div',
        className: 'min-feature-highlight__content',
        style: contentStyles,
        children: [
          title && {
            element: 'h3',
            style: titleStyles,
            className: 'min-feature-highlight__title',
            children: title,
          },
          description && {
            element: 'p',
            style: descriptionStyles,
            className: 'min-feature-highlight__description',
            children: description,
          },
        ].filter(Boolean),
      },
    ].filter(Boolean),
    ...props,
  };
}

export default FeatureHighlight;
