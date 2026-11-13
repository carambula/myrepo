/**
 * BottomSheet Component
 * A bottom sheet component with backdrop blur and darkening effects
 * that intensify as the sheet approaches large detent size.
 *
 * Edge swipes (from the sheet's top, sides, or bottom) drag the sheet
 * omnidirectionally until it is flung away or released back to rest.
 *
 * Usage:
 * import { BottomSheet } from '@min-apps/design-system/components';
 * import '@min-apps/design-system/components/BottomSheet.css';
 *
 * <BottomSheet
 *   isOpen={isOpen}
 *   onClose={handleClose}
 *   detent="large"
 *   onDetentChange={handleDetentChange}
 * >
 *   Content goes here
 * </BottomSheet>
 */

import React, { useEffect, useRef } from 'react';
import './BottomSheet.css';
import {
  dismissTranslation,
  edgeSwipeToDismissDefaults,
  flingDuration,
  isOnSheetEdge,
  isScrollAtBottom,
  isScrollAtTop,
  nearestScrollable,
  scrollLimitActivation,
  sheetTransform,
  shouldDismissEdgeSwipe,
  swipeBackdropBlurPx,
  swipeBackdropOpacity,
  swipeProgress,
  velocityFromSamples,
  visualTranslation,
} from './edgeSwipeToDismiss.js';

export function BottomSheet({
  isOpen = false,
  onClose,
  detent = 'medium', // 'small', 'medium', 'large'
  onDetentChange,
  enableDrag = true,
  enableEdgeSwipe = true,
  children,
  className = '',
  ...props
}) {
  const containerRef = useRef(null);
  const sheetRef = useRef(null);
  const backdropRef = useRef(null);
  const startRef = useRef({ x: 0, y: 0 });
  const currentRef = useRef({ x: 0, y: 0 });
  const samplesRef = useRef([]);
  const pendingRef = useRef(false);
  const isDraggingRef = useRef(false);
  const isEdgeSwipeRef = useRef(false);
  const activationRef = useRef(null);
  const isDismissingRef = useRef(false);
  const pointerIdRef = useRef(null);
  const scrollRef = useRef(null);

  const resetSheetStyles = () => {
    const sheet = sheetRef.current;
    const backdrop = backdropRef.current;
    if (sheet) {
      sheet.style.transition = '';
      sheet.style.transform = '';
      sheet.style.opacity = '';
      sheet.classList.remove('min-bottom-sheet--dragging');
    }
    if (backdrop) {
      backdrop.style.transition = '';
      backdrop.style.opacity = '';
      backdrop.style.backdropFilter = '';
      backdrop.style.webkitBackdropFilter = '';
    }
  };

  const applyFollow = (dx, dy) => {
    const sheet = sheetRef.current;
    const backdrop = backdropRef.current;
    if (!sheet) return;
    const progress = swipeProgress(dx, dy);
    sheet.style.transform = sheetTransform({ dx, dy, progress });
    if (backdrop) {
      const opacity = swipeBackdropOpacity(progress);
      const blurPx = swipeBackdropBlurPx(progress);
      backdrop.style.opacity = String(opacity);
      backdrop.style.backdropFilter = `blur(${blurPx}px)`;
      backdrop.style.webkitBackdropFilter = `blur(${blurPx}px)`;
    }
  };

  const pointerFromEvent = (e) => {
    if (e.touches && e.touches[0]) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    if (e.changedTouches && e.changedTouches[0]) {
      return { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  };

  const recordSample = (point) => {
    const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
    const samples = samplesRef.current;
    samples.push({ t: now, x: point.x, y: point.y });
    const cutoff = now - edgeSwipeToDismissDefaults.sampleWindowMs;
    samplesRef.current = samples.filter((s) => s.t >= cutoff);
  };

  const handleDragStart = (e) => {
    if (!enableDrag || !isOpen || isDismissingRef.current) return;
    const sheet = sheetRef.current;
    if (!sheet) return;

    const fromHandle = Boolean(
      e.target?.closest?.('.min-bottom-sheet__handle-container')
    );
    const point = pointerFromEvent(e);
    const rect = sheet.getBoundingClientRect();
    const localX = point.x - rect.left;
    const localY = point.y - rect.top;
    const onEdge =
      enableEdgeSwipe &&
      isOnSheetEdge(localX, localY, rect.width, rect.height);
    const scroll = nearestScrollable(e.target, sheet);
    scrollRef.current = scroll;

    if (!fromHandle && !onEdge) {
      startRef.current = point;
      currentRef.current = point;
      samplesRef.current = [];
      recordSample(point);
      pendingRef.current = true;
      isDraggingRef.current = false;
      isEdgeSwipeRef.current = false;
      activationRef.current = null;
      pointerIdRef.current = e.pointerId ?? null;
      return;
    }

    startRef.current = point;
    currentRef.current = point;
    samplesRef.current = [];
    recordSample(point);
    pendingRef.current = true;
    isDraggingRef.current = false;
    isEdgeSwipeRef.current = onEdge || fromHandle;
    activationRef.current = onEdge || fromHandle ? 'edge' : null;
    pointerIdRef.current = e.pointerId ?? null;
  };

  const beginDrag = (sheet) => {
    isDraggingRef.current = true;
    pendingRef.current = false;
    sheet.classList.add('min-bottom-sheet--dragging');
    sheet.style.transition = 'none';
    if (backdropRef.current) {
      backdropRef.current.style.transition = 'none';
    }
    const pointerId = pointerIdRef.current;
    if (pointerId != null && sheet.setPointerCapture) {
      try {
        sheet.setPointerCapture(pointerId);
      } catch {
        // Capture is best-effort; document listeners still track the pointer.
      }
    }
  };

  const handleDragMove = (e) => {
    if (!enableDrag) return;
    const sheet = sheetRef.current;
    if (!sheet) return;

    const point = pointerFromEvent(e);
    const dx = point.x - startRef.current.x;
    const dy = point.y - startRef.current.y;

    if (pendingRef.current && !isDraggingRef.current) {
      if (!isEdgeSwipeRef.current) {
        const scroll = scrollRef.current;
        const activation = scrollLimitActivation({
          dx,
          dy,
          atTop: isScrollAtTop(scroll),
          atBottom: isScrollAtBottom(scroll),
        });
        if (activation) {
          startRef.current = point;
          currentRef.current = point;
          isEdgeSwipeRef.current = true;
          activationRef.current = activation;
          beginDrag(sheet);
          applyFollow(0, 0);
          return;
        }
        if (Math.hypot(dx, dy) >= edgeSwipeToDismissDefaults.activationDistance) {
          pendingRef.current = false;
        }
        return;
      }
      if (
        activationRef.current !== 'edge' &&
        Math.hypot(dx, dy) < edgeSwipeToDismissDefaults.activationDistance
      ) {
        return;
      }
      beginDrag(sheet);
    }

    if (!isDraggingRef.current) return;

    currentRef.current = point;
    recordSample(point);

    if (isEdgeSwipeRef.current) {
      if (e.cancelable) e.preventDefault();
      const visual = visualTranslation({
        dx,
        dy,
        activation: activationRef.current,
      });
      applyFollow(visual.dx, visual.dy);
      return;
    }

    if (dy > 0) {
      sheet.style.transform = `translateY(${dy}px)`;
    }
  };

  const handleDragEnd = () => {
    pendingRef.current = false;
    if (!isDraggingRef.current || !enableDrag) return;
    isDraggingRef.current = false;

    const dx = currentRef.current.x - startRef.current.x;
    const dy = currentRef.current.y - startRef.current.y;
    recordSample(currentRef.current);
    const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
    const { vx, vy } = velocityFromSamples(samplesRef.current, now);
    const sheet = sheetRef.current;
    const wasEdgeSwipe = isEdgeSwipeRef.current;
    const activation = activationRef.current;
    isEdgeSwipeRef.current = false;
    activationRef.current = null;

    if (wasEdgeSwipe && shouldDismissEdgeSwipe({ dx, dy, vx, vy })) {
      const width = sheet?.offsetWidth || window.innerHeight;
      const height = sheet?.offsetHeight || window.innerHeight;
      const visual = visualTranslation({ dx, dy, activation });
      const fly = dismissTranslation(dx, dy, width, height, vx, vy);
      const duration = flingDuration({ dx, dy, vx, vy, width, height });
      const ms = Math.max(1, Math.round(duration * 1000));
      const easing = `transform ${ms}ms cubic-bezier(0.16, 1, 0.3, 1), opacity ${ms}ms cubic-bezier(0.16, 1, 0.3, 1)`;
      isDismissingRef.current = true;
      if (sheet) {
        sheet.style.transition = easing;
        sheet.style.transform = sheetTransform({
          dx: visual.dx,
          dy: visual.dy,
          progress: 1,
          dismissing: true,
          dismissX: fly.x,
          dismissY: fly.y,
        });
        sheet.style.opacity = '0';
      }
      if (backdropRef.current) {
        backdropRef.current.style.transition = `opacity ${ms}ms cubic-bezier(0.16, 1, 0.3, 1)`;
        backdropRef.current.style.opacity = '0';
      }
      window.setTimeout(() => {
        isDismissingRef.current = false;
        resetSheetStyles();
        onClose?.();
      }, ms);
      return;
    }

    if (sheet) {
      sheet.style.transition = '';
      sheet.style.transform = '';
      sheet.classList.remove('min-bottom-sheet--dragging');
    }
    if (backdropRef.current) {
      backdropRef.current.style.transition = '';
      backdropRef.current.style.opacity = '';
    }

    if (!wasEdgeSwipe && dy > window.innerHeight * 0.2) {
      onClose?.();
    }
  };

  useEffect(() => {
    if (!enableDrag || !isOpen) return undefined;

    const move = (e) => handleDragMove(e);
    const end = (e) => {
      if (e) {
        const point = pointerFromEvent(e);
        currentRef.current = point;
      }
      handleDragEnd();
    };
    const opts = { capture: true, passive: false };
    window.addEventListener('pointermove', move, opts);
    window.addEventListener('mousemove', move, opts);
    window.addEventListener('touchmove', move, opts);
    window.addEventListener('pointerup', end, opts);
    window.addEventListener('mouseup', end, opts);
    window.addEventListener('touchend', end, opts);
    window.addEventListener('pointercancel', end, opts);

    return () => {
      window.removeEventListener('pointermove', move, opts);
      window.removeEventListener('mousemove', move, opts);
      window.removeEventListener('touchmove', move, opts);
      window.removeEventListener('pointerup', end, opts);
      window.removeEventListener('mouseup', end, opts);
      window.removeEventListener('touchend', end, opts);
      window.removeEventListener('pointercancel', end, opts);
    };
  }, [isOpen, enableDrag, enableEdgeSwipe]);

  useEffect(() => {
    if (!isOpen) {
      pendingRef.current = false;
      isDraggingRef.current = false;
      isEdgeSwipeRef.current = false;
      activationRef.current = null;
      isDismissingRef.current = false;
      resetSheetStyles();
    }
  }, [isOpen]);

  const backdropClasses = [
    'min-bottom-sheet__backdrop',
    isOpen ? `min-bottom-sheet__backdrop--${detent}` : 'min-bottom-sheet__backdrop--hidden',
  ].join(' ');

  const sheetClasses = [
    'min-bottom-sheet',
    `min-bottom-sheet--${detent}`,
    !isOpen && 'min-bottom-sheet--closed',
  ].filter(Boolean).join(' ');

  const containerClasses = [
    'min-bottom-sheet-container',
    isOpen && 'min-bottom-sheet-container--open',
    className,
  ].filter(Boolean).join(' ');

  return (
    <div ref={containerRef} className={containerClasses} {...props}>
      <div
        ref={backdropRef}
        className={backdropClasses}
        onClick={onClose}
      />
      <div
        ref={sheetRef}
        className={sheetClasses}
        onPointerDown={handleDragStart}
        onMouseDown={handleDragStart}
      >
        <div className="min-bottom-sheet__handle-container">
          <div className="min-bottom-sheet__handle" />
        </div>
        <div className="min-bottom-sheet__content">
          {children}
        </div>
      </div>
    </div>
  );
}

export default BottomSheet;
