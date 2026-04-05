import SwiftUI
import MinAppKit

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewThemeID: String

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        _previewThemeID = State(initialValue: themeManager.selectedThemeID)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            TabView(selection: $previewThemeID) {
                ForEach(themeManager.availableThemes) { theme in
                    MinThemePreviewCard(
                        theme: theme,
                        colorScheme: colorScheme,
                        isSelected: theme.id == themeManager.selectedThemeID,
                        onSelect: {
                            previewThemeID = theme.id
                            themeManager.select(themeID: theme.id)
                        }
                    )
                    .tag(theme.id)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 440)

            MinThemePageDots(
                count: themeManager.availableThemes.count,
                currentIndex: themeManager.availableThemes.firstIndex(where: { $0.id == previewThemeID }) ?? 0,
                accentColor: themeManager.currentTheme.accent
            )

            Spacer(minLength: 0)
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .themeBackground(using: themeManager.currentTheme)
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.checkmark)
                        .viewControlIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
        }
        .onAppear {
            previewThemeID = themeManager.selectedThemeID
        }
    }
}
