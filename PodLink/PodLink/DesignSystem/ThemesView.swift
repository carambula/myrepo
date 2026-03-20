import SwiftUI

struct ThemesView: View {
    var isOnboarding: Bool = false

    @Environment(ThemeManager.self) private var themeManager

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: DesignSystem.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
                ForEach(themeManager.allThemes, id: \.id) { theme in
                    themeCard(theme)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .navigationTitle(isOnboarding ? "" : "Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeCard(_ theme: any AppTheme) -> some View {
        let isSelected = themeManager.currentTheme.id == theme.id

        return Button {
            withAnimation(DesignSystem.Animation.standard) {
                themeManager.selectTheme(theme)
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Color preview
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading) {
                        Text("Aa")
                            .font(.system(
                                size: 18,
                                weight: theme.headlineFontWeight,
                                design: theme.headlineFontDesign
                            ))
                            .foregroundColor(theme.headlineColor ?? DesignSystem.Colors.textPrimary)
                    }
                }

                Text(theme.name)
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(theme.backgroundTint.opacity(0.3))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .strokeBorder(theme.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
