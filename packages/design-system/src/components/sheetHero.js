/**
 * Shared math for zooming a sheet out of a matching key image and flinging
 * that image back into its thumbnail. Mirrors MinAppKit SheetHeroTransition.
 *
 * Nested sheets (a sheet sitting on another sheet) never zoom — only the
 * root sheet over home morphs from its key image.
 */

export const heroOpenDuration = 0.42;
/** Kept at 0 so shade, stacked layers, and the image share one motion. */
export const heroOverlayFadeDuration = 0;
/** Smallest overlap that still counts as "the thumbnail is on screen." */
export const heroSourceVisibleOverlap = 8;

export function sheetHeroID(kind, id) {
  return `${kind}:${id}`;
}

/** Root home↔sheet only. A sheet on another sheet uses ordinary present/dismiss. */
export function shouldHeroZoomSheet({ nested } = {}) {
  return nested !== true;
}

/** True when enough of the source rect is still in the viewport to morph into. */
export function isHeroSourceVisible(source, viewport, minOverlap = heroSourceVisibleOverlap) {
  if (!source || !viewport) return false;
  const width =
    Math.min(source.x + source.width, viewport.x + viewport.width) -
    Math.max(source.x, viewport.x);
  const height =
    Math.min(source.y + source.height, viewport.y + viewport.height) -
    Math.max(source.y, viewport.y);
  return width > minOverlap && height > minOverlap;
}

/**
 * Artwork overlay opacity while the returning card scales into place.
 * On-screen sources are already the flying object (fully opaque). Off-screen
 * sources fade the stored key image in so the shrinking card fills with art.
 */
export function heroFillOpacity(progress, { sourceVisible } = {}) {
  if (sourceVisible) return 1;
  const t = Number(progress);
  if (!Number.isFinite(t)) return 0;
  return Math.min(1, Math.max(0, t));
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
