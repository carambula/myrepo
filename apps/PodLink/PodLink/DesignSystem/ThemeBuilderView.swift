import SwiftUI

struct ThemeBuilderView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var themeName = ""
    @State private var accentColor: Color = .blue
    @State private var backgroundTint: Color = .clear
    @State private var fontDesign = "default"
    @State private var fontWeight = "bold"
    @State private var useAccentForHeadlines = false
    @State private var isDark = false

    var editingTheme: CustomTheme?

    var body: some View {
        List {
            Section {
                TextField("Theme Name", text: $themeName)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Name")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                ColorPicker("Background Tint", selection: $backgroundTint, supportsOpacity: true)
                Toggle("Prefer dark appearance", isOn: $isDark)
            } header: {
                Text("Colors")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Picker("Font Design", selection: $fontDesign) {
                    Text("Default").tag("default")
                    Text("Rounded").tag("rounded")
                    Text("Serif").tag("serif")
                    Text("Monospaced").tag("monospaced")
                }

                Picker("Font Weight", selection: $fontWeight) {
                    Text("Regular").tag("regular")
                    Text("Medium").tag("medium")
                    Text("Semibold").tag("semibold")
                    Text("Bold").tag("bold")
                    Text("Heavy").tag("heavy")
                    Text("Black").tag("black")
                }

                Toggle("Use Accent Color for Headlines", isOn: $useAccentForHeadlines)
            } header: {
                Text("Typography")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Headline Preview")
                        .font(.system(
                            size: 22,
                            weight: previewWeight,
                            design: previewDesign
                        ))
                        .foregroundStyle(useAccentForHeadlines ? accentColor : DesignSystem.Colors.textPrimary)

                    Text("Body text preview for the theme.")
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    HStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 24, height: 24)
                        Text("Accent")
                            .font(DesignSystem.Typography.caption())
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            } header: {
                Text("Preview")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle(editingTheme != nil ? "Edit Theme" : "New Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(editingTheme != nil ? "Save" : "Create") {
                    saveTheme()
                    dismiss()
                }
                .disabled(themeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let editing = editingTheme {
                themeName = editing.name
                accentColor = editing.accentColor
                backgroundTint = editing.backgroundTint ?? .clear
                fontDesign = editing.fontDesignRaw
                fontWeight = editing.fontWeightRaw
                useAccentForHeadlines = editing.useAccentForHeadlines
                isDark = editing.isDark
            }
        }
    }

    private var previewDesign: Font.Design {
        switch fontDesign {
        case "rounded": return .rounded
        case "serif": return .serif
        case "monospaced": return .monospaced
        default: return .default
        }
    }

    private var previewWeight: Font.Weight {
        switch fontWeight {
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "heavy": return .heavy
        case "black": return .black
        default: return .bold
        }
    }

    private func saveTheme() {
        let trimmed = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let theme = CustomTheme(
            id: editingTheme?.id ?? UUID().uuidString,
            name: trimmed,
            accentColor: accentColor,
            backgroundTint: backgroundTint,
            fontDesign: fontDesign,
            fontWeight: fontWeight,
            useAccentForHeadlines: useAccentForHeadlines,
            isDark: isDark
        )

        if editingTheme != nil {
            themeManager.removeCustomTheme(theme)
        }
        themeManager.addCustomTheme(theme)
        themeManager.selectTheme(theme)
    }
}
