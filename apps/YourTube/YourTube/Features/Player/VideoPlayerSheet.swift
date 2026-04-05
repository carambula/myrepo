import SwiftUI

struct VideoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoUnmuteVideos") private var autoUnmuteVideos = true
    @AppStorage("playbackTimeLimit") private var playbackTimeLimitRawValue = PlaybackTimeLimit.off.rawValue
    @State private var pauseSignal = 0
    @State private var playbackLimitTask: Task<Void, Never>?
    let video: YTVideo
    let theme: AppTheme
    private var youtubeWatchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(video.videoID)")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            YouTubePlayerView(
                videoID: video.videoID,
                autoPlay: true,
                allowInlinePlayback: true,
                contentMode: .watchPage,
                autoUnmute: autoUnmuteVideos,
                pauseSignal: pauseSignal,
                preferFullscreenOnStart: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()

            HStack(spacing: DesignSystem.Spacing.sm) {
                if let youtubeWatchURL {
                    Link(destination: youtubeWatchURL) {
                        Image(systemName: "safari")
                            .viewControlIconStyle()
                    }
                    .buttonStyle(CircularGlassIconButtonStyle())
                    .accessibilityLabel("Open in YouTube")
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.checkmark)
                        .viewControlIconStyle()
                }
                .buttonStyle(CircularGlassIconButtonStyle())
                .accessibilityLabel("Done")
            }
            .padding(.trailing, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.lg)
        }
        .themeBackground(using: theme)
        .onAppear {
            // Ensure a fresh playback session doesn't inherit a stale pause trigger.
            pauseSignal = 0
            schedulePlaybackLimitIfNeeded()
        }
        .onDisappear {
            playbackLimitTask?.cancel()
            playbackLimitTask = nil
        }
        .onChange(of: playbackTimeLimitRawValue) {
            schedulePlaybackLimitIfNeeded()
        }
    }

    private var playbackTimeLimit: PlaybackTimeLimit {
        PlaybackTimeLimit(rawValue: playbackTimeLimitRawValue) ?? .off
    }

    private func schedulePlaybackLimitIfNeeded() {
        playbackLimitTask?.cancel()
        playbackLimitTask = nil

        guard let duration = playbackTimeLimit.duration else { return }
        playbackLimitTask = Task {
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                pauseSignal += 1
            }
        }
    }
}
