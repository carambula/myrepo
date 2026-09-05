import SwiftUI

public struct MinThemeCardPressStyle: ButtonStyle {
    public let accent: Color
    public let isSelected: Bool

    public init(accent: Color, isSelected: Bool) {
        self.accent = accent
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 1.25 : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.35
            )
            .overlay(
                RoundedRectangle(cornerRadius: MinCornerRadius.xl, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.15 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MinCornerRadius.xl, style: .continuous)
                    .stroke(accent.opacity(isSelected ? 0.5 : (configuration.isPressed ? 0.32 : 0)), lineWidth: 1.5)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
