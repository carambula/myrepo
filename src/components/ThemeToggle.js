/**
 * ThemeToggle Component
 * Button to toggle between light and dark themes
 */

import { spacing, borders, transitions } from '../tokens/index.js';

export function ThemeToggle({
  currentTheme = 'light',
  onToggle,
  className = '',
  ...props
}) {
  const buttonStyles = `
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    padding: ${spacing[2]};
    background-color: var(--color-surface-primary);
    border: ${borders.widths.thin} ${borders.styles.solid} var(--color-border-primary);
    border-radius: ${borders.radii.full};
    cursor: pointer;
    transition: ${transitions.all};
    
    &:hover {
      background-color: var(--color-hover-primary);
      transform: scale(1.05);
    }
    
    &:active {
      transform: scale(0.95);
    }
  `;
  
  const iconStyles = `
    width: 20px;
    height: 20px;
    color: var(--color-text-primary);
  `;
  
  const sunIcon = `
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="5"/>
      <line x1="12" y1="1" x2="12" y2="3"/>
      <line x1="12" y1="21" x2="12" y2="23"/>
      <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/>
      <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>
      <line x1="1" y1="12" x2="3" y2="12"/>
      <line x1="21" y1="12" x2="23" y2="12"/>
      <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/>
      <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
    </svg>
  `;
  
  const moonIcon = `
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
    </svg>
  `;
  
  return {
    element: 'button',
    type: 'button',
    onClick: onToggle,
    className: `min-theme-toggle ${className}`.trim(),
    style: buttonStyles,
    'aria-label': `Switch to ${currentTheme === 'light' ? 'dark' : 'light'} theme`,
    innerHTML: currentTheme === 'light' ? moonIcon : sunIcon,
    ...props,
  };
}

export default ThemeToggle;
