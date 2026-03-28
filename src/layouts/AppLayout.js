/**
 * AppLayout Component
 * Standard page layout with consistent positioning and margins
 */

import { spacing } from '../tokens/index.js';

export function AppLayout({
  children,
  header,
  footer,
  className = '',
  ...props
}) {
  const layoutStyles = `
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    background-color: var(--color-background-primary);
  `;
  
  const mainStyles = `
    flex: 1;
    padding: ${spacing.page.marginTop} ${spacing.page.marginLeft} ${spacing.page.marginBottom} ${spacing.page.marginRight};
    
    @media (max-width: 767px) {
      padding: ${spacing.page.marginTopMobile} ${spacing.page.marginLeftMobile} ${spacing.page.marginBottomMobile} ${spacing.page.marginRightMobile};
    }
  `;
  
  return {
    element: 'div',
    className: `min-app-layout ${className}`.trim(),
    style: layoutStyles,
    children: [
      header,
      {
        element: 'main',
        className: 'min-app-layout__main',
        style: mainStyles,
        children,
      },
      footer,
    ].filter(Boolean),
    ...props,
  };
}

export default AppLayout;
