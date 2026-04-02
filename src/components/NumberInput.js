/**
 * NumberInput Component
 * Input for numeric values with validation
 */

export function NumberInput({
  value,
  onChange,
  label,
  min,
  max,
  step = 1,
  suffix,
  error,
  disabled = false
}) {
  const handleChange = (e) => {
    const numValue = parseFloat(e.target.value);
    if (onChange && !isNaN(numValue)) {
      onChange(numValue);
    }
  };

  return (
    <div className="number-input">
      {label && <label className="number-input__label">{label}</label>}
      <div className="number-input__wrapper">
        <input
          type="number"
          className={`number-input__input ${error ? 'number-input__input--error' : ''}`}
          value={value}
          onChange={handleChange}
          min={min}
          max={max}
          step={step}
          disabled={disabled}
        />
        {suffix && <span className="number-input__suffix">{suffix}</span>}
      </div>
      {error && <span className="number-input__error">{error}</span>}
      
      <style>{`
        .number-input {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .number-input__label {
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-primary);
        }

        .number-input__wrapper {
          position: relative;
          display: flex;
          align-items: center;
        }

        .number-input__input {
          flex: 1;
          padding: 10px 12px;
          font-size: 16px;
          border: 1px solid var(--color-gray-300);
          border-radius: 8px;
          background-color: var(--color-background-primary);
          color: var(--color-text-primary);
          transition: border-color 0.2s ease;
        }

        .number-input__input:hover:not(:disabled) {
          border-color: var(--color-gray-400);
        }

        .number-input__input:focus {
          outline: none;
          border-color: var(--color-primary-main);
          box-shadow: 0 0 0 3px var(--color-primary-alpha-10);
        }

        .number-input__input:disabled {
          opacity: 0.5;
          cursor: not-allowed;
          background-color: var(--color-gray-50);
        }

        .number-input__input--error {
          border-color: var(--color-error);
        }

        .number-input__input--error:focus {
          border-color: var(--color-error);
          box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
        }

        .number-input__suffix {
          position: absolute;
          right: 12px;
          font-size: 14px;
          color: var(--color-text-secondary);
          pointer-events: none;
        }

        .number-input__error {
          font-size: 14px;
          color: var(--color-error);
        }
      `}</style>
    </div>
  );
}
