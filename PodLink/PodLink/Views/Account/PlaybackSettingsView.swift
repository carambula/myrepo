import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("skipForwardInterval") private var skipForwardInterval = 30
    @AppStorage("skipBackwardInterval") private var skipBackwardInterval = 15
    @AppStorage("autoPlayNext") private var autoPlayNext = true
    @AppStorage("preferVideoPlayback") private var preferVideoPlayback = false
    @AppStorage("backgroundVideoPlayback") private var backgroundVideoPlayback = true
    @AppStorage("continuousPlay") private var continuousPlay = true

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

            Section("Behavior") {
                Toggle("Auto-Play Next Episode", isOn: $autoPlayNext)
                Toggle("Continuous Play", isOn: $continuousPlay)
            }

            Section("Video") {
                Toggle("Prefer Video When Available", isOn: $preferVideoPlayback)
                Toggle("Background Video Playback", isOn: $backgroundVideoPlayback)
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.currentTheme.accentColor)
    }
}
