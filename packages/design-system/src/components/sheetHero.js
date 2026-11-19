/**
 * Shared math for zooming a sheet out of a matching key image and flinging
 * that image back into its thumbnail. Mirrors MinAppKit SheetHeroTransition.
 *
 * Nested sheets skip the open zoom (ordinary present). Dismiss still flings
 * the card to the rest-size thumb while the sheet below un-scales with it.
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

/**
 * Re-applying `preferredCornerRadius` during dismiss fights the morph and
 * punches holes in the dim plate. Skip it while the card is flying.
 */
export function shouldApplySheetChromeRadius({ dismissing = false, heroMotion = false } = {}) {
  return dismissing !== true && heroMotion !== true;
}

/**
 * Clip-only corner radius for the returning card. Do not bake the sheet
 * radius into the snapshot and scale it — that only matches the tile when
 * the default 38pt sheet happens to scale onto an 8pt art tile.
 */
export function heroReturnClipRadius(fromRadius, toRadius) {
  const from = Number.isFinite(fromRadius) ? Math.max(0, fromRadius) : 0;
  const to = Number.isFinite(toRadius) ? Math.max(0, toRadius) : 0;
  return { from, to };
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
 * On-screen sources at rest stay the flying object. Off-screen sources, or a
 * sheet that has been scrolled away from its hero, fade the stored key image
 * in so the card does not crop-and-snap into the tile.
 */
export function heroFillOpacity(progress, { sourceVisible, scrolled } = {}) {
  if (sourceVisible !== false && scrolled !== true) return 1;
  const t = Number(progress);
  if (!Number.isFinite(t)) return 0;
  return Math.min(1, Math.max(0, t));
}

/**
 * Presenter scale shrinks every on-screen tile. Keep the rest-size frame so
 * the returning card flies to where the thumb will be, not the shrunken sheet.
 * Off-screen twins (the other pager page, a covered cell) must not overwrite
 * a live on-screen frame — that is what sent grid dismisses to a corner.
 */
export function shouldReplaceHeroFrame(
  existing,
  next,
  { existingOnScreen, nextOnScreen } = {}
) {
  if (!(next?.width > 1) || !(next?.height > 1)) return false;
  if (!existing) return true;
  if (next.width < existing.width * 0.97) return false;
  if (existingOnScreen && nextOnScreen === false) return false;
  return true;
}

/**
 * Root and nested sheets both fling the card back. Nested lands on the
 * rest-size thumb while the sheet below un-scales in the same motion.
 */
export function shouldHeroFlingToSource({ nested: _nested } = {}) {
  return true;
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
