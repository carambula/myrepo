import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    var body: some View {
        if let episode = playbackService.state.currentEpisode {
            Button { showFullPlayer = true } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    AsyncCachedImage(url: episode.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                            .fill(Color(.tertiarySystemFill))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        if let podcast = playbackService.state.currentPodcast {
                            Text(podcast.title)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        playbackService.togglePlayPause()
                    } label: {
                        Image(systemName: playbackService.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        playbackService.skipForward()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Progress line
            GeometryReader { geo in
                Capsule()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, DesignSystem.Spacing.xxl)
        }
    }
}
