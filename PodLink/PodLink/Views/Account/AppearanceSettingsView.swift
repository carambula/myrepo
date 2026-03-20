import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage("searchBarAppearance") private var searchBarAppearance = "glass"
    @AppStorage("glassComponentStyle") private var glassComponentStyle = "premium"
    @AppStorage("toolbarBehavior") private var toolbarBehavior = "static"
    @AppStorage("tapInteraction") private var tapInteraction = "bounce"
    @AppStorage("layoutMode") private var layoutMode = "grid"
    @AppStorage("posterSize") private var posterSize = "plus60"

    var body: some View {
        List {
            Section("Search Bar") {
                ForEach(SearchBarAppearance.allCases, id: \.self) { style in
                    Button {
                        searchBarAppearance = style.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(style.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(style.description)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if searchBarAppearance == style.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }
                }
            }

            Section("Toolbar & Buttons") {
                ForEach(GlassComponentStyle.allCases, id: \.self) { style in
                    Button {
                        glassComponentStyle = style.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(style.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(style.description)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if glassComponentStyle == style.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }
                }
            }

            Section("Tap Interactions") {
                ForEach(TapInteractionStyle.allCases, id: \.self) { style in
                    Button {
                        tapInteraction = style.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(style.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(style.description)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if tapInteraction == style.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }
                }
            }

            Section("Layout") {
                Picker("View Mode", selection: $layoutMode) {
                    Text("Grid").tag("grid")
                    Text("List").tag("list")
                    Text("Episodes").tag("episodes")
                }

                Picker("Artwork Size", selection: $posterSize) {
                    Text("+10%").tag("plus10")
                    Text("+20%").tag("plus20")
                    Text("+40%").tag("plus40")
                    Text("+60%").tag("plus60")
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
