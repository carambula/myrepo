//
//  FontOverrideSettingsView.swift
//  Cyclismo
//
//  Font override settings (aligned with WatchedIt ThemeManager pattern).
//

import SwiftUI

struct FontOverrideSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var settings: FontOverrideSettings
    @State private var enabled: Bool

    init() {
        let manager = ThemeManager.shared
        _settings = State(initialValue: manager.fontOverrideSettings)
        _enabled = State(initialValue: manager.fontOverrideEnabled)
    }

    var body: some View {
        List {
            Section {
                Toggle("Enable Custom Fonts", isOn: $enabled)
                    .onChange(of: enabled) { _, newValue in
                        themeManager.fontOverrideEnabled = newValue
                    }
            } header: {
                Text("Font Override")
            } footer: {
                Text("Use the Rotina font family to customize typography throughout the app.")
            }
            .designSystemGroupedListRow()

            if enabled {
                Section("Display (Large Headings)") {
                    Picker("Weight", selection: $settings.displayWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName)
                                .tag(weight)
                        }
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.display, size: 24))
                        .padding(.vertical, 8)
                }
                .designSystemGroupedListRow()

                Section("Heading (Section Titles)") {
                    Picker("Weight", selection: $settings.headingWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName)
                                .tag(weight)
                        }
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.heading, size: 18))
                        .padding(.vertical, 8)
                }
                .designSystemGroupedListRow()

                Section("Body (Content Text)") {
                    Picker("Weight", selection: $settings.bodyWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName)
                                .tag(weight)
                        }
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.body, size: 16))
                        .padding(.vertical, 8)
                }
                .designSystemGroupedListRow()

                Section("UI (Buttons & Labels)") {
                    Picker("Weight", selection: $settings.uiWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName)
                                .tag(weight)
                        }
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.ui, size: 16))
                        .padding(.vertical, 8)
                }
                .designSystemGroupedListRow()

                Section("Caption (Small Text)") {
                    Picker("Weight", selection: $settings.captionWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName)
                                .tag(weight)
                        }
                    }

                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.caption, size: 12))
                        .padding(.vertical, 8)
                }
                .designSystemGroupedListRow()

                Section {
                    Button("Reset to Defaults") {
                        settings = FontOverrideSettings()
                        themeManager.fontOverrideSettings = settings
                    }
                }
                .designSystemGroupedListRow()

                Section {
                    Button("Test Font Loading") {
                        themeManager.verifyRotinaFontsLoaded()
                    }
                } footer: {
                    Text("Check console for font loading status")
                }
                .designSystemGroupedListRow()
            }

            Section {
                Text("Make sure the Rotina font files are added to the Xcode project and listed in Info.plist.")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Font Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, newSettings in
            themeManager.fontOverrideSettings = newSettings
        }
    }
}

#Preview {
    NavigationStack {
        FontOverrideSettingsView()
            .environmentObject(ThemeManager.shared)
    }
}
