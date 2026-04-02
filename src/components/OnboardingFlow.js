/**
 * OnboardingFlow Component
 * Main onboarding flow container with step navigation
 */

import { useState } from 'react';

export function OnboardingFlow({
  steps = [],
  appId,
  onComplete,
  onSkip,
  showSkip = true
}) {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [stepData, setStepData] = useState({});

  const currentStep = steps[currentStepIndex];
  const isFirstStep = currentStepIndex === 0;
  const isLastStep = currentStepIndex === steps.length - 1;

  const handleNext = (data = {}) => {
    setStepData({ ...stepData, ...data });

    if (isLastStep) {
      if (onComplete) {
        onComplete({ ...stepData, ...data });
      }
    } else {
      setCurrentStepIndex(currentStepIndex + 1);
    }
  };

  const handleBack = () => {
    if (!isFirstStep) {
      setCurrentStepIndex(currentStepIndex - 1);
    }
  };

  const handleSkip = () => {
    if (onSkip) {
      onSkip(stepData);
    } else if (onComplete) {
      onComplete({ ...stepData, skipped: true });
    }
  };

  if (!currentStep) {
    return null;
  }

  const StepComponent = currentStep.component;

  return (
    <div className="onboarding-flow">
      <div className="onboarding-flow__container">
        <div className="onboarding-flow__progress">
          <div className="onboarding-flow__progress-bar">
            <div
              className="onboarding-flow__progress-fill"
              style={{
                width: `${((currentStepIndex + 1) / steps.length) * 100}%`
              }}
            />
          </div>
          <div className="onboarding-flow__step-counter">
            Step {currentStepIndex + 1} of {steps.length}
          </div>
        </div>

        <div className="onboarding-flow__content">
          <StepComponent
            appId={appId}
            data={stepData}
            onNext={handleNext}
            onBack={handleBack}
            isFirstStep={isFirstStep}
            isLastStep={isLastStep}
          />
        </div>

        {showSkip && !isLastStep && (
          <button
            className="onboarding-flow__skip"
            onClick={handleSkip}
            type="button"
          >
            Skip onboarding
          </button>
        )}
      </div>

      <style>{`
        .onboarding-flow {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--color-background);
          padding: 24px 16px;
        }

        .onboarding-flow__container {
          width: 100%;
          max-width: 600px;
        }

        .onboarding-flow__progress {
          margin-bottom: 32px;
        }

        .onboarding-flow__progress-bar {
          height: 4px;
          background: var(--color-border);
          border-radius: 2px;
          overflow: hidden;
          margin-bottom: 12px;
        }

        .onboarding-flow__progress-fill {
          height: 100%;
          background: var(--color-primary);
          transition: width 0.3s ease;
        }

        .onboarding-flow__step-counter {
          font-size: 14px;
          color: var(--color-text-secondary);
          text-align: center;
        }

        .onboarding-flow__content {
          background: var(--color-surface);
          border-radius: 16px;
          padding: 32px;
          box-shadow: var(--shadow-md);
        }

        .onboarding-flow__skip {
          display: block;
          margin: 24px auto 0;
          padding: 12px 24px;
          background: transparent;
          border: none;
          color: var(--color-text-secondary);
          font-size: 14px;
          cursor: pointer;
          text-decoration: underline;
          transition: color 0.2s ease;
        }

        .onboarding-flow__skip:hover {
          color: var(--color-text-primary);
        }

        @media (max-width: 768px) {
          .onboarding-flow {
            padding: 16px;
          }

          .onboarding-flow__content {
            padding: 24px 16px;
          }
        }
      `}</style>
    </div>
  );
}
