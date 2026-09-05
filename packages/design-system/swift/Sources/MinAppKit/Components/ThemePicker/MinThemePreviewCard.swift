import SwiftUI

#if canImport(UIKit)
import UIKit

public struct MinThemePreviewCard: View {
    public let theme: any MinTheme
    public let colorScheme: ColorScheme
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(
        theme: any MinTheme,
        colorScheme: ColorScheme,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: MinCornerRadius.xl, style: .continuous)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: MinCornerRadius.xl, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.accent.opacity(0.14),
                                        (theme.secondaryAccent ?? theme.accent).opacity(0.08),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MinCornerRadius.xl, style: .continuous)
                            .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 3)
                    )
                    .shadow(
                        color: isSelected ? theme.accent.opacity(0.2) : MinShadow.md.color,
                        radius: isSelected ? MinShadow.lg.radius : MinShadow.md.radius,
                        x: 0,
                        y: isSelected ? 6 : MinShadow.md.y
                    )

                VStack(alignment: .leading, spacing: MinSpacing.md) {
                    HStack {
                        Text(theme.name)
                            .font(theme.headlineFont)
                            .foregroundColor(previewHeadlineColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer()
                    }
                    .padding(.bottom, MinSpacing.xs)

                    VStack(alignment: .leading, spacing: MinSpacing.sm) {
                        Capsule()
                            .fill(previewHeadlineColor.opacity(0.20))
                            .frame(width: 120, height: 10)
                        Capsule()
                            .fill(previewHeadlineColor.opacity(0.14))
                            .frame(width: 90, height: 8)
                        Capsule()
                            .fill(previewHeadlineColor.opacity(0.1))
                            .frame(width: 140, height: 8)
                    }
                    .padding(.bottom, MinSpacing.sm)

                    HStack(spacing: MinSpacing.sm) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: MinCornerRadius.md, style: .continuous)
                                .fill(tileColor(for: index))
                                .frame(maxWidth: .infinity)
                                .frame(height: 74)
                        }
                    }

                    Spacer()

                    HStack(spacing: MinSpacing.sm) {
                        swatch(theme.accent)
                        swatch(theme.secondaryAccent ?? theme.accent.opacity(0.35))
                    }
                }
                .padding(MinSpacing.lg)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: MinIcon.checkmark)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(MinSpacing.sm)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: MinCornerRadius.round, style: .continuous))
                        .padding(MinSpacing.md)
                }
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .buttonStyle(MinThemeCardPressStyle(accent: theme.accent, isSelected: isSelected))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(theme.name) theme preview")
    }

    private var cardBackgroundColor: Color {
        let useDark = colorScheme == .dark || !theme.supportsLightMode
        if useDark {
            return theme.darkModeBackground ?? Color(UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
        }
        return theme.lightModeBackground ?? Color(UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }

    private var previewHeadlineColor: Color {
        let useDark = colorScheme == .dark || !theme.supportsLightMode
        if useDark {
            return theme.darkModeHeadlineColor ?? theme.headlineColor
        }
        return theme.lightModeHeadlineColor ?? theme.headlineColor
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
    }

    private func tileColor(for index: Int) -> Color {
        let secondary = theme.secondaryAccent ?? theme.accent
        switch index {
        case 0: return theme.accent.opacity(0.42)
        case 1: return secondary.opacity(0.34)
        default: return previewHeadlineColor.opacity(0.24)
        }
    }
}
#endif
