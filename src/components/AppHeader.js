/**
 * AppHeader Component
 * Standardized header with logo positioning across all min apps
 */

import { spacing, typography, shadows } from '../tokens/index.js';

export function AppHeader({
  logo,
  logoAlt = 'App Logo',
  title,
  actions,
  className = '',
  showShadow = false,
  ...props
}) {
  const headerStyles = `
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: ${spacing.page.marginTop} ${spacing.page.marginLeft};
    background-color: var(--color-background-primary);
    ${showShadow ? `box-shadow: ${shadows.sm};` : ''}
    
    @media (max-width: 767px) {
      padding: ${spacing.page.marginTopMobile} ${spacing.page.marginLeftMobile};
    }
  `;
  
  const logoContainerStyles = `
    display: flex;
    align-items: center;
    gap: ${spacing[4]};
  `;
  
  const logoStyles = `
    width: 48px;
    height: 48px;
    object-fit: contain;
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.h5.fontSize};
    font-weight: ${typography.styles.h5.fontWeight};
    color: var(--color-text-primary);
    margin: 0;
  `;
  
  const actionsStyles = `
    display: flex;
    align-items: center;
    gap: ${spacing[3]};
  `;
  
  return {
    element: 'header',
    className: `min-app-header ${className}`.trim(),
    style: headerStyles,
    children: [
      {
        element: 'div',
        style: logoContainerStyles,
        className: 'min-app-header__logo-container',
        children: [
          logo && {
            element: 'img',
            src: logo,
            alt: logoAlt,
            style: logoStyles,
            className: 'min-app-header__logo',
          },
          title && {
            element: 'h1',
            style: titleStyles,
            className: 'min-app-header__title',
            children: title,
          },
        ].filter(Boolean),
      },
      actions && {
        element: 'div',
        style: actionsStyles,
        className: 'min-app-header__actions',
        children: actions,
      },
    ].filter(Boolean),
    ...props,
  };
}

export default AppHeader;
