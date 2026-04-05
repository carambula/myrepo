/**
 * React Native — canonical main bootstrap loader (same as mov min).
 * Metro resolves this file instead of MainAppLoading.js for iOS/Android.
 * @see docs/main-app-loading-native.md
 */

import React from 'react';
import {
  View,
  Text,
  ActivityIndicator,
  StyleSheet,
  useWindowDimensions,
} from 'react-native';
import { spacing } from '../tokens/spacing.js';
import {
  MAIN_LOADING_MESSAGE,
  MAIN_LOADING_SPINNER_SIZE,
  MAIN_LOADING_ROW_GAP,
  MAIN_LOADING_LABEL_FONT_SIZE,
  MAIN_LOADING_PADDING_VERTICAL,
  MAIN_LOADING_LABEL_COLOR_LIGHT,
  MAIN_LOADING_SPINNER_COLOR_LIGHT,
} from '../tokens/mainLoading.js';

function horizontalPageMargin(width) {
  const compact = width < 768;
  const key = compact ? 'marginLeftMobile' : 'marginLeft';
  const raw = spacing.page[key];
  const n = Number.parseFloat(String(raw).replace(/px\s*$/i, ''));
  return Number.isFinite(n) ? n : compact ? 12 : 16;
}

export function MainAppLoading({
  message = MAIN_LOADING_MESSAGE,
  style,
  textColor = MAIN_LOADING_LABEL_COLOR_LIGHT,
  spinnerColor = MAIN_LOADING_SPINNER_COLOR_LIGHT,
  ...props
}) {
  const { width } = useWindowDimensions();
  const padX = horizontalPageMargin(width);

  return (
    <View
      style={[styles.root, { paddingHorizontal: padX }, style]}
      accessibilityRole="text"
      accessibilityLabel={message}
      {...props}
    >
      <View
        style={[
          styles.spinnerWrap,
          {
            width: MAIN_LOADING_SPINNER_SIZE,
            height: MAIN_LOADING_SPINNER_SIZE,
            marginRight: MAIN_LOADING_ROW_GAP,
          },
        ]}
      >
        <ActivityIndicator size="small" color={spinnerColor} />
      </View>
      <Text style={[styles.label, { color: textColor, fontSize: MAIN_LOADING_LABEL_FONT_SIZE }]}>
        {message}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-start',
    alignSelf: 'flex-start',
    paddingVertical: MAIN_LOADING_PADDING_VERTICAL,
  },
  spinnerWrap: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  label: {
    textAlign: 'left',
    flexShrink: 1,
  },
});

export default MainAppLoading;
