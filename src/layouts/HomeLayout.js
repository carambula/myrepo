/**
 * HomeLayout Component
 * Standard home page layout with logo at top and consistent positioning
 */

import { spacing, typography } from '../tokens/index.js';

export function HomeLayout({
  logo,
  logoAlt = 'App Logo',
  title,
  subtitle,
  children,
  className = '',
  ...props
}) {
  const layoutStyles = `
    display: flex;
    flex-direction: column;
    align-items: center;
    min-height: 100vh;
    background-color: var(--color-background-primary);
    padding: 0 ${spacing.page.marginLeft};
    
    @media (max-width: 767px) {
      padding: 0 ${spacing.page.marginLeftMobile};
    }
  `;
  
  const logoContainerStyles = `
    margin-top: ${spacing.logo.marginTop};
    margin-bottom: ${spacing.logo.marginBottom};
    text-align: center;
    
    @media (max-width: 767px) {
      margin-top: ${spacing.logo.marginTopMobile};
      margin-bottom: ${spacing.logo.marginBottomMobile};
    }
  `;
  
  const logoStyles = `
    width: 120px;
    height: 120px;
    object-fit: contain;
    margin-bottom: ${spacing[4]};
    
    @media (max-width: 767px) {
      width: 80px;
      height: 80px;
    }
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.h2.fontSize};
    font-weight: ${typography.styles.h2.fontWeight};
    line-height: ${typography.styles.h2.lineHeight};
    color: var(--color-text-primary);
    margin: 0 0 ${spacing[2]} 0;
    
    @media (max-width: 767px) {
      font-size: ${typography.styles.h3.fontSize};
    }
  `;
  
  const subtitleStyles = `
    font-size: ${typography.styles.bodyLarge.fontSize};
    color: var(--color-text-secondary);
    margin: 0 0 ${spacing[6]} 0;
  `;
  
  const contentStyles = `
    width: 100%;
    max-width: 600px;
    flex: 1;
  `;
  
  return {
    element: 'div',
    className: `min-home-layout ${className}`.trim(),
    style: layoutStyles,
    children: [
      {
        element: 'div',
        className: 'min-home-layout__header',
        style: logoContainerStyles,
        children: [
          logo && {
            element: 'img',
            src: logo,
            alt: logoAlt,
            style: logoStyles,
            className: 'min-home-layout__logo',
          },
          title && {
            element: 'h1',
            style: titleStyles,
            className: 'min-home-layout__title',
            children: title,
          },
          subtitle && {
            element: 'p',
            style: subtitleStyles,
            className: 'min-home-layout__subtitle',
            children: subtitle,
          },
        ].filter(Boolean),
      },
      {
        element: 'div',
        className: 'min-home-layout__content',
        style: contentStyles,
        children,
      },
    ],
    ...props,
  };
}

export default HomeLayout;
