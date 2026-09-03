/**
 * useScrollDismiss Hook
 * 
 * Tracks scroll position to determine when to show and expand the dismiss button.
 * 
 * Features:
 * - Detects when user has scrolled down (show button)
 * - Detects when user has scrolled to bottom (expand button)
 * - Provides debounced scroll state
 * - Optimized for performance with requestAnimationFrame
 * 
 * Usage:
 * const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef, {
 *   scrollThreshold: 100,
 *   bottomThreshold: 50,
 * });
 */

import { useState, useEffect, useCallback, useRef } from 'react';

export function useScrollDismiss(scrollContainerRef, options = {}) {
  const {
    scrollThreshold = 100, // How far to scroll before showing button
    bottomThreshold = 50,  // Distance from bottom to trigger expansion
  } = options;

  const [isScrolled, setIsScrolled] = useState(false);
  const [isAtBottom, setIsAtBottom] = useState(false);
  const ticking = useRef(false);

  const handleScroll = useCallback(() => {
    if (!ticking.current) {
      window.requestAnimationFrame(() => {
        const container = scrollContainerRef?.current;
        
        if (!container) {
          ticking.current = false;
          return;
        }

        const scrollTop = container.scrollTop;
        const scrollHeight = container.scrollHeight;
        const clientHeight = container.clientHeight;
        
        // Check if scrolled past threshold
        const scrolledPastThreshold = scrollTop > scrollThreshold;
        setIsScrolled(scrolledPastThreshold);
        
        // Check if near bottom
        const distanceFromBottom = scrollHeight - (scrollTop + clientHeight);
        const nearBottom = distanceFromBottom <= bottomThreshold;
        setIsAtBottom(scrolledPastThreshold && nearBottom);
        
        ticking.current = false;
      });
    }
    ticking.current = true;
  }, [scrollContainerRef, scrollThreshold, bottomThreshold]);

  useEffect(() => {
    const container = scrollContainerRef?.current;
    if (!container) return;

    container.addEventListener('scroll', handleScroll, { passive: true });
    
    // Check initial state
    handleScroll();

    return () => {
      container.removeEventListener('scroll', handleScroll);
    };
  }, [scrollContainerRef, handleScroll]);

  return {
    isScrolled,
    isAtBottom,
  };
}

export default useScrollDismiss;
