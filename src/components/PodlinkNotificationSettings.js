/**
 * PodlinkNotificationSettings Component
 * Notification settings specific to podlink app
 */

import { NotificationToggle } from './NotificationToggle.js';
import { TimePickerInput } from './TimePickerInput.js';
import { NumberInput } from './NumberInput.js';
import { NotificationSettingsGroup } from './NotificationSettingsGroup.js';

export function PodlinkNotificationSettings({
  preferences,
  onChange,
  errors = {},
  onManagePriorityPodcasts
}) {
  const handleToggle = (type, enabled) => {
    onChange(type, { enabled });
  };

  const handleTimeChange = (type, time) => {
    onChange(type, { time });
  };

  const handleNumberChange = (type, field, value) => {
    onChange(type, { [field]: value });
  };

  const handleCheckboxChange = (type, field, checked) => {
    onChange(type, { [field]: checked });
  };

  const priorityPodcastCount = preferences.priority_podcasts?.priorityPodcastIds?.length || 0;

  return (
    <div className="podlink-notification-settings">
      <NotificationSettingsGroup
        title="Morning Queue Summary"
        description="Get a daily summary of your podcast queue"
      >
        <NotificationToggle
          enabled={preferences.morning_queue?.enabled}
          onChange={(enabled) => handleToggle('morning_queue', enabled)}
          label="Enable morning queue notifications"
          description="Receive a summary of new episodes in your queue"
        />
        
        {preferences.morning_queue?.enabled && (
          <>
            <TimePickerInput
              label="Notification time"
              value={preferences.morning_queue?.time}
              onChange={(time) => handleTimeChange('morning_queue', time)}
              error={errors.morning_queue?.time}
            />
            
            <NotificationToggle
              enabled={preferences.morning_queue?.useAppleIntelligence}
              onChange={(checked) => handleCheckboxChange('morning_queue', 'useAppleIntelligence', checked)}
              label="Use Apple Intelligence"
              description="Generate smart summaries using Apple Intelligence"
            />
          </>
        )}
      </NotificationSettingsGroup>

      <NotificationSettingsGroup
        title="Priority Podcasts"
        description="Get notified when specific podcasts have new episodes"
      >
        <NotificationToggle
          enabled={preferences.priority_podcasts?.enabled}
          onChange={(enabled) => handleToggle('priority_podcasts', enabled)}
          label="Enable priority podcast notifications"
          description="Get instant notifications for your favorite podcasts"
        />
        
        {preferences.priority_podcasts?.enabled && (
          <>
            <NumberInput
              label="Check interval"
              value={preferences.priority_podcasts?.checkIntervalMinutes}
              onChange={(value) => handleNumberChange('priority_podcasts', 'checkIntervalMinutes', value)}
              min={15}
              max={360}
              suffix="minutes"
              error={errors.priority_podcasts?.checkIntervalMinutes}
            />
            
            <div className="priority-podcasts-manager">
              <div className="priority-podcasts-info">
                <span className="priority-podcasts-count">
                  {priorityPodcastCount} priority podcast{priorityPodcastCount !== 1 ? 's' : ''}
                </span>
              </div>
              {onManagePriorityPodcasts && (
                <button
                  className="priority-podcasts-button"
                  onClick={onManagePriorityPodcasts}
                >
                  Manage Priority Podcasts
                </button>
              )}
            </div>
          </>
        )}
      </NotificationSettingsGroup>

      <style>{`
        .podlink-notification-settings {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .priority-podcasts-manager {
          display: flex;
          flex-direction: column;
          gap: 12px;
          padding: 12px;
          background-color: var(--color-gray-50);
          border-radius: 8px;
        }

        .priority-podcasts-info {
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .priority-podcasts-count {
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-secondary);
        }

        .priority-podcasts-button {
          padding: 8px 16px;
          font-size: 14px;
          font-weight: 500;
          color: var(--color-primary-main);
          background: none;
          border: 1px solid var(--color-primary-main);
          border-radius: 8px;
          cursor: pointer;
          transition: all 0.2s ease;
        }

        .priority-podcasts-button:hover {
          background-color: var(--color-primary-main);
          color: white;
        }
      `}</style>
    </div>
  );
}
