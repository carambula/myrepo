/**
 * WatcheditNotificationSettings Component
 * Notification settings specific to WatchedIt (mov min) app
 */

import { NotificationToggle } from './NotificationToggle.js';
import { TimePickerInput } from './TimePickerInput.js';
import { NotificationSettingsGroup } from './NotificationSettingsGroup.js';

export function WatcheditNotificationSettings({
  preferences,
  onChange,
  errors = {}
}) {
  const handleToggle = (type, enabled) => {
    onChange(type, { enabled });
  };

  const handleTimeChange = (type, time) => {
    onChange(type, { time });
  };

  return (
    <div className="watchedit-notification-settings">
      <NotificationSettingsGroup
        title="New Episodes"
        description="Get notified about new podcast episodes"
      >
        <NotificationToggle
          enabled={preferences.new_episodes?.enabled}
          onChange={(enabled) => handleToggle('new_episodes', enabled)}
          label="Enable new episode notifications"
          description="Check daily for new episodes from your podcasts"
        />
        
        {preferences.new_episodes?.enabled && (
          <TimePickerInput
            label="Check time"
            value={preferences.new_episodes?.time}
            onChange={(time) => handleTimeChange('new_episodes', time)}
            error={errors.new_episodes?.time}
          />
        )}
      </NotificationSettingsGroup>

      <style>{`
        .watchedit-notification-settings {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }
      `}</style>
    </div>
  );
}
