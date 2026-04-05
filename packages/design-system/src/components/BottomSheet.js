/**
 * BottomSheet Component
 * A bottom sheet component with backdrop blur and darkening effects
 * that intensify as the sheet approaches large detent size
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

import './BottomSheet.css';

export function BottomSheet({
  isOpen = false,
  onClose,
  detent = 'medium', // 'small', 'medium', 'large'
  onDetentChange,
  enableDrag = true,
  children,
  className = '',
  ...props
}) {
  const containerRef = React.useRef(null);
  const sheetRef = React.useRef(null);
  const startYRef = React.useRef(0);
  const currentYRef = React.useRef(0);
  const isDraggingRef = React.useRef(false);

  const detents = ['small', 'medium', 'large'];
  const detentHeights = {
    small: 0.3,
    medium: 0.5,
    large: 0.9,
  };

  const handleDragStart = (e) => {
    if (!enableDrag) return;
    
    const touch = e.type.includes('touch') ? e.touches[0] : e;
    startYRef.current = touch.clientY;
    currentYRef.current = touch.clientY;
    isDraggingRef.current = true;
    
    if (sheetRef.current) {
      sheetRef.current.style.transition = 'none';
    }
  };

  const handleDragMove = (e) => {
    if (!isDraggingRef.current || !enableDrag) return;
    
    const touch = e.type.includes('touch') ? e.touches[0] : e;
    currentYRef.current = touch.clientY;
    
    const deltaY = currentYRef.current - startYRef.current;
    
    if (deltaY > 0 && sheetRef.current) {
      const transform = `translateY(${deltaY}px)`;
      sheetRef.current.style.transform = transform;
      
      const currentDetentIndex = detents.indexOf(detent);
      const viewportHeight = window.innerHeight;
      const dragPercentage = deltaY / viewportHeight;
      
      if (dragPercentage > 0.1 && currentDetentIndex > 0) {
        const newDetent = detents[currentDetentIndex - 1];
        if (onDetentChange && newDetent !== detent) {
          onDetentChange(newDetent);
        }
      }
    }
  };

  const handleDragEnd = () => {
    if (!isDraggingRef.current || !enableDrag) return;
    
    isDraggingRef.current = false;
    
    if (sheetRef.current) {
      sheetRef.current.style.transition = '';
      sheetRef.current.style.transform = '';
    }
    
    const deltaY = currentYRef.current - startYRef.current;
    const viewportHeight = window.innerHeight;
    
    if (deltaY > viewportHeight * 0.2) {
      if (onClose) {
        onClose();
      }
    }
  };

  React.useEffect(() => {
    if (enableDrag && isOpen) {
      document.addEventListener('mousemove', handleDragMove);
      document.addEventListener('touchmove', handleDragMove);
      document.addEventListener('mouseup', handleDragEnd);
      document.addEventListener('touchend', handleDragEnd);
      
      return () => {
        document.removeEventListener('mousemove', handleDragMove);
        document.removeEventListener('touchmove', handleDragMove);
        document.removeEventListener('mouseup', handleDragEnd);
        document.removeEventListener('touchend', handleDragEnd);
      };
    }
  }, [isOpen, enableDrag, detent]);

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
        className={backdropClasses}
        onClick={onClose}
      />
      <div 
        ref={sheetRef}
        className={sheetClasses}
      >
        <div 
          className="min-bottom-sheet__handle-container"
          onMouseDown={handleDragStart}
          onTouchStart={handleDragStart}
        >
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
