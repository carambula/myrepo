/**
 * Transition tokens for the min apps design system
 * Defines animation durations, easing functions, and common transitions
 */

export const transitions = {
  // Durations
  durations: {
    instant: '0ms',
    fast: '150ms',
    normal: '250ms',
    slow: '350ms',
    slower: '500ms',
  },
  
  // Easing functions
  easings: {
    linear: 'linear',
    easeIn: 'cubic-bezier(0.4, 0, 1, 1)',
    easeOut: 'cubic-bezier(0, 0, 0.2, 1)',
    easeInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
    sharp: 'cubic-bezier(0.4, 0, 0.6, 1)',
  },
  
  // Common transitions
  all: 'all 250ms cubic-bezier(0.4, 0, 0.2, 1)',
  color: 'color 250ms cubic-bezier(0.4, 0, 0.2, 1)',
  background: 'background-color 250ms cubic-bezier(0.4, 0, 0.2, 1)',
  transform: 'transform 250ms cubic-bezier(0.4, 0, 0.2, 1)',
  opacity: 'opacity 250ms cubic-bezier(0.4, 0, 0.2, 1)',
  shadow: 'box-shadow 250ms cubic-bezier(0.4, 0, 0.2, 1)',
};

export default transitions;
