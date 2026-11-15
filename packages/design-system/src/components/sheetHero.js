/**
 * Shared math for zooming a sheet out of a matching key image and flinging
 * that image back into its thumbnail. Mirrors MinAppKit SheetHeroTransition.
 */

export const heroOpenDuration = 0.42;
/** Kept at 0 so shade, stacked layers, and the image share one motion. */
export const heroOverlayFadeDuration = 0;

export function sheetHeroID(kind, id) {
  return `${kind}:${id}`;
}

/** One shared duration: the flying sheet and shade finish together. */
export function heroDismissTiming({
  from,
  to,
  speed,
  minDuration = 0.18,
  maxDuration = 0.42,
  fadeDuration = heroOverlayFadeDuration,
} = {}) {
  const move = heroReturnDuration({ from, to, speed, minDuration, maxDuration });
  return { move, fade: fadeDuration, total: move + fadeDuration };
}

export function heroReturnScale(currentWidth, sourceWidth) {
  if (!(currentWidth > 1)) return 1;
  return sourceWidth / currentWidth;
}

export function heroReturnDuration({
  from,
  to,
  speed,
  minDuration = 0.18,
  maxDuration = 0.42,
} = {}) {
  const fromMidX = (from?.x || 0) + (from?.width || 0) / 2;
  const fromMidY = (from?.y || 0) + (from?.height || 0) / 2;
  const toMidX = (to?.x || 0) + (to?.width || 0) / 2;
  const toMidY = (to?.y || 0) + (to?.height || 0) / 2;
  const distance = Math.hypot(toMidX - fromMidX, toMidY - fromMidY);
  const duration = distance / Math.max(speed, 1);
  return Math.min(maxDuration, Math.max(minDuration, duration));
}

/** Map a sheet rect onto a source image rect (top-left origin). */
export function heroOpenTransform(source, sheet) {
  const scale = heroReturnScale(sheet?.width || 0, source?.width || 0);
  return {
    x: (source?.x || 0) - (sheet?.x || 0),
    y: (source?.y || 0) - (sheet?.y || 0),
    scale,
  };
}
