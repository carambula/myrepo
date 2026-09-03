/**
 * PermissionRequest Component
 * UI for requesting user permissions (notifications, etc.)
 */

import { spacing, typography, borders, shadows } from '../tokens/index.js';

export function PermissionRequest({
  icon,
  iconAlt = 'Permission icon',
  title,
  description,
  benefits = [],
  permissionType = 'notifications',
  onGrant,
  onDeny,
  grantButtonText = 'Allow',
  denyButtonText = 'Not Now',
  className = '',
  ...props
}) {
  const containerStyles = `
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: ${spacing[6]};
    background-color: var(--color-surface-primary);
    border-radius: ${borders.radii.xl};
    border: 1px solid var(--color-border-primary);
    box-shadow: ${shadows.large};
    max-width: 500px;
    margin: 0 auto;
    
    @media (max-width: 767px) {
      padding: ${spacing[4]};
    }
  `;
  
  const iconContainerStyles = `
    width: 80px;
    height: 80px;
    margin-bottom: ${spacing[4]};
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, var(--color-primary-main), var(--color-primary-dark));
    border-radius: ${borders.radii.full};
    box-shadow: ${shadows.medium};
  `;
  
  const iconStyles = `
    width: 40px;
    height: 40px;
    object-fit: contain;
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.h3.fontSize};
    font-weight: ${typography.styles.h3.fontWeight};
    line-height: ${typography.styles.h3.lineHeight};
    color: var(--color-text-primary);
    margin: 0 0 ${spacing[3]} 0;
  `;
  
  const descriptionStyles = `
    font-size: ${typography.styles.body.fontSize};
    line-height: 1.6;
    color: var(--color-text-secondary);
    margin: 0 0 ${spacing[5]} 0;
  `;
  
  const benefitsListStyles = `
    list-style: none;
    padding: 0;
    margin: 0 0 ${spacing[6]} 0;
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: ${spacing[3]};
  `;
  
  const benefitItemStyles = `
    display: flex;
    align-items: center;
    gap: ${spacing[3]};
    padding: ${spacing[3]};
    background-color: var(--color-background-secondary);
    border-radius: ${borders.radii.md};
    text-align: left;
  `;
  
  const benefitIconStyles = `
    width: 20px;
    height: 20px;
    color: var(--color-success-main);
    flex-shrink: 0;
  `;
  
  const benefitTextStyles = `
    font-size: ${typography.styles.body.fontSize};
    color: var(--color-text-primary);
    flex: 1;
  `;
  
  const buttonGroupStyles = `
    display: flex;
    flex-direction: column;
    gap: ${spacing[3]};
    width: 100%;
  `;
  
  const buttonStyles = (variant) => `
    width: 100%;
    padding: ${spacing[3]} ${spacing[6]};
    font-family: ${typography.fonts.primary};
    font-size: ${typography.styles.button.fontSize};
    font-weight: ${typography.styles.button.fontWeight};
    border: none;
    border-radius: ${borders.radii.md};
    cursor: pointer;
    transition: all 0.3s ease;
    background-color: var(--color-${variant}-main);
    color: var(--color-${variant}-contrast);
    
    &:hover {
      background-color: var(--color-${variant}-dark);
      transform: translateY(-1px);
    }
    
    &:active {
      transform: translateY(0);
    }
  `;
  
  const secondaryButtonStyles = `
    width: 100%;
    padding: ${spacing[3]} ${spacing[6]};
    font-family: ${typography.fonts.primary};
    font-size: ${typography.styles.button.fontSize};
    background: transparent;
    border: none;
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: all 0.3s ease;
    
    &:hover {
      color: var(--color-text-primary);
    }
  `;
  
  return {
    element: 'div',
    className: `min-permission-request ${className}`.trim(),
    style: containerStyles,
    children: [
      icon && {
        element: 'div',
        className: 'min-permission-request__icon-container',
        style: iconContainerStyles,
        children: {
          element: 'img',
          src: icon,
          alt: iconAlt,
          style: iconStyles,
          className: 'min-permission-request__icon',
        },
      },
      title && {
        element: 'h2',
        style: titleStyles,
        className: 'min-permission-request__title',
        children: title,
      },
      description && {
        element: 'p',
        style: descriptionStyles,
        className: 'min-permission-request__description',
        children: description,
      },
      benefits.length > 0 && {
        element: 'ul',
        style: benefitsListStyles,
        className: 'min-permission-request__benefits',
        children: benefits.map((benefit, index) => ({
          element: 'li',
          key: index,
          style: benefitItemStyles,
          className: 'min-permission-request__benefit-item',
          children: [
            {
              element: 'span',
              style: benefitIconStyles,
              children: '✓',
            },
            {
              element: 'span',
              style: benefitTextStyles,
              children: benefit,
            },
          ],
        })),
      },
      {
        element: 'div',
        style: buttonGroupStyles,
        className: 'min-permission-request__buttons',
        children: [
          {
            element: 'button',
            onClick: onGrant,
            style: buttonStyles('primary'),
            className: 'min-permission-request__grant',
            children: grantButtonText,
          },
          {
            element: 'button',
            onClick: onDeny,
            style: secondaryButtonStyles,
            className: 'min-permission-request__deny',
            children: denyButtonText,
          },
        ],
      },
    ].filter(Boolean),
    ...props,
  };
}

export default PermissionRequest;
