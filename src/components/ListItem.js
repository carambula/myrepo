/**
 * ListItem Component
 * Standardized list item with consistent spacing and layout across all min apps
 */

import { spacing, typography, borders, shadows, transitions } from '../tokens/index.js';

export function ListItem({
  title,
  subtitle,
  image,
  imageAlt = '',
  action,
  onClick,
  className = '',
  children,
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
    cursor: ${onClick ? 'pointer' : 'default'};
    margin-bottom: ${spacing.list.betweenItems};
    
    &:hover {
      background-color: var(--color-hover-primary);
      box-shadow: ${shadows.card};
    }
    
    &:active {
      background-color: var(--color-active-primary);
    }
  `;
  
  const imageStyles = `
    width: 48px;
    height: 48px;
    border-radius: ${borders.radii.md};
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
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `;
  
  return {
    element: 'div',
    className: `min-list-item ${className}`.trim(),
    style: styles,
    onClick,
    children: [
      image && {
        element: 'img',
        src: image,
        alt: imageAlt,
        style: imageStyles,
        className: 'min-list-item__image',
      },
      {
        element: 'div',
        style: contentStyles,
        className: 'min-list-item__content',
        children: [
          title && {
            element: 'h3',
            style: titleStyles,
            className: 'min-list-item__title',
            children: title,
          },
          subtitle && {
            element: 'p',
            style: subtitleStyles,
            className: 'min-list-item__subtitle',
            children: subtitle,
          },
          children,
        ].filter(Boolean),
      },
      action && {
        element: 'div',
        className: 'min-list-item__action',
        children: action,
      },
    ].filter(Boolean),
    ...props,
  };
}

export default ListItem;
