/**
 * Font Override Settings Component
 * Allows users to customize fonts for each tier of the typography ramp
 */

import React, { useState, useEffect } from 'react';
import {
  FONT_TIERS,
  ROTINA_WEIGHTS,
  getFontOverrideConfig,
  enableFontOverride,
  disableFontOverride,
  updateFontOverride,
} from '../appearance/fontOverride.js';

/**
 * Font tier selector component
 */
function FontTierSelector({ tier, label, description, selectedWeight, onChange }) {
  const weights = Object.values(ROTINA_WEIGHTS);

  return (
    <div className="min-font-tier-selector">
      <div className="min-font-tier-header">
        <label htmlFor={`font-tier-${tier}`} className="min-font-tier-label">
          {label}
        </label>
        {description && (
          <span className="min-font-tier-description">{description}</span>
        )}
      </div>
      <select
        id={`font-tier-${tier}`}
        className="min-font-tier-select"
        value={selectedWeight ? selectedWeight.weight : ''}
        onChange={(e) => {
          const weight = weights.find(w => w.weight === parseInt(e.target.value));
          onChange(tier, weight);
        }}
      >
        <option value="">Default (System Font)</option>
        {weights.map((weight) => (
          <option key={weight.weight} value={weight.weight}>
            Rotina {weight.name} ({weight.weight})
          </option>
        ))}
      </select>
      {selectedWeight && (
        <div
          className="min-font-preview"
          style={{
            fontFamily: "'Rotina', sans-serif",
            fontWeight: selectedWeight.weight,
          }}
        >
          The quick brown fox jumps over the lazy dog
        </div>
      )}
    </div>
  );
}

/**
 * Main font override settings component
 */
export function FontOverrideSettings() {
  const [config, setConfig] = useState(getFontOverrideConfig());
  const [enabled, setEnabled] = useState(config.enabled);

  useEffect(() => {
    // Load current configuration
    const currentConfig = getFontOverrideConfig();
    setConfig(currentConfig);
    setEnabled(currentConfig.enabled);
  }, []);

  const handleToggle = () => {
    if (enabled) {
      disableFontOverride();
      setEnabled(false);
    } else {
      enableFontOverride(config.fonts);
      setEnabled(true);
    }
  };

  const handleFontChange = (tier, weight) => {
    const updatedFonts = {
      ...config.fonts,
      [tier]: weight,
    };
    
    setConfig({ enabled, fonts: updatedFonts });
    
    if (enabled) {
      updateFontOverride({ [tier]: weight });
    }
  };

  const handleReset = () => {
    const defaultConfig = {
      enabled: true,
      fonts: {
        [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,
        [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,
        [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
        [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,
        [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,
      },
    };
    
    setConfig(defaultConfig);
    if (enabled) {
      enableFontOverride(defaultConfig.fonts);
    }
  };

  return (
    <div className="min-font-override-settings">
      <div className="min-font-override-header">
        <h2>Custom Font Override</h2>
        <p className="min-font-override-description">
          Customize the fonts used throughout the app by selecting from the Rotina font family.
          Each tier of the typography scale can use a different weight.
        </p>
      </div>

      <div className="min-font-override-toggle">
        <label htmlFor="font-override-enabled" className="min-toggle-label">
          <input
            type="checkbox"
            id="font-override-enabled"
            checked={enabled}
            onChange={handleToggle}
          />
          <span>Enable Custom Fonts</span>
        </label>
      </div>

      {enabled && (
        <>
          <div className="min-font-tiers">
            <FontTierSelector
              tier={FONT_TIERS.DISPLAY}
              label="Display"
              description="Large headings (H1, H2)"
              selectedWeight={config.fonts[FONT_TIERS.DISPLAY]}
              onChange={handleFontChange}
            />

            <FontTierSelector
              tier={FONT_TIERS.HEADING}
              label="Heading"
              description="Section headings (H3, H4, H5, H6)"
              selectedWeight={config.fonts[FONT_TIERS.HEADING]}
              onChange={handleFontChange}
            />

            <FontTierSelector
              tier={FONT_TIERS.BODY}
              label="Body"
              description="Paragraphs and body text"
              selectedWeight={config.fonts[FONT_TIERS.BODY]}
              onChange={handleFontChange}
            />

            <FontTierSelector
              tier={FONT_TIERS.UI}
              label="UI Elements"
              description="Buttons, labels, and controls"
              selectedWeight={config.fonts[FONT_TIERS.UI]}
              onChange={handleFontChange}
            />

            <FontTierSelector
              tier={FONT_TIERS.CAPTION}
              label="Caption"
              description="Small text and captions"
              selectedWeight={config.fonts[FONT_TIERS.CAPTION]}
              onChange={handleFontChange}
            />
          </div>

          <div className="min-font-override-actions">
            <button
              type="button"
              className="min-button min-button-secondary"
              onClick={handleReset}
            >
              Reset to Defaults
            </button>
          </div>
        </>
      )}

      <div className="min-font-override-note">
        <p>
          <strong>Note:</strong> Make sure the Rotina font files are installed in your app.
          See the documentation for instructions on copying the font files from the Nuform Redux app.
        </p>
      </div>
    </div>
  );
}

export default FontOverrideSettings;
