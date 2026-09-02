import SwiftUI

enum AutoQueueRefreshPolicy: String, CaseIterable, Identifiable {
    case launchOnly
    case libraryChanges
    case adaptive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .launchOnly: return "Launch Only"
        case .libraryChanges: return "Library Changes"
        case .adaptive: return "Adaptive"
        }
    }

    var description: String {
        switch self {
        case .launchOnly: return "Rebuild queue only at app launch"
        case .libraryChanges: return "Also rebuild when followed podcasts change"
        case .adaptive: return "Rebuild whenever content or playback changes"
        }
    }
}

enum SearchSuggestionRefreshPolicy: String, CaseIterable, Identifiable {
    case onOpenOnly
    case onOpenAndLibraryChanges
    case live

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onOpenOnly: return "On Open Only"
        case .onOpenAndLibraryChanges: return "On Open & Library Changes"
        case .live: return "Live"
        }
    }

    var description: String {
        switch self {
        case .onOpenOnly: return "Refresh suggestions only when search opens (30 min cooldown)"
        case .onOpenAndLibraryChanges: return "Also refresh when library changes (10 min cooldown)"
        case .live: return "Refresh on every relevant change (2 min cooldown)"
        }
    }
}

struct PlaybackSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("skipForwardInterval") private var skipForwardInterval = 30
    @AppStorage("skipBackwardInterval") private var skipBackwardInterval = 15
    @AppStorage("autoPlayNext") private var autoPlayNext = true
    @AppStorage("preferVideoPlayback") private var preferVideoPlayback = false
    @AppStorage("backgroundVideoPlayback") private var backgroundVideoPlayback = true
    @AppStorage("continuousPlay") private var continuousPlay = true
    @AppStorage("playbackFinishRemainingSeconds") private var finishRemainingSeconds = 45.0
    @AppStorage("playbackFinishProgressFraction") private var finishProgressFraction = 0.97
    @AppStorage("playbackPartialMinSeconds") private var partialMinSeconds = 30.0
    @AppStorage("playbackPartialMinProgressFraction") private var partialMinProgressFraction = 0.02

    var body: some View {
        List {
            Section("Speed") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Default Speed")
                        Spacer()
                        Text(String(format: "%.2g×", playbackSpeed))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    Slider(value: $playbackSpeed, in: 0.5...3.0, step: 0.25)
                        .tint(themeManager.currentTheme.accentColor)
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Skip Intervals") {
                Picker("Skip Forward", selection: $skipForwardInterval) {
                    ForEach([10, 15, 30, 45, 60], id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }

                Picker("Skip Backward", selection: $skipBackwardInterval) {
                    ForEach([5, 10, 15, 30], id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section("Behavior") {
                Toggle("Auto-Play Next Episode", isOn: $autoPlayNext)
                Toggle("Continuous Play", isOn: $continuousPlay)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Mark finished with ≤ remaining")
                        Spacer()
                        Text("\(Int(finishRemainingSeconds))s")
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    Slider(value: $finishRemainingSeconds, in: 15...120, step: 5)
                        .tint(themeManager.currentTheme.accentColor)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Mark finished at progress ≥")
                        Spacer()
                        Text(String(format: "%.0f%%", finishProgressFraction * 100))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    Slider(value: $finishProgressFraction, in: 0.9...0.99, step: 0.01)
                        .tint(themeManager.currentTheme.accentColor)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Show progress after playback ≥")
                        Spacer()
                        Text("\(Int(partialMinSeconds))s")
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    Slider(value: $partialMinSeconds, in: 5...120, step: 5)
                        .tint(themeManager.currentTheme.accentColor)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("…or progress ≥")
                        Spacer()
                        Text(String(format: "%.0f%%", partialMinProgressFraction * 100))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                    Slider(value: $partialMinProgressFraction, in: 0.01...0.15, step: 0.01)
                        .tint(themeManager.currentTheme.accentColor)
                }
            } header: {
                Text("Episode progress")
            } footer: {
                Text(
                    "An episode is treated as finished when either threshold is met. Partial progress appears in lists after either “started” threshold is exceeded but before the episode is finished."
                )
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Toggle("Prefer Video When Available", isOn: $preferVideoPlayback)
                Toggle("Background Video Playback", isOn: $backgroundVideoPlayback)
            } header: {
                Text("Video")
            } footer: {
                Text(
                    "Video appears only when the podcast feed includes a video file (or supported video link). Many shows publish audio in RSS and host video separately on YouTube or other apps."
                )
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Playback")
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
        .onChange(of: playbackSpeed) { _, newValue in
            playbackService.setRate(Float(newValue))
        }
        .onChange(of: skipForwardInterval) { _, _ in
            playbackService.refreshRemoteCommandSettings()
        }
        .onChange(of: skipBackwardInterval) { _, _ in
            playbackService.refreshRemoteCommandSettings()
        }
    }
}
