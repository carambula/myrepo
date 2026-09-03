/**
 * Onboarding Step Configurations
 * Pre-configured onboarding flows for each min app
 */

import { OnboardingStep } from '../components/OnboardingStep.js';
import { OnboardingNotificationStep } from '../components/OnboardingNotificationStep.js';
import { APP_IDS } from '../notifications/notificationTypes.js';

/**
 * Welcome step component
 */
function WelcomeStep({ appId, onNext, onBack, isFirstStep, isLastStep }) {
  const getAppInfo = () => {
    switch (appId) {
      case APP_IDS.CYCLISMO:
        return {
          title: 'Welcome to Cyclismo Guide',
          description: 'Your complete companion for following professional cycling races, streams, and post-race content.',
          icon: '🚴'
        };
      case APP_IDS.PODLINK:
        return {
          title: 'Welcome to podlink',
          description: 'The minimal podcast app that keeps you connected to your favorite shows.',
          icon: '🎙️'
        };
      case APP_IDS.WATCHEDIT:
        return {
          title: 'Welcome to WatchedIt',
          description: 'Track your favorite podcasts and never miss a new episode.',
          icon: '🎬'
        };
      case APP_IDS.YOURTUBE:
        return {
          title: 'Welcome to yourtube',
          description: 'Your minimal video companion for managing your YouTube queue and favorite channels.',
          icon: '📺'
        };
      default:
        return {
          title: 'Welcome',
          description: 'Let\'s get started.',
          icon: '👋'
        };
    }
  };

  const info = getAppInfo();

  return (
    <OnboardingStep
      title={info.title}
      description={info.description}
      icon={info.icon}
      onNext={onNext}
      onBack={onBack}
      isFirstStep={isFirstStep}
      isLastStep={isLastStep}
      nextLabel="Let's go"
    />
  );
}

/**
 * Features step component
 */
function FeaturesStep({ appId, onNext, onBack, isFirstStep, isLastStep }) {
  const getFeatures = () => {
    switch (appId) {
      case APP_IDS.CYCLISMO:
        return {
          title: 'Everything You Need',
          description: 'Cyclismo Guide helps you stay on top of the racing season.',
          icon: '✨',
          features: [
            '🏁 Race schedules and stream links',
            '📺 Live stream notifications',
            '🎙️ Post-race podcasts and replays',
            '💾 Save your favorite races'
          ]
        };
      case APP_IDS.PODLINK:
        return {
          title: 'Your Podcast Hub',
          description: 'Everything you need to stay connected with your shows.',
          icon: '✨',
          features: [
            '📻 Daily queue summaries',
            '⭐ Priority podcast alerts',
            '🤖 Apple Intelligence summaries',
            '🔔 Custom notification schedules'
          ]
        };
      case APP_IDS.WATCHEDIT:
        return {
          title: 'Stay Updated',
          description: 'Never miss new content from your favorite podcasts.',
          icon: '✨',
          features: [
            '🆕 Daily new episode checks',
            '📅 Customizable notification times',
            '📝 Episode tracking',
            '🎧 Quick access to your queue'
          ]
        };
      case APP_IDS.YOURTUBE:
        return {
          title: 'Your Video Command Center',
          description: 'Manage your YouTube queue with ease.',
          icon: '✨',
          features: [
            '📺 Daily queue summaries',
            '⭐ Priority channel alerts',
            '🤖 Apple Intelligence summaries',
            '🔔 Custom notification schedules'
          ]
        };
      default:
        return {
          title: 'Features',
          description: 'Discover what you can do.',
          icon: '✨',
          features: []
        };
    }
  };

  const info = getFeatures();

  return (
    <OnboardingStep
      title={info.title}
      description={info.description}
      icon={info.icon}
      onNext={onNext}
      onBack={onBack}
      isFirstStep={isFirstStep}
      isLastStep={isLastStep}
    >
      <ul className="features-list">
        {info.features.map((feature, index) => (
          <li key={index} className="features-list__item">
            {feature}
          </li>
        ))}
      </ul>

      <style>{`
        .features-list {
          list-style: none;
          padding: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .features-list__item {
          font-size: 16px;
          line-height: 1.5;
          color: var(--color-text-primary);
          padding: 16px;
          background: var(--color-background);
          border-radius: 8px;
          text-align: left;
        }

        @media (max-width: 768px) {
          .features-list__item {
            font-size: 14px;
            padding: 12px;
          }
        }
      `}</style>
    </OnboardingStep>
  );
}

/**
 * Get default onboarding steps for an app
 */
export function getDefaultOnboardingSteps(appId) {
  return [
    {
      id: 'welcome',
      component: WelcomeStep
    },
    {
      id: 'features',
      component: FeaturesStep
    },
    {
      id: 'notifications',
      component: OnboardingNotificationStep
    }
  ];
}

/**
 * Get custom onboarding steps (allows apps to customize)
 */
export function createOnboardingSteps(appId, customSteps = null) {
  if (customSteps) {
    return customSteps;
  }
  return getDefaultOnboardingSteps(appId);
}
