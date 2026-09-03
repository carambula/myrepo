//
//  ThemesView.swift
//  WatchedIt
//
//  Theme Selection View
//

import SwiftUI

struct ThemesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var previewThemeName: String
    @State private var isShowingThemeBuilder = false
    @State private var editingTheme: CustomThemeDefinition? = nil
    
    init() {
        _previewThemeName = State(initialValue: ThemeManager.shared.currentTheme.name)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                TabView(selection: $previewThemeName) {
                    ForEach(allThemes, id: \.name) { theme in
                        MinThemePreviewCard(
                            theme: theme,
                            colorScheme: colorScheme,
                            isSelected: isCurrentTheme(theme.name),
                            onSelect: {
                                applyTheme(named: theme.name)
                            }
                        )
                        .tag(theme.name)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity)
                .frame(height: 440)

                MinThemePageDots(
                    count: allThemes.count,
                    currentIndex: allThemes.firstIndex(where: { isPreviewTheme($0.name) }) ?? 0,
                    accentColor: DesignSystem.Color.accent
                )

                if let selectedCustomTheme = selectedCustomThemeDefinition {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button {
                            editingTheme = selectedCustomTheme
                            isShowingThemeBuilder = true
                        } label: {
                            Label("Edit Theme", systemImage: DesignSystem.Icon.edit)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            themeManager.deleteCustomTheme(id: selectedCustomTheme.id)
                            previewThemeName = themeManager.currentTheme.name
                        } label: {
                            Label("Delete Theme", systemImage: DesignSystem.Icon.delete)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .background(DesignSystem.Color.background)
            .tint(DesignSystem.Color.accent)
            .navigationTitle("Themes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        editingTheme = nil
                        isShowingThemeBuilder = true
                    } label: {
                        Image(systemName: DesignSystem.Icon.add)
                    }
                    .accessibilityLabel("Create theme")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                    }
                    .accessibilityLabel("Done")
                }
            }
            #endif
            .sheet(isPresented: $isShowingThemeBuilder) {
                ThemeBuilderView(editingTheme: editingTheme)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                previewThemeName = themeManager.currentTheme.name
            }
        }
        .bottomSheetPullToDismiss()
    }

    private var allThemes: [Theme] {
        themeManager.getAllThemes()
    }

    private var selectedCustomThemeDefinition: CustomThemeDefinition? {
        themeManager.customThemeDefinitions.first {
            $0.name.caseInsensitiveCompare(previewThemeName) == .orderedSame
        }
    }

    private func applyTheme(named name: String) {
        guard let theme = themeManager.getTheme(named: name) else { return }
        if themeManager.currentTheme.name.caseInsensitiveCompare(theme.name) != .orderedSame {
            themeManager.setTheme(theme)
        }
    }

    private func isCurrentTheme(_ name: String) -> Bool {
        themeManager.currentTheme.name.caseInsensitiveCompare(name) == .orderedSame
    }

    private func isPreviewTheme(_ name: String) -> Bool {
        previewThemeName.caseInsensitiveCompare(name) == .orderedSame
    }
}

private struct ThemeBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    let editingTheme: CustomThemeDefinition?

    @State private var themeName: String
    @State private var highlightColor: Color
    @State private var accentColor: Color
    @State private var secondaryAccentColor: Color
    @State private var darkHeadlineColor: Color
    @State private var lightHeadlineColor: Color
    @State private var fontStyle: ThemeFontStyle
    @State private var darkBackgroundColor: Color
    @State private var lightBackgroundColor: Color
    @State private var supportsLightMode: Bool
    @State private var validationMessage: String?

    init(editingTheme: CustomThemeDefinition?) {
        self.editingTheme = editingTheme

        let seedColor = editingTheme?.accent.color ?? DesignSystem.Color.accent
        let manager = ThemeManager.shared
        let palette = manager.makeAdaptedPalette(from: seedColor)

        _themeName = State(initialValue: editingTheme?.name ?? "")
        _highlightColor = State(initialValue: seedColor)
        _accentColor = State(initialValue: editingTheme?.accent.color ?? palette.accent)
        _secondaryAccentColor = State(initialValue: editingTheme?.secondaryAccent.color ?? palette.secondaryAccent)
        _darkHeadlineColor = State(initialValue: editingTheme?.darkModeHeadlineColor.color ?? DesignSystem.Color.darkModeHeadline)
        _lightHeadlineColor = State(initialValue: editingTheme?.lightModeHeadlineColor.color ?? DesignSystem.Color.lightModeHeadline)
        _fontStyle = State(initialValue: editingTheme?.fontStyle ?? .system)
        _darkBackgroundColor = State(initialValue: editingTheme?.darkModeBackground.color ?? palette.darkModeBackground)
        _lightBackgroundColor = State(initialValue: editingTheme?.lightModeBackground.color ?? palette.lightModeBackground)
        _supportsLightMode = State(initialValue: editingTheme?.supportsLightMode ?? true)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("My Theme", text: $themeName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                } header: {
                    Text("Theme Name")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .designSystemGroupedListRow()

                Section {
                    ColorPicker("Highlight", selection: $highlightColor, supportsOpacity: false)
                    Button("Generate Palette From Highlight") {
                        regeneratePalette()
                    }
                } header: {
                    Text("Highlight Color")
                } footer: {
                    Text("Use this as your base color, then fine-tune each derived color below.")
                }
                .designSystemGroupedListRow()

                Section {
                    ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    ColorPicker("Secondary Accent", selection: $secondaryAccentColor, supportsOpacity: false)
                    ColorPicker("Dark Mode Headline", selection: $darkHeadlineColor, supportsOpacity: false)
                    ColorPicker("Light Mode Headline", selection: $lightHeadlineColor, supportsOpacity: false)
                } header: {
                    Text("Primary Colors")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .designSystemGroupedListRow()

                Section {
                    Picker("Font Style", selection: $fontStyle) {
                        ForEach(ThemeFontStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Typography")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .designSystemGroupedListRow()

                Section {
                    ColorPicker("Dark Background", selection: $darkBackgroundColor, supportsOpacity: false)
                    ColorPicker("Light Background", selection: $lightBackgroundColor, supportsOpacity: false)
                    Toggle("Supports Light Mode", isOn: $supportsLightMode)
                } header: {
                    Text("Background Colors")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } footer: {
                    Text("Background tint is auto-generated from background colors: dark mode is 3% lighter, light mode is 3% darker.")
                }
                .designSystemGroupedListRow()

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.error)
                    }
                    .designSystemGroupedListRow()
                }
            }
            .designSystemGroupedListStyle()
            .navigationTitle(editingTheme == nil ? "New Theme" : "Edit Theme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveTheme()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                    }
                    .accessibilityLabel(editingTheme == nil ? "Save" : "Update")
                }
            }
            #endif
        }
        .bottomSheetPullToDismiss()
    }

    private func regeneratePalette() {
        let palette = themeManager.makeAdaptedPalette(from: highlightColor)
        accentColor = palette.accent
        secondaryAccentColor = palette.secondaryAccent
        darkHeadlineColor = palette.darkModeHeadlineColor
        lightHeadlineColor = palette.lightModeHeadlineColor
        darkBackgroundColor = palette.darkModeBackground
        lightBackgroundColor = palette.lightModeBackground
    }

    private func saveTheme() {
        let saved = themeManager.createOrUpdateCustomTheme(
            existingID: editingTheme?.id,
            name: themeName,
            fontStyle: fontStyle,
            accent: accentColor,
            secondaryAccent: secondaryAccentColor,
            darkModeHeadlineColor: darkHeadlineColor,
            lightModeHeadlineColor: lightHeadlineColor,
            darkModeBackground: darkBackgroundColor,
            lightModeBackground: lightBackgroundColor,
            supportsLightMode: supportsLightMode
        )

        if saved {
            dismiss()
        } else {
            validationMessage = "Use a unique name and avoid built-in theme names."
        }
    }
}

#Preview {
    ThemesView()
}

