/**
 * OnboardingNotificationStep Component
 * Onboarding step for configuring notification preferences
 */

import { useState, useEffect } from 'react';
import { OnboardingStep } from './OnboardingStep.js';
import { CyclismoNotificationSettings } from './CyclismoNotificationSettings.js';
import { PodlinkNotificationSettings } from './PodlinkNotificationSettings.js';
import { WatcheditNotificationSettings } from './WatcheditNotificationSettings.js';
import { YourtubeNotificationSettings } from './YourtubeNotificationSettings.js';
import {
  loadNotificationPreferences,
  updateNotificationPreference,
  validatePreferences
} from '../notifications/notificationPreferences.js';
import { APP_IDS } from '../notifications/notificationTypes.js';

export function OnboardingNotificationStep({
  appId,
  onNext,
  onBack,
  isFirstStep,
  isLastStep,
  title,
  description,
  onManagePriorityPodcasts,
  onManagePriorityChannels
}) {
  const [preferences, setPreferences] = useState({});
  const [errors, setErrors] = useState({});

  useEffect(() => {
    const loaded = loadNotificationPreferences(appId);
    setPreferences(loaded);
  }, [appId]);

  const handleChange = (notificationType, updates) => {
    const updated = {
      ...preferences,
      [notificationType]: {
        ...preferences[notificationType],
        ...updates
      }
    };
    
    setPreferences(updated);
    
    const validation = validatePreferences(appId, updated);
    setErrors(validation.errors);
    
    updateNotificationPreference(appId, notificationType, updates);
  };

  const handleNext = () => {
    const validation = validatePreferences(appId, preferences);
    if (validation.isValid && onNext) {
      onNext({ notificationPreferences: preferences });
    }
  };

  const renderNotificationSettings = () => {
    const commonProps = {
      preferences,
      onChange: handleChange,
      errors
    };

    switch (appId) {
      case APP_IDS.CYCLISMO:
        return <CyclismoNotificationSettings {...commonProps} />;
      
      case APP_IDS.PODLINK:
        return (
          <PodlinkNotificationSettings
            {...commonProps}
            onManagePriorityPodcasts={onManagePriorityPodcasts}
          />
        );
      
      case APP_IDS.WATCHEDIT:
        return <WatcheditNotificationSettings {...commonProps} />;
      
      case APP_IDS.YOURTUBE:
        return (
          <YourtubeNotificationSettings
            {...commonProps}
            onManagePriorityChannels={onManagePriorityChannels}
          />
        );
      
      default:
        return <div>Unknown app</div>;
    }
  };

  const getDefaultTitle = () => {
    switch (appId) {
      case APP_IDS.CYCLISMO:
        return 'Stay Updated on Races';
      case APP_IDS.PODLINK:
        return 'Never Miss an Episode';
      case APP_IDS.WATCHEDIT:
        return 'Get Notified About New Episodes';
      case APP_IDS.YOURTUBE:
        return 'Stay on Top of Your Queue';
      default:
        return 'Notification Settings';
    }
  };

  const getDefaultDescription = () => {
    switch (appId) {
      case APP_IDS.CYCLISMO:
        return 'Get notified about upcoming races, stream starts, and post-race content. You can customize these settings anytime.';
      case APP_IDS.PODLINK:
        return 'Set up notifications for your podcast queue and priority shows. You can change these settings later.';
      case APP_IDS.WATCHEDIT:
        return 'Get daily notifications about new episodes from your podcasts. Customize when you want to be notified.';
      case APP_IDS.YOURTUBE:
        return 'Set up notifications for your video queue and priority channels. You can adjust these settings anytime.';
      default:
        return 'Configure your notification preferences.';
    }
  };

  return (
    <OnboardingStep
      title={title || getDefaultTitle()}
      description={description || getDefaultDescription()}
      icon="🔔"
      onNext={handleNext}
      onBack={onBack}
      isFirstStep={isFirstStep}
      isLastStep={isLastStep}
    >
      <div className="onboarding-notification-step__settings">
        {renderNotificationSettings()}
      </div>

      <style>{`
        .onboarding-notification-step__settings {
          text-align: left;
          margin: 0 auto;
          max-width: 100%;
        }
      `}</style>
    </OnboardingStep>
  );
}
