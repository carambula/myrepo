//
//  ThemeBackgroundModifier.swift
//  Cyclismo
//
//  View Modifier for Theme-Aware Backgrounds.
//

import SwiftUI

struct ThemeBackgroundModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Color.background)
            .tint(DesignSystem.Color.accent)
            .preferredColorScheme(themeManager.currentTheme.supportsLightMode ? nil : .dark)
            #if os(iOS)
            .toolbarBackground(DesignSystem.Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
    }
}

extension View {
    func themeBackground() -> some View {
        self.modifier(ThemeBackgroundModifier())
    }
}
