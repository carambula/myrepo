/**
 * React Native — primary title in the main content column (mov min).
 * Parent should already apply horizontal page inset (same as MinPageMargins); this only sets type + bottom margin.
 * @see native/MinTitleTypography.swift
 */

import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { MIN_MAIN_CONTENT_TITLE } from '../tokens/minTitles.js';

const base = StyleSheet.create({
  text: {
    fontSize: MIN_MAIN_CONTENT_TITLE.fontSize,
    fontWeight: String(MIN_MAIN_CONTENT_TITLE.fontWeight),
    lineHeight: MIN_MAIN_CONTENT_TITLE.lineHeight,
    letterSpacing: MIN_MAIN_CONTENT_TITLE.letterSpacing,
    textAlign: 'left',
    alignSelf: 'stretch',
  },
});

export function MainContentTitle({
  children,
  style,
  marginBottom = MIN_MAIN_CONTENT_TITLE.marginBottom,
  /** Override for light/dark; host apps should pass theme primary text color */
  color = '#212121',
  ...props
}) {
  return (
    <Text
      style={[base.text, { marginBottom, color }, style]}
      accessibilityRole="header"
      {...props}
    >
      {children}
    </Text>
  );
}

export default MainContentTitle;
