/**
 * Button Component
 * Standardized button with consistent styling across all min apps
 */

import { spacing, typography, borders, shadows, transitions } from '../tokens/index.js';

export function Button({
  children,
  variant = 'primary',
  size = 'medium',
  fullWidth = false,
  disabled = false,
  onClick,
  type = 'button',
  className = '',
  ...props
}) {
  const baseStyles = `
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: ${spacing.button.gap};
    font-family: ${typography.fonts.primary};
    font-size: ${typography.styles.button.fontSize};
    font-weight: ${typography.styles.button.fontWeight};
    letter-spacing: ${typography.styles.button.letterSpacing};
    line-height: ${typography.styles.button.lineHeight};
    border: none;
    border-radius: ${borders.radii.md};
    cursor: ${disabled ? 'not-allowed' : 'pointer'};
    transition: ${transitions.all};
    opacity: ${disabled ? '0.5' : '1'};
    ${fullWidth ? 'width: 100%;' : ''}
  `;
  
  const sizeStyles = {
    small: `
      padding: ${spacing[2]} ${spacing[4]};
      font-size: ${typography.sizes.sm};
    `,
    medium: `
      padding: ${spacing.button.paddingY} ${spacing.button.paddingX};
    `,
    large: `
      padding: ${spacing[4]} ${spacing[8]};
      font-size: ${typography.sizes.lg};
    `,
  };
  
  const variantStyles = {
    primary: `
      background-color: var(--color-primary-main);
      color: var(--color-primary-contrast);
      box-shadow: ${shadows.button};
      
      &:hover:not(:disabled) {
        background-color: var(--color-primary-dark);
        box-shadow: ${shadows.buttonHover};
        transform: translateY(-1px);
      }
      
      &:active:not(:disabled) {
        transform: translateY(0);
        box-shadow: ${shadows.button};
      }
    `,
    secondary: `
      background-color: var(--color-secondary-main);
      color: var(--color-secondary-contrast);
      box-shadow: ${shadows.button};
      
      &:hover:not(:disabled) {
        background-color: var(--color-secondary-dark);
        box-shadow: ${shadows.buttonHover};
        transform: translateY(-1px);
      }
      
      &:active:not(:disabled) {
        transform: translateY(0);
        box-shadow: ${shadows.button};
      }
    `,
    outline: `
      background-color: transparent;
      color: var(--color-primary-main);
      border: ${borders.widths.medium} ${borders.styles.solid} var(--color-primary-main);
      
      &:hover:not(:disabled) {
        background-color: var(--color-primary-main);
        color: var(--color-primary-contrast);
      }
    `,
    ghost: `
      background-color: transparent;
      color: var(--color-primary-main);
      
      &:hover:not(:disabled) {
        background-color: var(--color-hover-primary);
      }
    `,
    text: `
      background-color: transparent;
      color: var(--color-primary-main);
      box-shadow: none;
      
      &:hover:not(:disabled) {
        background-color: var(--color-hover-primary);
      }
    `,
  };
  
  return {
    element: 'button',
    type,
    disabled,
    onClick: disabled ? undefined : onClick,
    className: `min-button min-button--${variant} min-button--${size} ${className}`.trim(),
    style: baseStyles + sizeStyles[size] + variantStyles[variant],
    children,
    ...props,
  };
}

export default Button;
