/**
 * React Native hook: returns the mov min page margins for the current window width.
 * Compact (< 768 logical px) uses mobile tokens; wider uses regular.
 *
 * Usage (every screen root — vid min, pod min, cyc min, mov min):
 *
 *   import { usePageMargins } from '@min-apps/design-system/react-native';
 *
 *   function MyScreen() {
 *     const margins = usePageMargins();
 *     return (
 *       <ScrollView contentContainerStyle={{ padding: margins.top, paddingHorizontal: margins.horizontal }}>
 *         ...
 *       </ScrollView>
 *     );
 *   }
 */

import { useWindowDimensions } from 'react-native';
import { spacing } from '../tokens/spacing.js';

function px(v) {
  const n = Number.parseFloat(String(v).replace(/px\s*$/i, ''));
  return Number.isFinite(n) ? n : 0;
}

export function usePageMargins() {
  const { width } = useWindowDimensions();
  const compact = width < 768;
  const p = spacing.page;

  if (compact) {
    return {
      compact: true,
      top: px(p.marginTopMobile),
      bottom: px(p.marginBottomMobile),
      left: px(p.marginLeftMobile),
      right: px(p.marginRightMobile),
      horizontal: px(p.marginLeftMobile),
      vertical: px(p.marginTopMobile),
    };
  }

  return {
    compact: false,
    top: px(p.marginTop),
    bottom: px(p.marginBottom),
    left: px(p.marginLeft),
    right: px(p.marginRight),
    horizontal: px(p.marginLeft),
    vertical: px(p.marginTop),
  };
}

export default usePageMargins;
