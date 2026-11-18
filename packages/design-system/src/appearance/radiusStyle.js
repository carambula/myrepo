/**
 * Corner radius preference for min apps.
 *
 * Default keeps current radii. Reduced 1/2/3 slide each radius down the ramp
 * and clamp at the smallest ramp radius (never 0). Universal 3/2/1/0 set every
 * rounded corner to that ramp point (0 is square). Circular / pill radii
 * (buttons, navigation, `full` / `round`) are not remapped.
 */

export const RADIUS_RAMP = Object.freeze([4, 8, 12, 16, 20]);

/** Radii at or above this are treated as circular / pill and are not remapped. */
export const RADIUS_CIRCULAR_THRESHOLD = 50;

export const RADIUS_MODES = Object.freeze({
  DEFAULT: 'default',
  REDUCED_1: 'reduced1',
  REDUCED_2: 'reduced2',
  REDUCED_3: 'reduced3',
  UNIVERSAL_3: 'universal3',
  UNIVERSAL_2: 'universal2',
  UNIVERSAL_1: 'universal1',
  UNIVERSAL_0: 'universal0',
});

export const RADIUS_MODE_OPTIONS = Object.freeze([
  {
    id: RADIUS_MODES.DEFAULT,
    label: 'Default',
    description: 'Current corner radii across the app.',
  },
  {
    id: RADIUS_MODES.REDUCED_1,
    label: 'Reduced 1',
    description: 'Each corner is one step smaller on the radius ramp, not below the smallest ramp radius.',
  },
  {
    id: RADIUS_MODES.REDUCED_2,
    label: 'Reduced 2',
    description: 'Each corner is two steps smaller on the radius ramp, not below the smallest ramp radius.',
  },
  {
    id: RADIUS_MODES.REDUCED_3,
    label: 'Reduced 3',
    description: 'Each corner is three steps smaller on the radius ramp, not below the smallest ramp radius.',
  },
  {
    id: RADIUS_MODES.UNIVERSAL_3,
    label: 'Universal 3',
    description: 'Every rounded corner uses the third ramp radius (12px).',
  },
  {
    id: RADIUS_MODES.UNIVERSAL_2,
    label: 'Universal 2',
    description: 'Every rounded corner uses the second ramp radius (8px).',
  },
  {
    id: RADIUS_MODES.UNIVERSAL_1,
    label: 'Universal 1',
    description: 'Every rounded corner uses the first ramp radius (4px).',
  },
  {
    id: RADIUS_MODES.UNIVERSAL_0,
    label: 'Universal 0',
    description: 'Every rounded corner is square (0 radius).',
  },
]);

export const RADIUS_SECTION_FOOTER =
  'Scales rounded corners on cards, tiles, and sheets. Circular buttons and navigation stay round.';

/**
 * Canonical native ramp bases (Swift `MinCornerRadius`).
 * JS `borders.radii` names differ; resolve by numeric value, not name.
 */
export const RADIUS_BASE = Object.freeze({
  none: 0,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  sheet: 38,
  artTile: 8,
  round: 100,
});

/**
 * Web `borders.radii` numeric bases (current defaults).
 */
export const WEB_RADIUS_BASE = Object.freeze({
  none: 0,
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 24,
  artTile: 4,
  full: 9999,
});

/** Current web BottomSheet chrome — `borders.radii.xl` / `--min-radius-lg`. */
export const WEB_SHEET_RADIUS = WEB_RADIUS_BASE.xl;

/** Buttons, inputs, and other circular-adjacent controls — never remapped. */
export const CONTROL_RADIUS_PX = WEB_RADIUS_BASE.md;

const STORAGE_KEY = 'min-apps-radius-mode';

let currentMode = RADIUS_MODES.DEFAULT;

function isKnownMode(mode) {
  return RADIUS_MODE_OPTIONS.some((option) => option.id === mode);
}

export function getRadiusMode() {
  return currentMode;
}

export function parseRadiusValue(value) {
  if (typeof value === 'number') return value;
  if (typeof value !== 'string') return 0;
  const trimmed = value.trim();
  if (trimmed === '50%' || trimmed === '100%') return RADIUS_CIRCULAR_THRESHOLD;
  const match = /^(-?[\d.]+)px$/i.exec(trimmed);
  return match ? Number.parseFloat(match[1]) : 0;
}

/**
 * Index on the ramp, or `null` when the value is below the smallest ramp
 * radius (those stay as-is under reduced modes instead of going to 0).
 */
export function rampIndexFor(value) {
  const ramp = RADIUS_RAMP;
  const exact = ramp.indexOf(value);
  if (exact !== -1) return exact;
  if (value < ramp[0]) return null;
  if (value > ramp[ramp.length - 1]) {
    const stepSize = ramp[1] - ramp[0];
    const extra = Math.round((value - ramp[ramp.length - 1]) / stepSize);
    return ramp.length - 1 + Math.max(0, extra);
  }
  for (let i = ramp.length - 1; i >= 0; i -= 1) {
    if (ramp[i] <= value) return i;
  }
  return 0;
}

export function slideRadius(base, steps) {
  const ramp = RADIUS_RAMP;
  if (!steps) return base;
  const index = rampIndexFor(base);
  if (index == null) return base;
  const next = Math.max(0, index - steps);
  if (next < ramp.length) return ramp[next];
  const last = ramp[ramp.length - 1];
  const stepSize = ramp[1] - ramp[0];
  return last + (next - (ramp.length - 1)) * stepSize;
}

export function resolveRadius(base, mode = currentMode) {
  const value = typeof base === 'string' ? parseRadiusValue(base) : Number(base);
  if (!Number.isFinite(value)) return 0;
  if (value >= RADIUS_CIRCULAR_THRESHOLD) return value;
  if (value <= 0) return 0;

  switch (mode) {
    case RADIUS_MODES.DEFAULT:
      return value;
    case RADIUS_MODES.REDUCED_1:
      return slideRadius(value, 1);
    case RADIUS_MODES.REDUCED_2:
      return slideRadius(value, 2);
    case RADIUS_MODES.REDUCED_3:
      return slideRadius(value, 3);
    case RADIUS_MODES.UNIVERSAL_3:
      return RADIUS_RAMP[2];
    case RADIUS_MODES.UNIVERSAL_2:
      return RADIUS_RAMP[1];
    case RADIUS_MODES.UNIVERSAL_1:
      return RADIUS_RAMP[0];
    case RADIUS_MODES.UNIVERSAL_0:
      return 0;
    default:
      return value;
  }
}

/**
 * System / web sheet chrome. Native default is 38pt; reduced 1/2/3 step
 * onto the named ramp from `xl` (20 → 16 → 12). Universal matches content.
 */
export function resolveSheet(mode = currentMode, base = RADIUS_BASE.sheet) {
  const value = Number(base);
  if (!Number.isFinite(value)) return 0;

  switch (mode) {
    case RADIUS_MODES.DEFAULT:
      return value;
    case RADIUS_MODES.REDUCED_1:
    case RADIUS_MODES.REDUCED_2:
    case RADIUS_MODES.REDUCED_3: {
      const steps = mode === RADIUS_MODES.REDUCED_3 ? 3 : mode === RADIUS_MODES.REDUCED_2 ? 2 : 1;
      const last = RADIUS_RAMP[RADIUS_RAMP.length - 1];
      if (value > last) {
        return slideRadius(last, steps - 1);
      }
      return slideRadius(value, steps);
    }
    case RADIUS_MODES.UNIVERSAL_3:
      return RADIUS_RAMP[2];
    case RADIUS_MODES.UNIVERSAL_2:
      return RADIUS_RAMP[1];
    case RADIUS_MODES.UNIVERSAL_1:
      return RADIUS_RAMP[0];
    case RADIUS_MODES.UNIVERSAL_0:
      return 0;
    default:
      return value;
  }
}

export function formatRadiusPx(value) {
  if (value === 0) return '0';
  return `${value}px`;
}

/**
 * CSS custom properties whose *base* values should follow the radii setting.
 * Circular `--*-round` / `--*-full` tokens are omitted.
 */
export const RADIUS_CSS_VARIABLE_BASES = Object.freeze({
  '--min-radius-xs': RADIUS_BASE.xs,
  '--min-radius-sm': RADIUS_BASE.sm,
  '--min-radius-md': RADIUS_BASE.md,
  '--min-radius-lg': RADIUS_BASE.lg,
  '--min-radius-xl': RADIUS_BASE.xl,
  '--min-radius-art-tile': WEB_RADIUS_BASE.artTile,
  '--ds-radius-xs': RADIUS_BASE.xs,
  '--ds-radius-sm': RADIUS_BASE.sm,
  '--ds-radius-md': RADIUS_BASE.md,
  '--ds-radius-lg': RADIUS_BASE.lg,
  '--ds-radius-xl': RADIUS_BASE.xl,
  '--ds-radius-artTile': RADIUS_BASE.artTile,
  '--radius-sm': RADIUS_BASE.sm,
  '--radius-md': RADIUS_BASE.md,
  '--radius-lg': RADIUS_BASE.lg,
  '--radius-xl': 24,
  '--border-radius-sm': WEB_RADIUS_BASE.sm,
  '--border-radius-md': WEB_RADIUS_BASE.md,
  '--border-radius-lg': WEB_RADIUS_BASE.lg,
  '--border-radius-xl': WEB_RADIUS_BASE.xl,
  '--border-radius-2xl': WEB_RADIUS_BASE['2xl'],
  '--border-radius-art-tile': WEB_RADIUS_BASE.artTile,
});

export function radiusCssVariables(mode = currentMode) {
  const vars = {};
  for (const [name, base] of Object.entries(RADIUS_CSS_VARIABLE_BASES)) {
    vars[name] = formatRadiusPx(resolveRadius(base, mode));
  }
  vars['--min-radius-sheet'] = formatRadiusPx(resolveSheet(mode, WEB_SHEET_RADIUS));
  vars['--min-radius-none'] = '0px';
  vars['--min-radius-round'] = '100px';
  vars['--min-radius-full'] = '9999px';
  vars['--radius-none'] = '0px';
  vars['--radius-round'] = '999px';
  vars['--ds-radius-round'] = '100px';
  vars['--border-radius-full'] = '9999px';
  return vars;
}

export function applyRadiusStyleToDocument(mode = currentMode, root = globalThis.document?.documentElement) {
  if (!root?.style?.setProperty) return;
  const vars = radiusCssVariables(mode);
  Object.entries(vars).forEach(([property, value]) => {
    root.style.setProperty(property, value);
  });
  root.setAttribute('data-radius-mode', mode);
}

export function getSavedRadiusMode() {
  if (typeof localStorage === 'undefined') {
    return RADIUS_MODES.DEFAULT;
  }
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return isKnownMode(saved) ? saved : RADIUS_MODES.DEFAULT;
  } catch {
    return RADIUS_MODES.DEFAULT;
  }
}

export function setRadiusMode(mode, { persist = true, apply = true } = {}) {
  currentMode = isKnownMode(mode) ? mode : RADIUS_MODES.DEFAULT;
  if (persist && typeof localStorage !== 'undefined') {
    try {
      localStorage.setItem(STORAGE_KEY, currentMode);
    } catch {
      // Ignore quota / private-mode failures.
    }
  }
  if (apply) {
    applyRadiusStyleToDocument(currentMode);
  }
  return currentMode;
}

export function initRadiusStyle() {
  currentMode = getSavedRadiusMode();
  applyRadiusStyleToDocument(currentMode);
  return currentMode;
}

export default {
  RADIUS_RAMP,
  RADIUS_MODES,
  RADIUS_MODE_OPTIONS,
  RADIUS_BASE,
  WEB_RADIUS_BASE,
  WEB_SHEET_RADIUS,
  CONTROL_RADIUS_PX,
  resolveRadius,
  resolveSheet,
  slideRadius,
  setRadiusMode,
  getRadiusMode,
  initRadiusStyle,
};
