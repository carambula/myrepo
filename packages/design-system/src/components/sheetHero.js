/**
 * Shared math for zooming a sheet out of a matching key image.
 * Mirrors MinAppKit SheetHeroTransition.
 *
 * Open and close use the system zoom transition (iOS 18
 * `matchedTransitionSource` + `navigationTransition(.zoom)`), the same API
 * as the App Store. Destinations present as `.sheet`. Custom snapshot
 * flings fight that motion.
 */

export const heroOpenDuration = 0.42;
/** Kept at 0 so shade, stacked layers, and the image share one motion. */
export const heroOverlayFadeDuration = 0;
/** Smallest overlap that still counts as "the thumbnail is on screen." */
export const heroSourceVisibleOverlap = 8;

export function sheetHeroID(kind, id) {
  return `${kind}:${id}`;
}

/** System zoom handles root and nested sheets. */
export function shouldHeroZoomSheet({ nested: _nested } = {}) {
  return true;
}

/**
 * `navigationTransition(.zoom)` must sit on the presented view, not inside
 * the destination view's body. Inner attachment lets UIKit draw a full-size
 * sheet for a frame, then remove it when zoom starts.
 */
export function shouldAttachHeroZoomOnPresentedSheet({ innerBody = false } = {}) {
  return innerBody !== true;
}

/**
 * Zoom destinations present as sheets. Full-screen covers and UIKit
 * `preferredTransition` drop the sheet chrome.
 */
export function shouldPresentHeroZoomAsFullScreenCover({ hasSource: _hasSource } = {}) {
  return false;
}

export function shouldPresentHeroZoomWithPreferredTransition({ hasSource: _hasSource } = {}) {
  return false;
}

export function shouldPresentHeroZoomAsSheet({ hasSource = true } = {}) {
  return hasSource === true;
}

/**
 * A zoom sheet is the system's from its first frame. The presenting side
 * knows it is a zoom sheet as soon as its content is built (`expected`),
 * once the destination has rendered (`rendered`), or when the controller
 * carries a preferred transition. Waiting for `rendered` alone is too late:
 * UIKit reports the sheet before the sheet has drawn.
 */
export function isSystemZoomPresentation({
  expected = false,
  rendered = false,
  preferredTransition = false,
} = {}) {
  return expected === true || rendered === true || preferredTransition === true;
}

/**
 * The presenting-side scrim guard leaves a zoom sheet alone: no chrome
 * writes, no custom dim plate, no child hook in the sheet's view.
 */
export function shouldScrimGuardManageSheet({ systemZoom = false } = {}) {
  return systemZoom !== true;
}

/**
 * Overlay mini-player sheets must present from a full-window host. A 72pt
 * hugging host makes UIKit draw a full-size platter, then zoom tears it down.
 */
export function shouldSizeMiniPlayerOverlayHostToWindow() {
  return true;
}

/** Hits outside the mini card must pass through to the main window. */
export function shouldHitTestMiniPlayerOverlayCardOnly() {
  return true;
}

/**
 * Overlay hit testing must use the card's UIKit window frame, not SwiftUI
 * `.global` — in a secondary window those spaces do not match.
 */
export function shouldReportMiniPlayerHitTargetInWindowCoordinates() {
  return true;
}

/**
 * The visible pager page must sit at layout x = 0. Parent `.offset` is
 * visual-only, so list sources on page 1 otherwise stay at x = width.
 */
export function pagerPageOffset({ pageIndex = 0, pagerOffset = 0, pageWidth = 0 } = {}) {
  return pagerOffset + pageIndex * pageWidth;
}

/**
 * `matchedTransitionSource` hides live views in overlay windows (the floating
 * mini player). Keep an idle copy there. Grid/list tiles must not — a second
 * copy reads as a leftover thumb during the morph.
 */
export function shouldPersistMatchedSourceCopy({ kind } = {}) {
  return kind === 'miniPlayer';
}

/**
 * Overlay mini-player zoom must snapshot the visible copy. Matching the
 * hidden live view presents a full-size sheet for a frame, then tears it down.
 */
export function shouldMatchHeroSourceOnVisibleCopy({ kind } = {}) {
  return kind === 'miniPlayer';
}

/**
 * Off-screen pager twins (grid still mounted in list, and vice versa) must
 * not register as zoom sources or the sheet fades from the wrong rect.
 */
export function shouldRegisterHeroSource({ pageVisible = true } = {}) {
  return pageVisible === true;
}

/**
 * Mini-player chrome stays at rest while it owns the now-playing zoom.
 * Hide it only when a player from another window would sit underneath;
 * never animate that hide against the zoom.
 */
export function miniPlayerChromeOpacity({
  playerVisible = false,
  overlayOwnsPlayer = false,
} = {}) {
  if (playerVisible && !overlayOwnsPlayer) return 0;
  return 1;
}

/** Instant when the zoom is in flight; spring only for first appear / search. */
export function miniPlayerChromeAnimationDuration({
  zoomInFlight = false,
} = {}) {
  return zoomInFlight === true ? 0 : heroOpenDuration;
}

/**
 * Re-applying `preferredCornerRadius` during dismiss fights the morph and
 * punches holes in the dim plate. Skip it while the card is flying.
 */
export function shouldApplySheetChromeRadius({
  dismissing = false,
  presenting = false,
  heroMotion = false,
  systemZoom = false,
} = {}) {
  return (
    dismissing !== true &&
    presenting !== true &&
    heroMotion !== true &&
    systemZoom !== true
  );
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
 * sheet scrolled away from its hero, fade the stored key image in so the
 * card dissolves into the tile instead of cropping into it.
 */
export function heroFillOpacity(progress, { sourceVisible, scrolled } = {}) {
  if (sourceVisible !== false && scrolled !== true) return 1;
  const t = Number(progress);
  if (!Number.isFinite(t)) return 0;
  return Math.min(1, Math.max(0, t));
}

/**
 * Presenter scale shrinks tiles. Keep the rest-size frame so a grid dismiss
 * returns to the live thumb, not a shrunken or off-screen twin.
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

/** Do not snapshot-fling when the system zoom transition is driving dismiss. */
export function shouldHeroFlingToSource({ systemZoom = true } = {}) {
  return systemZoom !== true;
}

/**
 * Pin every sheet in a stack to the same chrome radius. Leaving the system
 * default (`< 0` / null) lets UIKit morph the sheet below to device corners.
 */
export function stackedSheetCornerRadius(preferred, { fallback = 38 } = {}) {
  if (preferred == null) return fallback;
  const value = Number(preferred);
  if (!Number.isFinite(value) || value < 0) return fallback;
  return value;
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
