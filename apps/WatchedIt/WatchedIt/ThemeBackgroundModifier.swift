//
//  ThemeBackgroundModifier.swift
//  WatchedIt
//
//  View Modifier for Theme-Aware Backgrounds
//

import SwiftUI

struct ThemeBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Color.background)
    }
}

extension View {
    func themeBackground() -> some View {
        self.modifier(ThemeBackgroundModifier())
    }
}





