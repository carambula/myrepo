/**
 * Input Component
 * Standardized text input with consistent styling
 */

import { spacing, typography, borders, transitions } from '../tokens/index.js';

export function Input({
  type = 'text',
  placeholder,
  value,
  onChange,
  disabled = false,
  error = false,
  label,
  helperText,
  fullWidth = false,
  className = '',
  ...props
}) {
  const wrapperStyles = `
    display: flex;
    flex-direction: column;
    gap: ${spacing[2]};
    ${fullWidth ? 'width: 100%;' : ''}
  `;
  
  const labelStyles = `
    font-size: ${typography.styles.label.fontSize};
    font-weight: ${typography.styles.label.fontWeight};
    color: var(--color-text-primary);
    margin: 0;
  `;
  
  const inputStyles = `
    padding: ${spacing[3]} ${spacing[4]};
    font-size: ${typography.styles.body.fontSize};
    font-family: ${typography.fonts.primary};
    color: var(--color-text-primary);
    background-color: var(--color-surface-primary);
    border: ${borders.widths.thin} ${borders.styles.solid} var(--color-border-primary);
    border-radius: ${borders.radii.md};
    transition: ${transitions.all};
    outline: none;
    ${fullWidth ? 'width: 100%;' : ''}
    ${error ? `border-color: var(--color-error-main);` : ''}
    
    &:focus {
      border-color: var(--color-border-focus);
      box-shadow: 0 0 0 3px var(--color-focus-background);
    }
    
    &:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      background-color: var(--color-background-secondary);
    }
    
    &::placeholder {
      color: var(--color-text-tertiary);
    }
  `;
  
  const helperTextStyles = `
    font-size: ${typography.styles.caption.fontSize};
    color: ${error ? 'var(--color-error-main)' : 'var(--color-text-secondary)'};
    margin: 0;
  `;
  
  return {
    element: 'div',
    className: `min-input-wrapper ${className}`.trim(),
    style: wrapperStyles,
    children: [
      label && {
        element: 'label',
        style: labelStyles,
        className: 'min-input__label',
        children: label,
      },
      {
        element: 'input',
        type,
        placeholder,
        value,
        onChange,
        disabled,
        style: inputStyles,
        className: `min-input ${error ? 'min-input--error' : ''}`.trim(),
        ...props,
      },
      helperText && {
        element: 'p',
        style: helperTextStyles,
        className: 'min-input__helper-text',
        children: helperText,
      },
    ].filter(Boolean),
  };
}

export default Input;
