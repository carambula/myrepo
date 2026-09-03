import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @Environment(PlaybackService.self) private var playbackService

    @State private var player: AVPlayer?

    private var videoURL: URL? {
        playbackService.state.currentEpisode?.videoURL
    }

    var body: some View {
        Group {
            if let url = videoURL {
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay { ProgressView() }
                }
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "video.slash")
                                .font(.title)
                            Text("No video available")
                                .font(DesignSystem.Typography.bodySmall())
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear { ensurePlayer() }
        .onChange(of: playbackService.state.currentEpisode?.id) { _, _ in
            player?.pause()
            player = nil
            ensurePlayer()
        }
        .onChange(of: videoURL?.absoluteString) { _, _ in
            player?.pause()
            player = nil
            ensurePlayer()
        }
    }

    private func ensurePlayer() {
        guard let url = videoURL else { return }
        if player == nil {
            player = AVPlayer(url: url)
        }
    }
}
