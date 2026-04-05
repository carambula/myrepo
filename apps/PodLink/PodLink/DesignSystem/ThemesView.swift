import SwiftUI
import MinAppKit

struct ThemesView: View {
    var isOnboarding: Bool = false

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var previewThemeID: String
    @State private var isShowingThemeBuilder = false
    @State private var editingTheme: CustomTheme?

    init(isOnboarding: Bool = false) {
        self.isOnboarding = isOnboarding
        _previewThemeID = State(initialValue: ThemeManager.shared.currentTheme.id)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            TabView(selection: $previewThemeID) {
                ForEach(themeManager.allThemes, id: \.id) { theme in
                    MinThemePreviewCard(
                        theme: theme,
                        colorScheme: colorScheme,
                        isSelected: themeManager.currentTheme.id == theme.id,
                        onSelect: {
                            withAnimation(DesignSystem.Animation.standard) {
                                themeManager.selectTheme(theme)
                            }
                        }
                    )
                    .tag(theme.id)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .frame(height: 440)

            MinThemePageDots(
                count: themeManager.allThemes.count,
                currentIndex: themeManager.allThemes.firstIndex(where: { $0.id == previewThemeID }) ?? 0,
                accentColor: themeManager.currentTheme.accentColor
            )

            if !isOnboarding, let custom = previewedCustomTheme {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button {
                        editingTheme = custom
                        isShowingThemeBuilder = true
                    } label: {
                        Label("Edit Theme", systemImage: DesignSystem.Icon.edit)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        themeManager.removeCustomTheme(custom)
                        previewThemeID = themeManager.currentTheme.id
                    } label: {
                        Label("Delete Theme", systemImage: DesignSystem.Icon.delete)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isOnboarding {
                Text("Pick a look—you can change it anytime in Account → Themes.")
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .themeBackground()
        .navigationTitle(isOnboarding ? "" : "Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        editingTheme = nil
                        isShowingThemeBuilder = true
                    } label: {
                        Image(systemName: DesignSystem.Icon.add)
                            .viewControlIconStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create theme")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
        }
        .sheet(isPresented: $isShowingThemeBuilder) {
            NavigationStack {
                ThemeBuilderView(editingTheme: editingTheme)
                    .environment(themeManager)
                    .environment(playbackService)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environment(themeManager)
            .environment(playbackService)
            .bottomSheetPullToDismiss()
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
        .onAppear {
            previewThemeID = themeManager.currentTheme.id
        }
    }

    private var previewedCustomTheme: CustomTheme? {
        themeManager.customThemes.first { $0.id == previewThemeID }
    }
}
