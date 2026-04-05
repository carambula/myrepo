/**
 * Primary title inside AppLayout `main` — same type and spacing as WatchedIt (mov min).
 * Mirrors `MIN_MAIN_CONTENT_TITLE` / native `MinTitleTypography` (single source: `src/tokens/minTitles.js`).
 * Pass marginBottom={spacing[2]} when a subtitle sits directly under the title.
 */

import React from 'react';
import { MIN_MAIN_CONTENT_TITLE } from '../tokens/minTitles.js';

const baseTitleStyle = {
  marginTop: 0,
  marginLeft: 0,
  marginRight: 0,
  fontSize: `${MIN_MAIN_CONTENT_TITLE.fontSize}px`,
  fontWeight: MIN_MAIN_CONTENT_TITLE.fontWeight,
  lineHeight: MIN_MAIN_CONTENT_TITLE.lineHeight,
  letterSpacing: `${MIN_MAIN_CONTENT_TITLE.letterSpacing}px`,
  color: 'var(--color-text-primary)',
};

export function MainContentTitle({
  children,
  className = '',
  marginBottom = MIN_MAIN_CONTENT_TITLE.marginBottom,
  style,
  ...props
}) {
  return (
    <h1
      className={['min-main-content-title', className].filter(Boolean).join(' ')}
      style={{
        ...baseTitleStyle,
        marginBottom,
        ...style,
      }}
      {...props}
    >
      {children}
    </h1>
  );
}

export default MainContentTitle;
