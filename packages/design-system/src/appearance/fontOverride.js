/**
 * Font Override System
 * Allows users to override theme fonts with custom fonts from the Rotina family
 */

import { typography } from '../tokens/typography.js';

/**
 * Font tiers that can be customized
 * Maps to the typography font ramp
 */
export const FONT_TIERS = {
  DISPLAY: 'display',        // Used for h1, h2 - largest headings
  HEADING: 'heading',        // Used for h3, h4, h5, h6 - section headings
  BODY: 'body',             // Used for body text, paragraphs
  UI: 'ui',                 // Used for buttons, labels, UI elements
  CAPTION: 'caption',       // Used for captions, small text
  MONO: 'mono',             // Used for code, monospace text
};

/**
 * Available Rotina font weights
 */
export const ROTINA_WEIGHTS = {
  EXTRA_THIN: { name: 'ExtraThin', weight: 200 },
  THIN: { name: 'Thin', weight: 250 },
  EXTRA_LIGHT: { name: 'ExtraLight', weight: 275 },
  LIGHT: { name: 'Light', weight: 300 },
  REGULAR: { name: 'Regular', weight: 400 },
  MEDIUM: { name: 'Medium', weight: 500 },
  BOLD: { name: 'Bold', weight: 700 },
  EXTRA_BOLD: { name: 'ExtraBold', weight: 800 },
};

/**
 * Default font override configuration
 * Maps font tiers to specific Rotina weights
 */
export const DEFAULT_FONT_OVERRIDE = {
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.MEDIUM,
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,
  [FONT_TIERS.MONO]: null, // Don't override monospace font
};

/**
 * Maps typography styles to font tiers
 */
const STYLE_TO_TIER_MAP = {
  h1: FONT_TIERS.DISPLAY,
  h2: FONT_TIERS.DISPLAY,
  h3: FONT_TIERS.HEADING,
  h4: FONT_TIERS.HEADING,
  h5: FONT_TIERS.HEADING,
  h6: FONT_TIERS.HEADING,
  body: FONT_TIERS.BODY,
  bodyLarge: FONT_TIERS.BODY,
  bodySmall: FONT_TIERS.BODY,
  button: FONT_TIERS.UI,
  label: FONT_TIERS.UI,
  overline: FONT_TIERS.UI,
  caption: FONT_TIERS.CAPTION,
};

/**
 * Storage key for font override preferences
 */
const STORAGE_KEY = 'min-apps-font-override';

/**
 * Gets the saved font override configuration
 */
export function getSavedFontOverride() {
  if (typeof localStorage === 'undefined') {
    return null;
  }

  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : null;
  } catch (error) {
    console.error('Error loading font override preferences:', error);
    return null;
  }
}

/**
 * Saves the font override configuration
 */
export function saveFontOverride(config) {
  if (typeof localStorage === 'undefined') {
    return false;
  }

  try {
    if (config === null) {
      localStorage.removeItem(STORAGE_KEY);
    } else {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
    }
    return true;
  } catch (error) {
    console.error('Error saving font override preferences:', error);
    return false;
  }
}

/**
 * Checks if font override is enabled
 */
export function isFontOverrideEnabled() {
  const config = getSavedFontOverride();
  return config !== null && config.enabled === true;
}

/**
 * Generates font-family CSS value with Rotina and fallbacks
 */
function generateFontFamily(rotinaWeight, fallback) {
  if (!rotinaWeight) {
    return fallback;
  }
  
  // Include Rotina with system fallbacks
  return `'Rotina', ${fallback}`;
}

/**
 * Applies font override to the document
 */
export function applyFontOverride(config = null) {
  const root = document.documentElement;
  
  // If no config provided, try to load from storage
  if (config === null) {
    config = getSavedFontOverride();
  }
  
  // If still no config or disabled, remove overrides
  if (!config || !config.enabled) {
    removeFontOverride();
    return;
  }
  
  // Merge with defaults
  const fontConfig = { ...DEFAULT_FONT_OVERRIDE, ...config.fonts };
  
  // Apply CSS custom properties for each tier
  if (fontConfig[FONT_TIERS.DISPLAY]) {
    root.style.setProperty(
      '--font-display',
      generateFontFamily(fontConfig[FONT_TIERS.DISPLAY], typography.fonts.primary)
    );
    root.style.setProperty('--font-weight-display', fontConfig[FONT_TIERS.DISPLAY].weight);
  }
  
  if (fontConfig[FONT_TIERS.HEADING]) {
    root.style.setProperty(
      '--font-heading',
      generateFontFamily(fontConfig[FONT_TIERS.HEADING], typography.fonts.primary)
    );
    root.style.setProperty('--font-weight-heading', fontConfig[FONT_TIERS.HEADING].weight);
  }
  
  if (fontConfig[FONT_TIERS.BODY]) {
    root.style.setProperty(
      '--font-body',
      generateFontFamily(fontConfig[FONT_TIERS.BODY], typography.fonts.primary)
    );
    root.style.setProperty('--font-weight-body', fontConfig[FONT_TIERS.BODY].weight);
  }
  
  if (fontConfig[FONT_TIERS.UI]) {
    root.style.setProperty(
      '--font-ui',
      generateFontFamily(fontConfig[FONT_TIERS.UI], typography.fonts.primary)
    );
    root.style.setProperty('--font-weight-ui', fontConfig[FONT_TIERS.UI].weight);
  }
  
  if (fontConfig[FONT_TIERS.CAPTION]) {
    root.style.setProperty(
      '--font-caption',
      generateFontFamily(fontConfig[FONT_TIERS.CAPTION], typography.fonts.primary)
    );
    root.style.setProperty('--font-weight-caption', fontConfig[FONT_TIERS.CAPTION].weight);
  }
  
  // Set data attribute to indicate font override is active
  root.setAttribute('data-font-override', 'true');
  
  // Load Rotina font CSS if not already loaded
  loadRotinaFonts();
}

/**
 * Removes font override and restores default fonts
 */
export function removeFontOverride() {
  const root = document.documentElement;
  
  // Remove CSS custom properties
  root.style.removeProperty('--font-display');
  root.style.removeProperty('--font-weight-display');
  root.style.removeProperty('--font-heading');
  root.style.removeProperty('--font-weight-heading');
  root.style.removeProperty('--font-body');
  root.style.removeProperty('--font-weight-body');
  root.style.removeProperty('--font-ui');
  root.style.removeProperty('--font-weight-ui');
  root.style.removeProperty('--font-caption');
  root.style.removeProperty('--font-weight-caption');
  
  // Remove data attribute
  root.removeAttribute('data-font-override');
}

/**
 * Loads Rotina font CSS file
 */
function loadRotinaFonts() {
  // Check if already loaded
  if (document.getElementById('rotina-fonts')) {
    return;
  }
  
  // Create and append link element
  const link = document.createElement('link');
  link.id = 'rotina-fonts';
  link.rel = 'stylesheet';
  link.href = new URL('../assets/fonts/rotina/rotina.css', import.meta.url).href;
  document.head.appendChild(link);
}

/**
 * Initialize font override on page load
 */
export function initFontOverride() {
  const config = getSavedFontOverride();
  if (config && config.enabled) {
    applyFontOverride(config);
  }
}

/**
 * Creates a new font override configuration
 */
export function createFontOverrideConfig(fonts = {}) {
  return {
    enabled: true,
    fonts: { ...DEFAULT_FONT_OVERRIDE, ...fonts },
  };
}

/**
 * Disables font override
 */
export function disableFontOverride() {
  saveFontOverride({ enabled: false });
  removeFontOverride();
}

/**
 * Enables font override with optional custom configuration
 */
export function enableFontOverride(fonts = {}) {
  const config = createFontOverrideConfig(fonts);
  saveFontOverride(config);
  applyFontOverride(config);
}

/**
 * Updates font override configuration
 */
export function updateFontOverride(fonts) {
  const current = getSavedFontOverride() || createFontOverrideConfig();
  const updated = {
    ...current,
    fonts: { ...current.fonts, ...fonts },
  };
  saveFontOverride(updated);
  applyFontOverride(updated);
}

/**
 * Gets the current font override configuration
 */
export function getFontOverrideConfig() {
  return getSavedFontOverride() || { enabled: false, fonts: DEFAULT_FONT_OVERRIDE };
}

export default {
  FONT_TIERS,
  ROTINA_WEIGHTS,
  DEFAULT_FONT_OVERRIDE,
  getSavedFontOverride,
  saveFontOverride,
  isFontOverrideEnabled,
  applyFontOverride,
  removeFontOverride,
  initFontOverride,
  createFontOverrideConfig,
  disableFontOverride,
  enableFontOverride,
  updateFontOverride,
  getFontOverrideConfig,
};
