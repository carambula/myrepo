import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import {
  CONTROL_RADIUS_PX,
  RADIUS_BASE,
  RADIUS_MODES,
  RADIUS_RAMP,
  WEB_RADIUS_BASE,
  WEB_SHEET_RADIUS,
  formatRadiusPx,
  getRadiusMode,
  radiusCssVariables,
  rampIndexFor,
  resolveRadius,
  resolveSheet,
  setRadiusMode,
  slideRadius,
} from './radiusStyle.js';
import { borders } from '../tokens/borders.js';

const ramp = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
};

describe('radius ramp', () => {
  it('matches the native 4–20pt scale', () => {
    assert.deepEqual(RADIUS_RAMP, [4, 8, 12, 16, 20]);
    assert.equal(RADIUS_BASE.xs, ramp.xs);
    assert.equal(RADIUS_BASE.xl, ramp.xl);
  });
});

describe('slideRadius', () => {
  it('slides each named radius down one step and clamps at the smallest ramp radius', () => {
    assert.equal(slideRadius(ramp.xs, 1), ramp.xs);
    assert.equal(slideRadius(ramp.sm, 1), ramp.xs);
    assert.equal(slideRadius(ramp.md, 1), ramp.sm);
    assert.equal(slideRadius(ramp.lg, 1), ramp.md);
    assert.equal(slideRadius(ramp.xl, 1), ramp.lg);
  });

  it('slides two and three steps without going to 0', () => {
    assert.equal(slideRadius(ramp.xs, 2), ramp.xs);
    assert.equal(slideRadius(ramp.sm, 2), ramp.xs);
    assert.equal(slideRadius(ramp.md, 2), ramp.xs);
    assert.equal(slideRadius(ramp.lg, 2), ramp.sm);
    assert.equal(slideRadius(ramp.xl, 2), ramp.md);

    assert.equal(slideRadius(ramp.xs, 3), ramp.xs);
    assert.equal(slideRadius(ramp.sm, 3), ramp.xs);
    assert.equal(slideRadius(ramp.md, 3), ramp.xs);
    assert.equal(slideRadius(ramp.lg, 3), ramp.xs);
    assert.equal(slideRadius(ramp.xl, 3), ramp.sm);
  });

  it('keeps values below the smallest ramp radius as-is', () => {
    assert.equal(slideRadius(2, 3), 2);
    assert.equal(rampIndexFor(2), null);
  });

  it('treats 24 as one step above xl', () => {
    assert.equal(slideRadius(24, 1), ramp.xl);
    assert.equal(slideRadius(24, 2), ramp.lg);
  });
});

describe('resolveRadius', () => {
  it('keeps current values in default mode', () => {
    for (const value of Object.values(ramp)) {
      assert.equal(resolveRadius(value, RADIUS_MODES.DEFAULT), value);
    }
    assert.equal(resolveRadius(WEB_RADIUS_BASE.artTile, RADIUS_MODES.DEFAULT), 4);
  });

  it('applies reduced 1/2/3 from each current radius', () => {
    assert.equal(resolveRadius(ramp.md, RADIUS_MODES.REDUCED_1), ramp.sm);
    assert.equal(resolveRadius(ramp.md, RADIUS_MODES.REDUCED_2), ramp.xs);
    assert.equal(resolveRadius(ramp.md, RADIUS_MODES.REDUCED_3), ramp.xs);
    assert.equal(resolveRadius(ramp.xs, RADIUS_MODES.REDUCED_3), ramp.xs);
  });

  it('applies universal 3/2/1/0 to every rounded corner', () => {
    for (const value of [ramp.xs, ramp.sm, ramp.md, ramp.lg, ramp.xl, 24]) {
      assert.equal(resolveRadius(value, RADIUS_MODES.UNIVERSAL_3), ramp.md);
      assert.equal(resolveRadius(value, RADIUS_MODES.UNIVERSAL_2), ramp.sm);
      assert.equal(resolveRadius(value, RADIUS_MODES.UNIVERSAL_1), ramp.xs);
      assert.equal(resolveRadius(value, RADIUS_MODES.UNIVERSAL_0), 0);
    }
  });

  it('does not remap circular or pill radii', () => {
    assert.equal(resolveRadius(100, RADIUS_MODES.UNIVERSAL_0), 100);
    assert.equal(resolveRadius(9999, RADIUS_MODES.REDUCED_3), 9999);
    assert.equal(resolveRadius('50%', RADIUS_MODES.UNIVERSAL_0), 50);
  });

  it('leaves already-square corners square', () => {
    assert.equal(resolveRadius(0, RADIUS_MODES.UNIVERSAL_3), 0);
    assert.equal(resolveRadius(0, RADIUS_MODES.REDUCED_1), 0);
  });

  it('accepts px strings', () => {
    assert.equal(resolveRadius('12px', RADIUS_MODES.REDUCED_1), 8);
    assert.equal(formatRadiusPx(0), '0');
    assert.equal(formatRadiusPx(8), '8px');
  });
});

describe('control radii', () => {
  it('keeps the web control radius at the current button default', () => {
    assert.equal(CONTROL_RADIUS_PX, 8);
    setRadiusMode(RADIUS_MODES.UNIVERSAL_0, { persist: false, apply: false });
    assert.equal(CONTROL_RADIUS_PX, 8);
    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
  });

  it('remaps content tokens but not control or pill radii', () => {
    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
    assert.equal(borders.radii.md, '8px');
    assert.equal(borders.radii.control, '8px');
    assert.equal(borders.radii.full, '9999px');

    setRadiusMode(RADIUS_MODES.REDUCED_1, { persist: false, apply: false });
    assert.equal(borders.radii.md, '4px');
    assert.equal(borders.radii.control, '8px');
    assert.equal(borders.radii.full, '9999px');

    setRadiusMode(RADIUS_MODES.UNIVERSAL_0, { persist: false, apply: false });
    assert.equal(borders.radii.md, '0');
    assert.equal(borders.radii.artTile, '0');
    assert.equal(borders.radii.control, '8px');
    assert.equal(borders.radii.full, '9999px');

    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
    assert.equal(getRadiusMode(), RADIUS_MODES.DEFAULT);
  });
});

describe('resolveSheet', () => {
  it('keeps the system sheet radius in default mode', () => {
    assert.equal(resolveSheet(RADIUS_MODES.DEFAULT), 38);
    assert.equal(RADIUS_BASE.sheet, 38);
  });

  it('steps the native sheet onto the named ramp for reduced modes', () => {
    assert.equal(resolveSheet(RADIUS_MODES.REDUCED_1), ramp.xl);
    assert.equal(resolveSheet(RADIUS_MODES.REDUCED_2), ramp.lg);
    assert.equal(resolveSheet(RADIUS_MODES.REDUCED_3), ramp.md);
  });

  it('uses universal radii for sheet chrome', () => {
    assert.equal(resolveSheet(RADIUS_MODES.UNIVERSAL_3), ramp.md);
    assert.equal(resolveSheet(RADIUS_MODES.UNIVERSAL_2), ramp.sm);
    assert.equal(resolveSheet(RADIUS_MODES.UNIVERSAL_1), ramp.xs);
    assert.equal(resolveSheet(RADIUS_MODES.UNIVERSAL_0), 0);
  });

  it('slides a web sheet that already sits on the ramp', () => {
    assert.equal(WEB_SHEET_RADIUS, 16);
    assert.equal(resolveSheet(RADIUS_MODES.REDUCED_1, 16), ramp.md);
    assert.equal(resolveSheet(RADIUS_MODES.DEFAULT, 16), 16);
  });

  it('keeps the current web BottomSheet radius in CSS variables', () => {
    assert.equal(radiusCssVariables(RADIUS_MODES.DEFAULT)['--min-radius-sheet'], '16px');
    assert.equal(radiusCssVariables(RADIUS_MODES.REDUCED_1)['--min-radius-sheet'], '12px');
    assert.equal(radiusCssVariables(RADIUS_MODES.UNIVERSAL_0)['--min-radius-sheet'], '0');
  });

  it('exposes a live sheet token on borders.radii', () => {
    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
    assert.equal(borders.radii.sheet, '16px');
    setRadiusMode(RADIUS_MODES.UNIVERSAL_0, { persist: false, apply: false });
    assert.equal(borders.radii.sheet, '0');
    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
  });
});

describe('setRadiusMode', () => {
  beforeEach(() => {
    setRadiusMode(RADIUS_MODES.DEFAULT, { persist: false, apply: false });
  });

  it('falls back to default for unknown values', () => {
    assert.equal(setRadiusMode('not-a-mode', { persist: false, apply: false }), RADIUS_MODES.DEFAULT);
  });
});
