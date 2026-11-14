/**
 * Shared math for omnidirectional edge-swipe-to-dismiss on bottom sheets.
 * Used by the web BottomSheet and mirrored in MinAppKit (Swift).
 *
 * A gesture that begins on a sheet edge tracks the sheet 1:1 under the
 * finger. Releasing past the distance/velocity threshold flings it away
 * along the drag trajectory; otherwise it springs back to rest.
 */

export const edgeSwipeToDismissDefaults = {
  sideInset: 24,
  topInset: 44,
  bottomInset: 24,
  dismissDistance: 120,
  velocityThreshold: 900,
  minFlingDistance: 48,
  minScale: 0.92,
  activationDistance: 8,
  sampleWindowMs: 80,
  minFlingSpeed: 1100,
  maxFlingSpeed: 2800,
  minFlingDuration: 0.18,
  maxFlingDuration: 0.42,
  // Higher = closer to 1:1. ~720 lets a 80pt pull move ~71pt.
  bottomSwipeStiffness: 720,
  // Web sheet spec. Native reads the live presentation platter and flattens
  // the drag proxy to a single continuous clip so nested radii cannot peek.
  cardCornerRadius: 16,
  // Dim-only backdrops (blur removed — was expensive and rarely visible).
  restBackdropBlurPx: 0,
  edges: { top: true, right: true, bottom: true, left: true },
};

export function isOnSheetEdge(x, y, width, height, options = {}) {
  const sideInset = options.sideInset ?? edgeSwipeToDismissDefaults.sideInset;
  const topInset = options.topInset ?? edgeSwipeToDismissDefaults.topInset;
  const bottomInset = options.bottomInset ?? edgeSwipeToDismissDefaults.bottomInset;
  const edges = { ...edgeSwipeToDismissDefaults.edges, ...options.edges };

  if (width <= 0 || height <= 0) return false;
  if (!Number.isFinite(x) || !Number.isFinite(y)) return false;

  const onLeft = edges.left !== false && x >= 0 && x <= sideInset;
  const onRight = edges.right !== false && x >= width - sideInset && x <= width;
  const onTop = edges.top !== false && y >= 0 && y <= topInset;
  const onBottom = edges.bottom !== false && y >= height - bottomInset && y <= height;
  return onLeft || onRight || onTop || onBottom;
}

export function nearestScrollable(node, root) {
  let el = node;
  while (el && el !== root) {
    if (el.scrollHeight > el.clientHeight + 1) return el;
    el = el.parentElement;
  }
  return null;
}

export function isScrollAtTop(el) {
  if (!el) return true;
  return el.scrollTop <= 1;
}

export function isScrollAtBottom(el) {
  if (!el) return true;
  return el.scrollTop + el.clientHeight >= el.scrollHeight - 1;
}

export function effectiveCardCornerRadius(
  configured = 0,
  platter = 0,
  fallback = 38
) {
  if (configured > 0.5) return configured;
  if (platter > 0.5) return platter;
  return fallback;
}

export function scrollLimitActivation({
  dx = 0,
  dy = 0,
  atTop = false,
  atBottom = false,
} = {}) {
  if (Math.abs(dy) < Math.abs(dx)) return null;
  if (atTop && dy > 0) return 'topOverscroll';
  if (atBottom && dy < 0) return 'bottomOverscroll';
  return null;
}

/**
 * Mild resistance so the sheet lags the finger a little. Used for the
 * bottom-overscroll swipe so lifting the sheet off the home indicator
 * does not feel weightless.
 */
export function resistOffset(offset, stiffness = edgeSwipeToDismissDefaults.bottomSwipeStiffness) {
  if (!offset) return 0;
  const s = Math.max(stiffness, 1);
  return offset / (1 + Math.abs(offset) / s);
}

/**
 * Bottom-overscroll follow is resisted (especially upward). Edge and
 * top-overscroll stays 1:1 with the finger.
 */
export function visualTranslation({
  dx = 0,
  dy = 0,
  activation,
  stiffness = edgeSwipeToDismissDefaults.bottomSwipeStiffness,
} = {}) {
  if (activation !== 'bottomOverscroll') return { dx, dy };
  return {
    dx: resistOffset(dx, stiffness),
    dy: dy < 0 ? resistOffset(dy, stiffness) : dy,
  };
}

export function swipeDistance(dx, dy) {
  return Math.hypot(dx || 0, dy || 0);
}

export function swipeProgress(dx, dy, dismissDistance = edgeSwipeToDismissDefaults.dismissDistance) {
  if (!(dismissDistance > 0)) return 0;
  return Math.min(1, swipeDistance(dx, dy) / dismissDistance);
}

export function swipeScale(progress, minScale = edgeSwipeToDismissDefaults.minScale) {
  const p = Math.min(1, Math.max(0, progress || 0));
  return 1 - (1 - minScale) * p;
}

export function swipeBackdropOpacity(progress) {
  return Math.max(0, 1 - Math.min(1, Math.max(0, progress || 0)));
}

/** @deprecated Dim-only sheets — always returns 0. Kept for API compatibility. */
export function swipeBackdropBlurPx(
  progress,
  restBlurPx = edgeSwipeToDismissDefaults.restBackdropBlurPx
) {
  return Math.max(0, restBlurPx * swipeBackdropOpacity(progress));
}

export function velocityFromSamples(samples, now = 0, windowMs = edgeSwipeToDismissDefaults.sampleWindowMs) {
  if (!Array.isArray(samples) || samples.length < 2) {
    return { vx: 0, vy: 0 };
  }
  const cutoff = now > 0 ? now - windowMs : samples[samples.length - 1].t - windowMs;
  const recent = samples.filter((s) => s.t >= cutoff);
  if (recent.length < 2) return { vx: 0, vy: 0 };
  const first = recent[0];
  const last = recent[recent.length - 1];
  const dt = (last.t - first.t) / 1000;
  if (!(dt > 0)) return { vx: 0, vy: 0 };
  return {
    vx: (last.x - first.x) / dt,
    vy: (last.y - first.y) / dt,
  };
}

export function shouldDismissEdgeSwipe({
  dx,
  dy,
  vx = 0,
  vy = 0,
  dismissDistance = edgeSwipeToDismissDefaults.dismissDistance,
  velocityThreshold = edgeSwipeToDismissDefaults.velocityThreshold,
  minFlingDistance = edgeSwipeToDismissDefaults.minFlingDistance,
} = {}) {
  const dist = swipeDistance(dx, dy);
  if (dist >= dismissDistance) return true;
  if (dist < minFlingDistance) return false;
  const speed = Math.hypot(vx, vy);
  if (speed < velocityThreshold) return false;
  return dx * vx + dy * vy > 0;
}

export function flingDirection(dx, dy, vx = 0, vy = 0) {
  const speed = Math.hypot(vx, vy);
  const along = (dx || 0) * vx + (dy || 0) * vy;
  const useVelocity = speed >= 80 && along > 0;
  const x = useVelocity ? vx : dx || 0;
  const y = useVelocity ? vy : dy || 0;
  const mag = Math.hypot(x, y);
  if (mag < 1) return { x: 0, y: 1 };
  return { x: x / mag, y: y / mag };
}

export function dismissTranslation(dx, dy, width, height, vx = 0, vy = 0) {
  const dir = flingDirection(dx, dy, vx, vy);
  const travel = Math.max(Math.hypot(width || 0, height || 0), 1);
  return { x: dir.x * travel, y: dir.y * travel };
}

export function clampedFlingSpeed(
  vx = 0,
  vy = 0,
  minSpeed = edgeSwipeToDismissDefaults.minFlingSpeed,
  maxSpeed = edgeSwipeToDismissDefaults.maxFlingSpeed
) {
  const speed = Math.hypot(vx, vy);
  return Math.min(maxSpeed, Math.max(minSpeed, speed || minSpeed));
}

export function flingDuration({
  dx,
  dy,
  vx = 0,
  vy = 0,
  width,
  height,
  minSpeed = edgeSwipeToDismissDefaults.minFlingSpeed,
  maxSpeed = edgeSwipeToDismissDefaults.maxFlingSpeed,
  minDuration = edgeSwipeToDismissDefaults.minFlingDuration,
  maxDuration = edgeSwipeToDismissDefaults.maxFlingDuration,
} = {}) {
  const target = dismissTranslation(dx, dy, width, height, vx, vy);
  const remaining = Math.hypot((target.x || 0) - (dx || 0), (target.y || 0) - (dy || 0));
  const speed = clampedFlingSpeed(vx, vy, minSpeed, maxSpeed);
  const duration = remaining / speed;
  return Math.min(maxDuration, Math.max(minDuration, duration));
}

export function sheetTransform({
  dx,
  dy,
  progress,
  minScale = edgeSwipeToDismissDefaults.minScale,
  dismissing = false,
  dismissX,
  dismissY,
} = {}) {
  const x = dismissing ? dismissX : dx;
  const y = dismissing ? dismissY : dy;
  const scale = dismissing ? minScale : swipeScale(progress, minScale);
  return `translate(${x || 0}px, ${y || 0}px) scale(${scale})`;
}
