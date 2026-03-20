import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @Environment(PlaybackService.self) private var playbackService

    var body: some View {
        if let episode = playbackService.state.currentEpisode,
           let videoURL = episode.videoURL {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .aspectRatio(16/9, contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
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
}
