//
//  FontOverrideSettingsView.swift
//  WatchedIt
//
//  Font Override Settings
//

import SwiftUI

struct FontOverrideSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var settings: FontOverrideSettings
    @State private var enabled: Bool
    
    init() {
        let manager = ThemeManager.shared
        _settings = State(initialValue: manager.fontOverrideSettings)
        _enabled = State(initialValue: manager.fontOverrideEnabled)
    }
    
    var body: some View {
        Form {
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
                
                Section {
                    Button("Reset to Defaults") {
                        settings = FontOverrideSettings()
                        themeManager.fontOverrideSettings = settings
                    }
                }
                
                Section {
                    Button("Test Font Loading") {
                        themeManager.verifyRotinaFontsLoaded()
                    }
                } footer: {
                    Text("Check console for font loading status")
                }
            }
            
            Section {
                Text("Make sure the Rotina font files are added to the Xcode project and listed in Info.plist.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
