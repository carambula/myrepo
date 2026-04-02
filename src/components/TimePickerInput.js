/**
 * TimePickerInput Component
 * Input for selecting notification time in HH:MM format
 */

export function TimePickerInput({
  value = '08:00',
  onChange,
  label,
  error,
  disabled = false
}) {
  const handleChange = (e) => {
    if (onChange) {
      onChange(e.target.value);
    }
  };

  return (
    <div className="time-picker">
      {label && <label className="time-picker__label">{label}</label>}
      <input
        type="time"
        className={`time-picker__input ${error ? 'time-picker__input--error' : ''}`}
        value={value}
        onChange={handleChange}
        disabled={disabled}
      />
      {error && <span className="time-picker__error">{error}</span>}
      
      <style>{`
        .time-picker {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .time-picker__label {
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-primary);
        }

        .time-picker__input {
          padding: 10px 12px;
          font-size: 16px;
          border: 1px solid var(--color-gray-300);
          border-radius: 8px;
          background-color: var(--color-background-primary);
          color: var(--color-text-primary);
          transition: border-color 0.2s ease;
        }

        .time-picker__input:hover:not(:disabled) {
          border-color: var(--color-gray-400);
        }

        .time-picker__input:focus {
          outline: none;
          border-color: var(--color-primary-main);
          box-shadow: 0 0 0 3px var(--color-primary-alpha-10);
        }

        .time-picker__input:disabled {
          opacity: 0.5;
          cursor: not-allowed;
          background-color: var(--color-gray-50);
        }

        .time-picker__input--error {
          border-color: var(--color-error);
        }

        .time-picker__input--error:focus {
          border-color: var(--color-error);
          box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
        }

        .time-picker__error {
          font-size: 14px;
          color: var(--color-error);
        }
      `}</style>
    </div>
  );
}
