/**
 * Shadow tokens for the min apps design system
 * Provides elevation through consistent shadow values
 */

export const shadows = {
  none: 'none',
  
  // Subtle shadows
  xs: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  sm: '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)',
  
  // Default shadows
  md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
  lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
  xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
  
  // Strong shadows
  '2xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
  
  // Inner shadow
  inner: 'inset 0 2px 4px 0 rgba(0, 0, 0, 0.06)',
  
  // Semantic shadows
  card: '0 2px 8px rgba(0, 0, 0, 0.1)',
  cardHover: '0 8px 16px rgba(0, 0, 0, 0.15)',
  button: '0 2px 4px rgba(0, 0, 0, 0.1)',
  buttonHover: '0 4px 8px rgba(0, 0, 0, 0.15)',
  modal: '0 20px 25px -5px rgba(0, 0, 0, 0.2), 0 10px 10px -5px rgba(0, 0, 0, 0.1)',
  dropdown: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
};

export default shadows;
