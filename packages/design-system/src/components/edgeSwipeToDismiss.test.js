import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  clampedFlingSpeed,
  dismissTranslation,
  edgeSwipeToDismissDefaults,
  flingDirection,
  flingDuration,
  isOnSheetEdge,
  isScrollAtBottom,
  isScrollAtTop,
  scrollLimitActivation,
  sheetTransform,
  shouldDismissEdgeSwipe,
  swipeBackdropOpacity,
  swipeDistance,
  swipeProgress,
  swipeScale,
  velocityFromSamples,
  resistOffset,
  visualTranslation,
} from './edgeSwipeToDismiss.js';

const sheet = { width: 390, height: 700 };

describe('isOnSheetEdge', () => {
  it('accepts starts on every edge and rejects the interior', () => {
    assert.equal(isOnSheetEdge(8, 200, sheet.width, sheet.height), true);
    assert.equal(isOnSheetEdge(sheet.width - 8, 200, sheet.width, sheet.height), true);
    assert.equal(isOnSheetEdge(200, 12, sheet.width, sheet.height), true);
    assert.equal(isOnSheetEdge(200, sheet.height - 8, sheet.width, sheet.height), true);
    assert.equal(isOnSheetEdge(120, 200, sheet.width, sheet.height), false);
  });

  it('honors a disabled bottom edge so home-indicator swipes can pass through', () => {
    assert.equal(
      isOnSheetEdge(200, sheet.height - 8, sheet.width, sheet.height, {
        edges: { bottom: false },
      }),
      false
    );
    assert.equal(
      isOnSheetEdge(8, 200, sheet.width, sheet.height, { edges: { bottom: false } }),
      true
    );
  });

  it('uses the taller top inset so the grabber is a valid start', () => {
    assert.equal(isOnSheetEdge(200, 40, sheet.width, sheet.height), true);
    assert.equal(isOnSheetEdge(200, 50, sheet.width, sheet.height), false);
  });

  it('rejects empty frames', () => {
    assert.equal(isOnSheetEdge(0, 0, 0, 100), false);
    assert.equal(isOnSheetEdge(Number.NaN, 0, 100, 100), false);
  });
});

describe('scrollLimitActivation', () => {
  it('takes over when pulling down past the top of content', () => {
    assert.equal(
      scrollLimitActivation({ dx: 0, dy: 20, atTop: true, atBottom: false }),
      'topOverscroll'
    );
  });

  it('takes over when pulling up past the bottom of content', () => {
    assert.equal(
      scrollLimitActivation({ dx: 0, dy: -20, atTop: false, atBottom: true }),
      'bottomOverscroll'
    );
  });

  it('lets interior scrolling continue', () => {
    assert.equal(
      scrollLimitActivation({ dx: 0, dy: 20, atTop: false, atBottom: false }),
      null
    );
    assert.equal(
      scrollLimitActivation({ dx: 0, dy: -20, atTop: true, atBottom: false }),
      null
    );
    assert.equal(
      scrollLimitActivation({ dx: 30, dy: 10, atTop: true, atBottom: false }),
      null
    );
  });

  it('treats a non-scrollable surface as both limits', () => {
    assert.equal(isScrollAtTop(null), true);
    assert.equal(isScrollAtBottom(null), true);
  });
});

describe('progress and visual follow', () => {
  it('tracks omnidirectional distance, not a single axis', () => {
    assert.equal(swipeDistance(30, 40), 50);
    assert.equal(swipeProgress(60, 0, 120), 0.5);
    assert.equal(swipeProgress(90, 120, 150), 1);
    assert.equal(swipeProgress(0, 0), 0);
  });

  it('scales and fades the backdrop as the sheet leaves its rest position', () => {
    assert.equal(swipeScale(0), 1);
    assert.equal(swipeScale(1), edgeSwipeToDismissDefaults.minScale);
    assert.equal(swipeScale(0.5), 0.96);
    assert.equal(swipeBackdropOpacity(0), 1);
    assert.equal(swipeBackdropOpacity(1), 0);
    assert.equal(swipeBackdropOpacity(0.25), 0.75);
  });

  it('builds a 2D transform that follows the finger', () => {
    assert.equal(
      sheetTransform({ dx: 24, dy: -18, progress: 0 }),
      'translate(24px, -18px) scale(1)'
    );
  });
});

describe('shouldDismissEdgeSwipe', () => {
  it('dismisses after enough travel in any direction', () => {
    assert.equal(shouldDismissEdgeSwipe({ dx: 130, dy: 0 }), true);
    assert.equal(shouldDismissEdgeSwipe({ dx: -80, dy: -100 }), true);
    assert.equal(shouldDismissEdgeSwipe({ dx: 20, dy: 20 }), false);
  });

  it('dismisses on a fling that continues away from rest', () => {
    assert.equal(
      shouldDismissEdgeSwipe({ dx: 60, dy: 10, vx: 1000, vy: 100 }),
      true
    );
  });

  it('snaps back when travel is too short even if velocity is high', () => {
    assert.equal(
      shouldDismissEdgeSwipe({ dx: 20, dy: 10, vx: 2000, vy: 0 }),
      false
    );
  });

  it('snaps back when released short or pulled toward rest', () => {
    assert.equal(shouldDismissEdgeSwipe({ dx: 40, dy: 10, vx: 200, vy: 0 }), false);
    assert.equal(
      shouldDismissEdgeSwipe({ dx: 80, dy: 0, vx: -1200, vy: 0 }),
      false
    );
  });
});

describe('dismissTranslation', () => {
  it('continues in the swipe direction until the sheet is off-screen', () => {
    const down = dismissTranslation(0, 40, 390, 700);
    assert.ok(down.y > 700);
    assert.equal(down.x, 0);

    const diagonal = dismissTranslation(30, 40, 300, 400);
    const ratio = diagonal.y / diagonal.x;
    assert.ok(Math.abs(ratio - 40 / 30) < 0.001);
    assert.ok(Math.hypot(diagonal.x, diagonal.y) >= 500);
  });

  it('falls back to downward dismiss when there is no direction', () => {
    const rest = dismissTranslation(0, 0, 390, 700);
    assert.equal(rest.x, 0);
    assert.ok(rest.y > 0);
  });

  it('steers the fling along the drag velocity when it continues away from rest', () => {
    const fly = dismissTranslation(40, 10, 300, 400, 1200, 400);
    const dir = flingDirection(40, 10, 1200, 400);
    const mag = Math.hypot(fly.x, fly.y);
    assert.ok(Math.abs(fly.x / mag - dir.x) < 0.001);
    assert.ok(Math.abs(fly.y / mag - dir.y) < 0.001);
    assert.ok(Math.abs(dir.y / dir.x - 400 / 1200) < 0.001);
  });
});

describe('clamped fling', () => {
  it('clamps speed between the configured min and max', () => {
    assert.equal(clampedFlingSpeed(0, 0), edgeSwipeToDismissDefaults.minFlingSpeed);
    assert.equal(clampedFlingSpeed(200, 0), edgeSwipeToDismissDefaults.minFlingSpeed);
    assert.equal(clampedFlingSpeed(1800, 0), 1800);
    assert.equal(clampedFlingSpeed(4000, 0), edgeSwipeToDismissDefaults.maxFlingSpeed);
  });

  it('keeps fling duration inside the min/max window along the remaining path', () => {
    const slow = flingDuration({
      dx: 120,
      dy: 0,
      vx: 0,
      vy: 0,
      width: 390,
      height: 700,
    });
    const fast = flingDuration({
      dx: 80,
      dy: 40,
      vx: 4000,
      vy: 2000,
      width: 390,
      height: 700,
    });
    assert.ok(slow >= edgeSwipeToDismissDefaults.minFlingDuration);
    assert.ok(slow <= edgeSwipeToDismissDefaults.maxFlingDuration);
    assert.ok(fast >= edgeSwipeToDismissDefaults.minFlingDuration);
    assert.ok(fast <= edgeSwipeToDismissDefaults.maxFlingDuration);
    assert.ok(fast <= slow);
  });
});

describe('bottom swipe friction', () => {
  it('lags the finger a little without freezing the sheet', () => {
    const pulled = resistOffset(-80, 720);
    assert.ok(pulled < -70);
    assert.ok(pulled > -80);
    assert.equal(resistOffset(0), 0);
    assert.ok(resistOffset(80) > 0);
  });

  it('only resists bottom-overscroll follow, especially upward', () => {
    const edge = visualTranslation({ dx: 12, dy: -80, activation: 'edge' });
    assert.equal(edge.dx, 12);
    assert.equal(edge.dy, -80);

    const top = visualTranslation({ dx: 0, dy: 40, activation: 'topOverscroll' });
    assert.equal(top.dy, 40);

    const up = visualTranslation({ dx: 30, dy: -80, activation: 'bottomOverscroll' });
    assert.ok(Math.abs(up.dx) < 30);
    assert.ok(up.dy > -80);
    assert.ok(up.dy < -70);

    const down = visualTranslation({ dx: 0, dy: 40, activation: 'bottomOverscroll' });
    assert.equal(down.dy, 40);
  });
});

describe('defaults', () => {
  it('activates after a short movement so edge taps still click', () => {
    assert.equal(edgeSwipeToDismissDefaults.activationDistance, 8);
    assert.equal(edgeSwipeToDismissDefaults.dismissDistance, 120);
  });

  it('clamps fling speed so dismiss neither crawls nor teleports', () => {
    assert.equal(edgeSwipeToDismissDefaults.minFlingSpeed, 1100);
    assert.equal(edgeSwipeToDismissDefaults.maxFlingSpeed, 2800);
    assert.equal(edgeSwipeToDismissDefaults.minFlingDuration, 0.18);
    assert.equal(edgeSwipeToDismissDefaults.maxFlingDuration, 0.42);
    assert.equal(edgeSwipeToDismissDefaults.bottomSwipeStiffness, 720);
    assert.equal(edgeSwipeToDismissDefaults.cardCornerRadius, 16);
  });
});

describe('velocityFromSamples', () => {
  it('uses the recent sample window', () => {
    const samples = [
      { t: 0, x: 0, y: 0 },
      { t: 100, x: 10, y: 0 },
      { t: 160, x: 70, y: 0 },
    ];
    const { vx } = velocityFromSamples(samples, 160, 80);
    assert.ok(vx > 900);
  });

  it('treats a held pause as zero velocity instead of a stale flick', () => {
    const samples = [
      { t: 0, x: 0, y: 0 },
      { t: 1, x: 56, y: 40 },
    ];
    const { vx, vy } = velocityFromSamples(samples, 800, 80);
    assert.equal(vx, 0);
    assert.equal(vy, 0);
  });
});
