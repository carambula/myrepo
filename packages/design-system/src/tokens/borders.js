/**
 * Border tokens for the min apps design system
 * Defines border widths, radii, and styles
 */

import {
  CONTROL_RADIUS_PX,
  WEB_RADIUS_BASE,
  formatRadiusPx,
  getRadiusMode,
  resolveRadius,
} from '../appearance/radiusStyle.js';

function liveRadius(basePx) {
  return formatRadiusPx(resolveRadius(basePx, getRadiusMode()));
}

export const borders = {
  // Border widths
  widths: {
    none: '0',
    thin: '1px',
    medium: '2px',
    thick: '4px',
  },

  // Border radii. Content radii follow `MinRadiusStyle` / `setRadiusMode`.
  // `control` and `full` are circular-adjacent (buttons, nav, pills) and
  // do not follow the radii setting.
  radii: {
    get none() {
      return liveRadius(WEB_RADIUS_BASE.none);
    },
    get sm() {
      return liveRadius(WEB_RADIUS_BASE.sm);
    },
    get md() {
      return liveRadius(WEB_RADIUS_BASE.md);
    },
    get lg() {
      return liveRadius(WEB_RADIUS_BASE.lg);
    },
    get xl() {
      return liveRadius(WEB_RADIUS_BASE.xl);
    },
    get ['2xl']() {
      return liveRadius(WEB_RADIUS_BASE['2xl']);
    },
    full: '9999px',
    control: formatRadiusPx(CONTROL_RADIUS_PX),

    // Primary art tile radius (movie posters, race images, video thumbnails, show art)
    // This is the ONLY radius that should be used for primary content artwork
    // across all min apps (WatchedIt, Cyclismo, Yourtube, Podlink)
    // DO NOT use larger radii (md, lg, xl, etc.) for primary art tiles
    get artTile() {
      return liveRadius(WEB_RADIUS_BASE.artTile);
    },
  },

  // Border styles
  styles: {
    solid: 'solid',
    dashed: 'dashed',
    dotted: 'dotted',
    none: 'none',
  },
};

export default borders;
