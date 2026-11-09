/**
 * Shared math for omnidirectional edge-swipe-to-dismiss on bottom sheets.
 * Used by the web BottomSheet and mirrored in MinAppKit (Swift).
 *
 * A gesture that begins on a sheet edge tracks the sheet in any direction.
 * Releasing past the distance/velocity threshold dismisses; otherwise it
 * springs back to the resting position.
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
  // Velocity must continue away from the origin, not reverse back into place.
  return dx * vx + dy * vy > 0;
}

export function dismissTranslation(dx, dy, width, height) {
  const dist = swipeDistance(dx, dy);
  const travel = Math.max(Math.hypot(width || 0, height || 0), 1);
  if (dist < 1) {
    return { x: 0, y: travel };
  }
  const scale = travel / dist;
  return { x: dx * scale, y: dy * scale };
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
