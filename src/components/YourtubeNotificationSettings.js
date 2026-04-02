/**
 * YourtubeNotificationSettings Component
 * Notification settings specific to yourtube (vid min) app
 */

import { NotificationToggle } from './NotificationToggle.js';
import { TimePickerInput } from './TimePickerInput.js';
import { NumberInput } from './NumberInput.js';
import { NotificationSettingsGroup } from './NotificationSettingsGroup.js';

export function YourtubeNotificationSettings({
  preferences,
  onChange,
  errors = {},
  onManagePriorityChannels
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

  const priorityChannelCount = preferences.priority_channels?.priorityChannelIds?.length || 0;

  return (
    <div className="yourtube-notification-settings">
      <NotificationSettingsGroup
        title="Morning Queue Summary"
        description="Get a daily summary of your video queue"
      >
        <NotificationToggle
          enabled={preferences.morning_queue?.enabled}
          onChange={(enabled) => handleToggle('morning_queue', enabled)}
          label="Enable morning queue notifications"
          description="Receive a summary of new videos in your queue"
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
        title="Priority Channels"
        description="Get notified when specific channels upload new videos"
      >
        <NotificationToggle
          enabled={preferences.priority_channels?.enabled}
          onChange={(enabled) => handleToggle('priority_channels', enabled)}
          label="Enable priority channel notifications"
          description="Get instant notifications for your favorite channels"
        />
        
        {preferences.priority_channels?.enabled && (
          <>
            <NumberInput
              label="Check interval"
              value={preferences.priority_channels?.checkIntervalMinutes}
              onChange={(value) => handleNumberChange('priority_channels', 'checkIntervalMinutes', value)}
              min={15}
              max={360}
              suffix="minutes"
              error={errors.priority_channels?.checkIntervalMinutes}
            />
            
            <div className="priority-channels-manager">
              <div className="priority-channels-info">
                <span className="priority-channels-count">
                  {priorityChannelCount} priority channel{priorityChannelCount !== 1 ? 's' : ''}
                </span>
              </div>
              {onManagePriorityChannels && (
                <button
                  className="priority-channels-button"
                  onClick={onManagePriorityChannels}
                >
                  Manage Priority Channels
                </button>
              )}
            </div>
          </>
        )}
      </NotificationSettingsGroup>

      <style>{`
        .yourtube-notification-settings {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .priority-channels-manager {
          display: flex;
          flex-direction: column;
          gap: 12px;
          padding: 12px;
          background-color: var(--color-gray-50);
          border-radius: 8px;
        }

        .priority-channels-info {
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .priority-channels-count {
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-secondary);
        }

        .priority-channels-button {
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

        .priority-channels-button:hover {
          background-color: var(--color-primary-main);
          color: white;
        }
      `}</style>
    </div>
  );
}
