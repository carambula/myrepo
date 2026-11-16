/**
 * Radii appearance setting
 * Scales rounded corners without affecting circular buttons and navigation.
 */

import React, { useEffect, useState } from 'react';
import {
  RADIUS_MODE_OPTIONS,
  RADIUS_SECTION_FOOTER,
  getRadiusMode,
  setRadiusMode,
} from '../appearance/radiusStyle.js';

export function RadiusSettings() {
  const [mode, setMode] = useState(getRadiusMode);

  useEffect(() => {
    setMode(getRadiusMode());
  }, []);

  const selected = RADIUS_MODE_OPTIONS.find((option) => option.id === mode) || RADIUS_MODE_OPTIONS[0];

  return (
    <div className="min-radius-settings">
      <div className="min-radius-settings-header">
        <h2>Radii</h2>
        <p className="min-radius-settings-description">{RADIUS_SECTION_FOOTER}</p>
      </div>

      <label className="min-radius-settings-label" htmlFor="min-radius-mode">
        Radii
      </label>
      <select
        id="min-radius-mode"
        className="min-radius-settings-select"
        value={mode}
        onChange={(event) => {
          const next = setRadiusMode(event.target.value);
          setMode(next);
        }}
      >
        {RADIUS_MODE_OPTIONS.map((option) => (
          <option key={option.id} value={option.id}>
            {option.label}
          </option>
        ))}
      </select>
      {selected?.description && (
        <p className="min-radius-settings-detail">{selected.description}</p>
      )}
    </div>
  );
}

export default RadiusSettings;
