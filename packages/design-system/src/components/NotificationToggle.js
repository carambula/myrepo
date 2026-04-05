/**
 * NotificationToggle Component
 * A toggle switch for enabling/disabling notifications
 */

export function NotificationToggle({ 
  enabled = false, 
  onChange,
  label,
  description,
  disabled = false 
}) {
  const handleChange = (e) => {
    if (onChange) {
      onChange(e.target.checked);
    }
  };

  return (
    <div className="notification-toggle">
      <label className="notification-toggle__container">
        <div className="notification-toggle__content">
          {label && <span className="notification-toggle__label">{label}</span>}
          {description && (
            <span className="notification-toggle__description">{description}</span>
          )}
        </div>
        <input
          type="checkbox"
          className="notification-toggle__input"
          checked={enabled}
          onChange={handleChange}
          disabled={disabled}
        />
        <span className="notification-toggle__switch"></span>
      </label>
      
      <style>{`
        .notification-toggle {
          width: 100%;
        }

        .notification-toggle__container {
          display: flex;
          align-items: center;
          justify-content: space-between;
          cursor: pointer;
          padding: 12px 0;
          gap: 16px;
        }

        .notification-toggle__container:hover .notification-toggle__switch {
          background-color: var(--color-gray-300);
        }

        .notification-toggle__content {
          flex: 1;
          display: flex;
          flex-direction: column;
          gap: 4px;
        }

        .notification-toggle__label {
          font-size: 16px;
          font-weight: 500;
          color: var(--color-text-primary);
        }

        .notification-toggle__description {
          font-size: 14px;
          color: var(--color-text-secondary);
        }

        .notification-toggle__input {
          position: absolute;
          opacity: 0;
          width: 0;
          height: 0;
        }

        .notification-toggle__switch {
          position: relative;
          width: 48px;
          height: 28px;
          background-color: var(--color-gray-300);
          border-radius: 14px;
          transition: background-color 0.2s ease;
          flex-shrink: 0;
        }

        .notification-toggle__switch::after {
          content: '';
          position: absolute;
          top: 2px;
          left: 2px;
          width: 24px;
          height: 24px;
          background-color: white;
          border-radius: 50%;
          transition: transform 0.2s ease;
        }

        .notification-toggle__input:checked + .notification-toggle__switch {
          background-color: var(--color-primary-main);
        }

        .notification-toggle__input:checked + .notification-toggle__switch::after {
          transform: translateX(20px);
        }

        .notification-toggle__input:disabled + .notification-toggle__switch {
          opacity: 0.5;
          cursor: not-allowed;
        }

        .notification-toggle__input:focus + .notification-toggle__switch {
          outline: 2px solid var(--color-primary-main);
          outline-offset: 2px;
        }
      `}</style>
    </div>
  );
}
