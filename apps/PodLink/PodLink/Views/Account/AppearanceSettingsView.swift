import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchBarAppearance") private var searchBarAppearance = "glass"
    @AppStorage("glassComponentStyle") private var glassComponentStyle = "premium"
    @AppStorage("toolbarBehavior") private var toolbarBehavior = "static"
    @AppStorage("tapInteraction") private var tapInteraction = "bounce"
    @AppStorage("layoutMode") private var layoutMode = "grid"
    @AppStorage("posterSize") private var posterSize = "plus60"
    @AppStorage("mainScreenArtEmphasis") private var mainScreenArtEmphasis = MainScreenArtEmphasis.largeArt.rawValue
    @AppStorage("showPodcastTitlesOnMain") private var showPodcastTitlesOnMain = false
    @AppStorage("newEpisodeBadgeMode") private var newEpisodeBadgeMode = NewEpisodeBadgeMode.notStartedLatest.rawValue
    @AppStorage("navigationSearchPlacement") private var navigationSearchPlacement = NavigationSearchPlacement.topLeading.rawValue
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue
    @AppStorage("miniPlayerDockPresentation") private var miniPlayerDockPresentation = MiniPlayerDockPresentation.fullBleed.rawValue
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared

    var body: some View {
        List {
            Section {
                Toggle("Affordance border", isOn: $affordanceStyle.borderEnabled)

                Picker("Affordance shape", selection: $affordanceStyle.shape) {
                    ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                        Text(shape.displayName).tag(shape)
                    }
                }
            } header: {
                Text("Controls")
            } footer: {
                Text("Border adds an outline to buttons, inputs, and players. Shape switches between round (capsule/circle) and square (rounded rectangle) geometry.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

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
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

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
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

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
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Picker("Artwork emphasis", selection: $mainScreenArtEmphasis) {
                    ForEach(MainScreenArtEmphasis.allCases, id: \.rawValue) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }

                Toggle("Show podcast titles", isOn: $showPodcastTitlesOnMain)

                Picker("New episode badge", selection: $newEpisodeBadgeMode) {
                    ForEach(NewEpisodeBadgeMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
            } header: {
                Text("Main screen")
            } footer: {
                let badgeMode = NewEpisodeBadgeMode(rawValue: newEpisodeBadgeMode) ?? .notStartedLatest
                Text(badgeMode == .off
                    ? "Large artwork applies on top of your artwork size setting."
                    : "Large artwork applies on top of your artwork size setting. \(badgeMode.description) When titles are off, the badge is a larger accent circle on the cover.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

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
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Navigation Positions") {
                ForEach(NavigationSearchPlacement.allCases, id: \.self) { placement in
                    Button {
                        navigationSearchPlacement = placement.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(placement.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(placement.description)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if navigationSearchPlacement == placement.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Mini Player") {
                ForEach(MiniPlayerDockMode.allCases, id: \.self) { mode in
                    Button {
                        miniPlayerDockMode = mode.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(mode.description)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            if miniPlayerDockMode == mode.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }
                }

                if miniPlayerDockMode == MiniPlayerDockMode.docked.rawValue {
                    Picker("Docked Size", selection: $miniPlayerSize) {
                        ForEach(MiniPlayerSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(MiniPlayerDockPresentation.allCases, id: \.self) { style in
                        Button {
                            miniPlayerDockPresentation = style.rawValue
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
                                if miniPlayerDockPresentation == style.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.currentTheme.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            
            Section("Typography") {
                NavigationLink {
                    FontOverrideSettingsView()
                        .environment(themeManager)
                } label: {
                    HStack {
                        Text("Fonts")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "textformat")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
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
}
