/**
 * NotificationSettingsGroup Component
 * Groups notification settings with a title and collapsible content
 */

import { useState } from 'react';

export function NotificationSettingsGroup({
  title,
  description,
  children,
  defaultExpanded = true
}) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  return (
    <div className="notification-settings-group">
      <button
        className="notification-settings-group__header"
        onClick={() => setIsExpanded(!isExpanded)}
        aria-expanded={isExpanded}
      >
        <div className="notification-settings-group__header-content">
          <h3 className="notification-settings-group__title">{title}</h3>
          {description && (
            <p className="notification-settings-group__description">{description}</p>
          )}
        </div>
        <svg
          className={`notification-settings-group__icon ${
            isExpanded ? 'notification-settings-group__icon--expanded' : ''
          }`}
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="6 9 12 15 18 9"></polyline>
        </svg>
      </button>

      {isExpanded && (
        <div className="notification-settings-group__content">
          {children}
        </div>
      )}

      <style>{`
        .notification-settings-group {
          border: 1px solid var(--color-gray-200);
          border-radius: 12px;
          background-color: var(--color-background-primary);
          overflow: hidden;
        }

        .notification-settings-group__header {
          width: 100%;
          padding: 16px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          background: none;
          border: none;
          cursor: pointer;
          text-align: left;
          transition: background-color 0.2s ease;
        }

        .notification-settings-group__header:hover {
          background-color: var(--color-gray-50);
        }

        .notification-settings-group__header-content {
          flex: 1;
        }

        .notification-settings-group__title {
          font-size: 18px;
          font-weight: 600;
          color: var(--color-text-primary);
          margin: 0 0 4px 0;
        }

        .notification-settings-group__description {
          font-size: 14px;
          color: var(--color-text-secondary);
          margin: 0;
        }

        .notification-settings-group__icon {
          width: 24px;
          height: 24px;
          color: var(--color-text-secondary);
          transition: transform 0.2s ease;
          flex-shrink: 0;
        }

        .notification-settings-group__icon--expanded {
          transform: rotate(180deg);
        }

        .notification-settings-group__content {
          padding: 0 16px 16px 16px;
          display: flex;
          flex-direction: column;
          gap: 16px;
        }
      `}</style>
    </div>
  );
}
