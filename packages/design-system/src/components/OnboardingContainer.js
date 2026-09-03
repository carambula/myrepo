/**
 * OnboardingContainer Component
 * Complete onboarding experience that integrates all steps
 * This is a high-level component that apps can use directly
 */

import { OnboardingFlow } from './OnboardingFlow.js';
import { OnboardingStep } from './OnboardingStep.js';
import { FeatureHighlight } from './FeatureHighlight.js';
import { PermissionRequest } from './PermissionRequest.js';
import { ThemeToggle } from './ThemeToggle.js';
import { OnboardingManager } from '../onboarding/onboardingManager.js';
import { spacing, typography, borders } from '../tokens/index.js';

export function OnboardingContainer({
  config,
  onComplete,
  onSkip,
  onRequestNotifications,
  onSelectTheme,
  className = '',
  ...props
}) {
  const [currentStep, setCurrentStep] = React.useState(
    OnboardingManager.getCurrentStep(config.appId)
  );
  
  const totalSteps = config.steps.length;
  const stepConfig = config.steps[currentStep - 1];
  
  const handleNext = () => {
    if (currentStep < totalSteps) {
      const nextStep = currentStep + 1;
      setCurrentStep(nextStep);
      OnboardingManager.saveCurrentStep(config.appId, nextStep);
    }
  };
  
  const handlePrevious = () => {
    if (currentStep > 1) {
      const prevStep = currentStep - 1;
      setCurrentStep(prevStep);
      OnboardingManager.saveCurrentStep(config.appId, prevStep);
    }
  };
  
  const handleComplete = () => {
    OnboardingManager.markOnboardingComplete(config.appId);
    if (onComplete) {
      onComplete(config.defaultSettings);
    }
  };
  
  const handleSkip = () => {
    OnboardingManager.skipOnboarding(config.appId);
    if (onSkip) {
      onSkip();
    }
  };
  
  const renderStepContent = () => {
    switch (stepConfig.type) {
      case 'theme-selector':
        return renderThemeSelector();
      case 'priority-podcast-selector':
      case 'priority-channel-selector':
        return renderPrioritySelector();
      case 'notification-preferences':
        return renderNotificationPreferences();
      default:
        return renderDefaultStep();
    }
  };
  
  const renderDefaultStep = () => {
    if (stepConfig.permissionType === 'notifications') {
      return (
        <PermissionRequest
          icon={stepConfig.icon || '/assets/icon-notifications.svg'}
          title={stepConfig.title}
          description={stepConfig.description}
          benefits={stepConfig.benefits || []}
          permissionType={stepConfig.permissionType}
          onGrant={() => {
            if (onRequestNotifications) {
              onRequestNotifications();
            }
            handleNext();
          }}
          onDeny={handleNext}
        />
      );
    }
    
    return (
      <OnboardingStep
        icon={stepConfig.icon}
        title={stepConfig.title}
        description={stepConfig.description}
        stepNumber={currentStep}
        totalSteps={totalSteps}
      >
        {stepConfig.features && renderFeatures(stepConfig.features)}
      </OnboardingStep>
    );
  };
  
  const renderFeatures = (features) => {
    const featuresContainerStyles = `
      display: flex;
      flex-direction: column;
      gap: ${spacing[3]};
      width: 100%;
      margin-top: ${spacing[4]};
    `;
    
    return {
      element: 'div',
      style: featuresContainerStyles,
      className: 'onboarding-features',
      children: features.map((feature, index) => (
        <FeatureHighlight
          key={index}
          icon={feature.icon}
          title={feature.title}
          description={feature.description}
        />
      )),
    };
  };
  
  const renderThemeSelector = () => {
    const themeSelectorStyles = `
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: ${spacing[6]};
      padding: ${spacing[6]};
    `;
    
    const titleStyles = `
      font-size: ${typography.styles.h2.fontSize};
      font-weight: ${typography.styles.h2.fontWeight};
      color: var(--color-text-primary);
      margin: 0;
      text-align: center;
    `;
    
    const descriptionStyles = `
      font-size: ${typography.styles.body.fontSize};
      color: var(--color-text-secondary);
      text-align: center;
      max-width: 400px;
      margin: 0;
    `;
    
    const themeOptionsStyles = `
      display: flex;
      gap: ${spacing[4]};
      flex-wrap: wrap;
      justify-content: center;
    `;
    
    const themeOptionStyles = (isSelected) => `
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: ${spacing[2]};
      padding: ${spacing[4]};
      background-color: var(--color-surface-primary);
      border: 2px solid ${isSelected ? 'var(--color-primary-main)' : 'var(--color-border-primary)'};
      border-radius: ${borders.radii.lg};
      cursor: pointer;
      transition: all 0.3s ease;
      min-width: 120px;
      
      &:hover {
        border-color: var(--color-primary-main);
        transform: translateY(-2px);
      }
    `;
    
    return (
      <OnboardingStep
        title={stepConfig.title}
        description={stepConfig.description}
        stepNumber={currentStep}
        totalSteps={totalSteps}
      >
        <ThemeToggle />
      </OnboardingStep>
    );
  };
  
  const renderPrioritySelector = () => {
    const infoStyles = `
      text-align: center;
      color: var(--color-text-secondary);
      font-size: ${typography.styles.body.fontSize};
      padding: ${spacing[6]};
    `;
    
    return (
      <OnboardingStep
        title={stepConfig.title}
        description={stepConfig.description}
        stepNumber={currentStep}
        totalSteps={totalSteps}
      >
        <div style={infoStyles}>
          You can set up priority {stepConfig.type === 'priority-podcast-selector' ? 'podcasts' : 'channels'} 
          {' '}after completing onboarding in the app settings.
        </div>
      </OnboardingStep>
    );
  };
  
  const renderNotificationPreferences = () => {
    return (
      <OnboardingStep
        title={stepConfig.title}
        description={stepConfig.description}
        stepNumber={currentStep}
        totalSteps={totalSteps}
      >
        {stepConfig.settings && renderNotificationSettings(stepConfig.settings)}
      </OnboardingStep>
    );
  };
  
  const renderNotificationSettings = (settings) => {
    const settingsContainerStyles = `
      display: flex;
      flex-direction: column;
      gap: ${spacing[3]};
      width: 100%;
      margin-top: ${spacing[4]};
    `;
    
    const settingItemStyles = `
      padding: ${spacing[4]};
      background-color: var(--color-surface-primary);
      border-radius: ${borders.radii.md};
      border: 1px solid var(--color-border-primary);
    `;
    
    const settingTitleStyles = `
      font-size: ${typography.styles.h6.fontSize};
      font-weight: ${typography.styles.h6.fontWeight};
      color: var(--color-text-primary);
      margin: 0 0 ${spacing[1]} 0;
    `;
    
    const settingDescStyles = `
      font-size: ${typography.styles.bodySmall.fontSize};
      color: var(--color-text-secondary);
      margin: 0;
    `;
    
    return {
      element: 'div',
      style: settingsContainerStyles,
      className: 'notification-settings-preview',
      children: settings.map((setting, index) => ({
        element: 'div',
        key: index,
        style: settingItemStyles,
        children: [
          {
            element: 'h4',
            style: settingTitleStyles,
            children: setting.title,
          },
          {
            element: 'p',
            style: settingDescStyles,
            children: setting.description,
          },
        ],
      })),
    };
  };
  
  return (
    <OnboardingFlow
      currentStep={currentStep}
      totalSteps={totalSteps}
      onNext={handleNext}
      onPrevious={handlePrevious}
      onSkip={handleSkip}
      onComplete={handleComplete}
      showSkip={currentStep < totalSteps}
      showPrevious={currentStep > 1}
      completeButtonText={stepConfig.ctaText || 'Get Started'}
      className={className}
      {...props}
    >
      {renderStepContent()}
    </OnboardingFlow>
  );
}

export default OnboardingContainer;
