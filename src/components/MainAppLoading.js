/**
 * Canonical main bootstrap loader (WatchedIt / mov min). Use in React apps so vid min and others cannot drift.
 * @see docs/main-app-loading.md
 */

import React from 'react';
import { MAIN_APP_LOADING_CLASSNAME } from './ContentStatus.js';
import { MAIN_LOADING_MESSAGE } from '../tokens/mainLoading.js';

export function MainAppLoading({ message = MAIN_LOADING_MESSAGE, className = '', ...props }) {
  return (
    <div
      className={[MAIN_APP_LOADING_CLASSNAME, className].filter(Boolean).join(' ')}
      role="status"
      aria-live="polite"
      {...props}
    >
      <span className="min-content-status__spinner" aria-hidden="true" />
      <span className="min-content-status__label">{message}</span>
    </div>
  );
}

export default MainAppLoading;
