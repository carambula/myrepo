/**
 * OnboardingFlow Component
 * Container for multi-step onboarding experience
 */

import { spacing, typography, borders, transitions } from '../tokens/index.js';

export function OnboardingFlow({
  currentStep = 1,
  totalSteps,
  onNext,
  onPrevious,
  onSkip,
  onComplete,
  showSkip = true,
  showPrevious = true,
  nextButtonText = 'Next',
  previousButtonText = 'Previous',
  skipButtonText = 'Skip',
  completeButtonText = 'Get Started',
  children,
  className = '',
  ...props
}) {
  const containerStyles = `
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    background-color: var(--color-background-primary);
    position: relative;
  `;
  
  const contentStyles = `
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: ${spacing[6]} ${spacing[4]};
    
    @media (max-width: 767px) {
      padding: ${spacing[4]} ${spacing[3]};
    }
  `;
  
  const navigationStyles = `
    display: flex;
    gap: ${spacing[4]};
    padding: ${spacing[6]};
    border-top: 1px solid var(--color-border-primary);
    background-color: var(--color-background-secondary);
    
    @media (max-width: 767px) {
      padding: ${spacing[4]};
      flex-direction: column-reverse;
    }
  `;
  
  const buttonGroupStyles = `
    flex: 1;
    display: flex;
    gap: ${spacing[3]};
    
    @media (max-width: 767px) {
      flex-direction: column;
    }
  `;
  
  const buttonStyles = (variant = 'secondary') => `
    flex: 1;
    padding: ${spacing.button.paddingY} ${spacing.button.paddingX};
    font-family: ${typography.fonts.primary};
    font-size: ${typography.styles.button.fontSize};
    font-weight: ${typography.styles.button.fontWeight};
    border: none;
    border-radius: ${borders.radii.md};
    cursor: pointer;
    transition: ${transitions.all};
    background-color: var(--color-${variant}-main);
    color: var(--color-${variant}-contrast);
    
    &:hover {
      background-color: var(--color-${variant}-dark);
      transform: translateY(-1px);
    }
    
    &:active {
      transform: translateY(0);
    }
    
    @media (max-width: 767px) {
      width: 100%;
    }
  `;
  
  const skipButtonStyles = `
    padding: ${spacing.button.paddingY} ${spacing.button.paddingX};
    font-family: ${typography.fonts.primary};
    font-size: ${typography.styles.button.fontSize};
    background: transparent;
    border: none;
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: ${transitions.all};
    
    &:hover {
      color: var(--color-text-primary);
    }
  `;
  
  const isLastStep = currentStep === totalSteps;
  
  return {
    element: 'div',
    className: `min-onboarding-flow ${className}`.trim(),
    style: containerStyles,
    children: [
      {
        element: 'div',
        className: 'min-onboarding-flow__content',
        style: contentStyles,
        children,
      },
      {
        element: 'nav',
        className: 'min-onboarding-flow__navigation',
        style: navigationStyles,
        children: [
          {
            element: 'div',
            style: buttonGroupStyles,
            children: [
              showPrevious && currentStep > 1 && {
                element: 'button',
                onClick: onPrevious,
                style: buttonStyles('secondary'),
                className: 'min-onboarding-flow__previous',
                children: previousButtonText,
              },
              {
                element: 'button',
                onClick: isLastStep ? onComplete : onNext,
                style: buttonStyles('primary'),
                className: 'min-onboarding-flow__next',
                children: isLastStep ? completeButtonText : nextButtonText,
              },
            ].filter(Boolean),
          },
          showSkip && !isLastStep && {
            element: 'button',
            onClick: onSkip,
            style: skipButtonStyles,
            className: 'min-onboarding-flow__skip',
            children: skipButtonText,
          },
        ].filter(Boolean),
      },
    ],
    ...props,
  };
}

export default OnboardingFlow;
