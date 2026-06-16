import SwiftUI

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared

    @AppStorage("fitMin.timerSoundsEnabled") private var timerSoundsEnabled = true
    @State private var showsThemes = false
    @State private var showsFonts = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button {
                        showsThemes = true
                    } label: {
                        HStack {
                            Label("Themes", systemImage: DesignSystem.Icon.themes)
                            Spacer()
                            Text(themeManager.currentTheme.name)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Toggle("Affordance border", isOn: $affordanceStyle.borderEnabled)

                    Picker("Affordance shape", selection: $affordanceStyle.shape) {
                        ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showsFonts = true
                    } label: {
                        Label("Fonts", systemImage: DesignSystem.Icon.fonts)
                    }
                }
                .designSystemGroupedListRow()

                Section("Timer") {
                    Toggle(isOn: $timerSoundsEnabled) {
                        Label("Tick and boop sounds", systemImage: DesignSystem.Icon.sound)
                    }
                }
                .designSystemGroupedListRow()

                Section("iCloud") {
                    Label("Timers sync with iCloud when available.", systemImage: "icloud")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .designSystemGroupedListRow()

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                            .viewControlIconStyle()
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showsThemes) {
                NavigationStack {
                    ThemeSelectionView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .bottomSheetPullToDismiss()
            }
            .sheet(isPresented: $showsFonts) {
                NavigationStack {
                    FontOverrideSettingsView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .bottomSheetPullToDismiss()
    }
}

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        List {
            Section("Sport Themes") {
                ForEach(themeManager.availableThemes) { theme in
                    Button {
                        themeManager.select(themeID: theme.id)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            themeSwatch(theme)
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(theme.name)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(theme.isDark ? "Dark" : "Light")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if themeManager.selectedThemeID == theme.id {
                                Image(systemName: DesignSystem.Icon.check)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.check)
                        .viewControlIconStyle()
                }
                .accessibilityLabel("Done")
            }
        }
    }

    private func themeSwatch(_ theme: FitTheme) -> some View {
        ZStack {
            Circle()
                .fill(theme.background)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(theme.accent)
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(theme.highlight)
                .rotationEffect(.degrees(180))
        }
        .frame(width: 36, height: 36)
        .overlay(Circle().stroke(theme.divider, lineWidth: 1))
    }
}

struct FontOverrideSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fitMin.usesRoundedTimerDigits") private var usesRoundedTimerDigits = true

    var body: some View {
        SettingsSheet(title: "Fonts") {
            Section("Timer") {
                Toggle("Rounded timer digits", isOn: $usesRoundedTimerDigits)
                Text("Sport themes define the primary type style. This preference is reserved for expanding fit min font controls alongside the other min apps.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .designSystemGroupedListStyle()
    }
}

#Preview {
    AccountSheetView()
        .environment(ThemeManager.shared)
}
