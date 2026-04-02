/**
 * OnboardingStep Component
 * Generic onboarding step with title, description, and navigation
 */

export function OnboardingStep({
  title,
  description,
  icon,
  children,
  onNext,
  onBack,
  isFirstStep,
  isLastStep,
  nextLabel = 'Continue',
  backLabel = 'Back',
  showNext = true,
  showBack = true
}) {
  const handleNext = () => {
    if (onNext) {
      onNext();
    }
  };

  const handleBack = () => {
    if (onBack) {
      onBack();
    }
  };

  return (
    <div className="onboarding-step">
      {icon && (
        <div className="onboarding-step__icon">
          {icon}
        </div>
      )}

      <h2 className="onboarding-step__title">{title}</h2>
      
      {description && (
        <p className="onboarding-step__description">{description}</p>
      )}

      <div className="onboarding-step__content">
        {children}
      </div>

      <div className="onboarding-step__actions">
        {showBack && !isFirstStep && (
          <button
            className="onboarding-step__button onboarding-step__button--secondary"
            onClick={handleBack}
            type="button"
          >
            {backLabel}
          </button>
        )}
        
        {showNext && (
          <button
            className="onboarding-step__button onboarding-step__button--primary"
            onClick={handleNext}
            type="button"
          >
            {isLastStep ? 'Get Started' : nextLabel}
          </button>
        )}
      </div>

      <style>{`
        .onboarding-step {
          display: flex;
          flex-direction: column;
          align-items: center;
          text-align: center;
        }

        .onboarding-step__icon {
          margin-bottom: 24px;
          font-size: 48px;
        }

        .onboarding-step__title {
          font-size: 28px;
          font-weight: 700;
          color: var(--color-text-primary);
          margin: 0 0 12px 0;
        }

        .onboarding-step__description {
          font-size: 16px;
          line-height: 1.5;
          color: var(--color-text-secondary);
          margin: 0 0 32px 0;
          max-width: 480px;
        }

        .onboarding-step__content {
          width: 100%;
          margin-bottom: 32px;
        }

        .onboarding-step__actions {
          display: flex;
          gap: 12px;
          width: 100%;
          justify-content: center;
        }

        .onboarding-step__button {
          padding: 14px 32px;
          font-size: 16px;
          font-weight: 600;
          border-radius: 8px;
          border: none;
          cursor: pointer;
          transition: all 0.2s ease;
          min-width: 120px;
        }

        .onboarding-step__button--primary {
          background: var(--color-primary);
          color: var(--color-text-on-primary);
        }

        .onboarding-step__button--primary:hover {
          background: var(--color-primary-dark);
          transform: translateY(-1px);
          box-shadow: var(--shadow-sm);
        }

        .onboarding-step__button--primary:active {
          transform: translateY(0);
        }

        .onboarding-step__button--secondary {
          background: transparent;
          color: var(--color-text-secondary);
          border: 1px solid var(--color-border);
        }

        .onboarding-step__button--secondary:hover {
          background: var(--color-surface-hover);
          color: var(--color-text-primary);
        }

        @media (max-width: 768px) {
          .onboarding-step__title {
            font-size: 24px;
          }

          .onboarding-step__description {
            font-size: 14px;
          }

          .onboarding-step__actions {
            flex-direction: column-reverse;
          }

          .onboarding-step__button {
            width: 100%;
          }
        }
      `}</style>
    </div>
  );
}
