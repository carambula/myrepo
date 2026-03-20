import SwiftUI
import AVFoundation

@main
struct PodLinkApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var playbackService = PlaybackService.shared

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(playbackService)
                .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : nil)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
