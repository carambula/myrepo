/**
 * OnboardingStep Component
 * Individual step in the onboarding flow
 */

import { spacing, typography, borders, shadows } from '../tokens/index.js';

export function OnboardingStep({
  icon,
  iconAlt = 'Step icon',
  title,
  description,
  children,
  className = '',
  stepNumber,
  totalSteps,
  ...props
}) {
  const containerStyles = `
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: ${spacing[6]};
    width: 100%;
    max-width: 500px;
    margin: 0 auto;
    
    @media (max-width: 767px) {
      padding: ${spacing[4]};
    }
  `;
  
  const iconContainerStyles = `
    width: 120px;
    height: 120px;
    margin-bottom: ${spacing[6]};
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, var(--color-primary-main), var(--color-primary-dark));
    border-radius: ${borders.radii.full};
    box-shadow: ${shadows.medium};
    
    @media (max-width: 767px) {
      width: 100px;
      height: 100px;
      margin-bottom: ${spacing[4]};
    }
  `;
  
  const iconStyles = `
    width: 60px;
    height: 60px;
    object-fit: contain;
    
    @media (max-width: 767px) {
      width: 50px;
      height: 50px;
    }
  `;
  
  const titleStyles = `
    font-size: ${typography.styles.h2.fontSize};
    font-weight: ${typography.styles.h2.fontWeight};
    line-height: ${typography.styles.h2.lineHeight};
    color: var(--color-text-primary);
    margin: 0 0 ${spacing[4]} 0;
    
    @media (max-width: 767px) {
      font-size: ${typography.styles.h3.fontSize};
    }
  `;
  
  const descriptionStyles = `
    font-size: ${typography.styles.bodyLarge.fontSize};
    line-height: 1.6;
    color: var(--color-text-secondary);
    margin: 0 0 ${spacing[6]} 0;
    max-width: 400px;
    
    @media (max-width: 767px) {
      font-size: ${typography.styles.body.fontSize};
    }
  `;
  
  const progressContainerStyles = `
    display: flex;
    gap: ${spacing[2]};
    margin-bottom: ${spacing[6]};
  `;
  
  const progressDotStyles = (isActive) => `
    width: 8px;
    height: 8px;
    border-radius: ${borders.radii.full};
    background-color: ${isActive ? 'var(--color-primary-main)' : 'var(--color-border-primary)'};
    transition: background-color 0.3s ease;
  `;
  
  const contentStyles = `
    width: 100%;
  `;
  
  return {
    element: 'div',
    className: `min-onboarding-step ${className}`.trim(),
    style: containerStyles,
    children: [
      totalSteps && stepNumber && {
        element: 'div',
        className: 'min-onboarding-step__progress',
        style: progressContainerStyles,
        children: Array.from({ length: totalSteps }, (_, i) => ({
          element: 'div',
          key: i,
          className: 'min-onboarding-step__progress-dot',
          style: progressDotStyles(i + 1 === stepNumber),
        })),
      },
      icon && {
        element: 'div',
        className: 'min-onboarding-step__icon-container',
        style: iconContainerStyles,
        children: {
          element: 'img',
          src: icon,
          alt: iconAlt,
          style: iconStyles,
          className: 'min-onboarding-step__icon',
        },
      },
      title && {
        element: 'h2',
        style: titleStyles,
        className: 'min-onboarding-step__title',
        children: title,
      },
      description && {
        element: 'p',
        style: descriptionStyles,
        className: 'min-onboarding-step__description',
        children: description,
      },
      children && {
        element: 'div',
        className: 'min-onboarding-step__content',
        style: contentStyles,
        children,
      },
    ].filter(Boolean),
    ...props,
  };
}

export default OnboardingStep;
