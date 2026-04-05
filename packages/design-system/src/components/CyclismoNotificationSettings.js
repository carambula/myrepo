/**
 * CyclismoNotificationSettings Component
 * Notification settings specific to Cyclismo guide app
 */

import { NotificationToggle } from './NotificationToggle.js';
import { TimePickerInput } from './TimePickerInput.js';
import { NumberInput } from './NumberInput.js';
import { NotificationSettingsGroup } from './NotificationSettingsGroup.js';

export function CyclismoNotificationSettings({
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

  const handleNumberChange = (type, field, value) => {
    onChange(type, { [field]: value });
  };

  const handleCheckboxChange = (type, field, checked) => {
    onChange(type, { [field]: checked });
  };

  return (
    <div className="cyclismo-notification-settings">
      <NotificationSettingsGroup
        title="Morning Race Notification"
        description="Get notified in the morning if there are races today"
      >
        <NotificationToggle
          enabled={preferences.morning_races?.enabled}
          onChange={(enabled) => handleToggle('morning_races', enabled)}
          label="Enable morning notifications"
          description="Receive a summary of today's races, times, and streamers"
        />
        
        {preferences.morning_races?.enabled && (
          <TimePickerInput
            label="Notification time"
            value={preferences.morning_races?.time}
            onChange={(time) => handleTimeChange('morning_races', time)}
            error={errors.morning_races?.time}
          />
        )}
      </NotificationSettingsGroup>

      <NotificationSettingsGroup
        title="Recap Notification"
        description="Get a recap after races conclude"
      >
        <NotificationToggle
          enabled={preferences.recap?.enabled}
          onChange={(enabled) => handleToggle('recap', enabled)}
          label="Enable recap notifications"
          description="Receive podcasts and replays after the last race"
        />
        
        {preferences.recap?.enabled && (
          <NumberInput
            label="Hours after last race"
            value={preferences.recap?.hoursAfterLastRace}
            onChange={(value) => handleNumberChange('recap', 'hoursAfterLastRace', value)}
            min={1}
            max={12}
            suffix="hours"
            error={errors.recap?.hoursAfterLastRace}
          />
        )}
      </NotificationSettingsGroup>

      <NotificationSettingsGroup
        title="Stream Start Notifications"
        description="Get notified before races start streaming"
      >
        <NotificationToggle
          enabled={preferences.stream_start?.enabled}
          onChange={(enabled) => handleToggle('stream_start', enabled)}
          label="Enable stream start notifications"
          description="Get reminded before each race stream begins"
        />
        
        {preferences.stream_start?.enabled && (
          <>
            <NumberInput
              label="Notify before stream"
              value={preferences.stream_start?.minutesBefore}
              onChange={(value) => handleNumberChange('stream_start', 'minutesBefore', value)}
              min={5}
              max={60}
              suffix="minutes"
              error={errors.stream_start?.minutesBefore}
            />
            
            <NotificationToggle
              enabled={preferences.stream_start?.onlySavedRaces}
              onChange={(checked) => handleCheckboxChange('stream_start', 'onlySavedRaces', checked)}
              label="Only saved races"
              description="Only notify for races you've saved"
            />
          </>
        )}
      </NotificationSettingsGroup>

      <style>{`
        .cyclismo-notification-settings {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }
      `}</style>
    </div>
  );
}
