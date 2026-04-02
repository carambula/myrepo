/**
 * NotificationSettingsPage Component
 * Main notification settings page that routes to app-specific settings
 */

import { useState, useEffect } from 'react';
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

export function NotificationSettingsPage({
  appId,
  onManagePriorityPodcasts,
  onManagePriorityChannels,
  onSave
}) {
  const [preferences, setPreferences] = useState({});
  const [errors, setErrors] = useState({});
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');

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
    
    const success = updateNotificationPreference(appId, notificationType, updates);
    
    if (success && onSave) {
      onSave(updated);
    }
  };

  const renderAppSettings = () => {
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

  const getAppName = () => {
    switch (appId) {
      case APP_IDS.CYCLISMO:
        return 'Cyclismo Guide';
      case APP_IDS.PODLINK:
        return 'podlink';
      case APP_IDS.WATCHEDIT:
        return 'WatchedIt';
      case APP_IDS.YOURTUBE:
        return 'yourtube';
      default:
        return 'App';
    }
  };

  return (
    <div className="notification-settings-page">
      <div className="notification-settings-page__header">
        <h1 className="notification-settings-page__title">Notification Settings</h1>
        <p className="notification-settings-page__subtitle">
          Manage your {getAppName()} notification preferences
        </p>
      </div>

      <div className="notification-settings-page__content">
        {renderAppSettings()}
      </div>

      {saveMessage && (
        <div className={`notification-settings-page__message ${
          saveMessage.includes('Error') ? 'notification-settings-page__message--error' : ''
        }`}>
          {saveMessage}
        </div>
      )}

      <style>{`
        .notification-settings-page {
          max-width: 800px;
          margin: 0 auto;
          padding: 24px 16px;
        }

        .notification-settings-page__header {
          margin-bottom: 32px;
        }

        .notification-settings-page__title {
          font-size: 32px;
          font-weight: 700;
          color: var(--color-text-primary);
          margin: 0 0 8px 0;
        }

        .notification-settings-page__subtitle {
          font-size: 16px;
          color: var(--color-text-secondary);
          margin: 0;
        }

        .notification-settings-page__content {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .notification-settings-page__message {
          margin-top: 24px;
          padding: 12px 16px;
          border-radius: 8px;
          background-color: var(--color-success-bg);
          color: var(--color-success);
          font-size: 14px;
        }

        .notification-settings-page__message--error {
          background-color: var(--color-error-bg);
          color: var(--color-error);
        }

        @media (max-width: 768px) {
          .notification-settings-page {
            padding: 16px 12px;
          }

          .notification-settings-page__title {
            font-size: 24px;
          }
        }
      `}</style>
    </div>
  );
}
