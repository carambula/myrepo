/**
 * Loading and empty (null) content states
 * Left-aligned, minimal chrome — see docs/visual-specification.md
 */

import { MAIN_LOADING_MESSAGE } from '../tokens/mainLoading.js';

/** Canonical class list for main bootstrap loading (WatchedIt / mov min); all min apps must match. @see docs/main-app-loading.md */
export const MAIN_APP_LOADING_CLASSNAME =
  'min-content-status min-content-status--loading min-content-status--main';

/**
 * Inline loading row: small CSS spinner + label (requires global.css).
 * @param {boolean} [main=false] - Set true for root bootstrap loading (same as mov min — see docs/main-app-loading.md).
 */
export function LoadingState({ message = MAIN_LOADING_MESSAGE, className = '', main = false, ...props }) {
  const baseClass = main ? MAIN_APP_LOADING_CLASSNAME : 'min-content-status min-content-status--loading';
  return {
    element: 'div',
    className: `${baseClass} ${className}`.trim(),
    role: 'status',
    'aria-live': 'polite',
    children: [
      {
        element: 'span',
        className: 'min-content-status__spinner',
        'aria-hidden': 'true',
      },
      {
        element: 'span',
        className: 'min-content-status__label',
        children: message,
      },
    ],
    ...props,
  };
}

/**
 * Empty / no-data message (no decorative icons).
 * @param {boolean} [main=false] - Set true when this is the primary full-view empty state.
 */
export function EmptyState({ message, className = '', main = false, ...props }) {
  const mainClass = main ? 'min-content-status--main' : '';
  return {
    element: 'div',
    className: `min-content-status min-content-status--empty ${mainClass} ${className}`.trim(),
    children: {
      element: 'p',
      className: 'min-content-status__message',
      children: message,
    },
    ...props,
  };
}

export default { LoadingState, EmptyState };
