import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    let podcast: Podcast
    let onTap: () -> Void
    var onShowDetails: (() -> Void)? = nil
    var showsDownloadAffordance = true

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService
    @State private var playbackMergeTick = 0

    private var ep: Episode {
        _ = playbackMergeTick
        return EpisodePlaybackStore.merge(episode)
    }

    private var isCurrentEpisode: Bool {
        playbackService.state.currentEpisode?.id == episode.id
    }

    private var displayDuration: TimeInterval {
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return max(ep.duration, playbackService.state.duration)
        }
        return ep.duration
    }

    private var displayPosition: TimeInterval {
        if isCurrentEpisode { return playbackService.state.currentTime }
        return ep.playbackPosition
    }

    private var rowEffectivelyFinished: Bool {
        if ep.isPlayed { return true }
        guard displayDuration > 0 else { return false }
        return PlaybackProgressPolicy.current.isFinished(playbackPosition: displayPosition, duration: displayDuration)
    }

    private var rowShowsPartialBar: Bool {
        PlaybackProgressPolicy.current.shouldShowPartialProgress(
            isPlayed: ep.isPlayed,
            playbackPosition: displayPosition,
            duration: displayDuration
        )
    }

    private var rowProgressFraction: Double {
        guard displayDuration > 0 else { return 0 }
        return min(1, max(0, displayPosition / displayDuration))
    }

    private var playPauseIconName: String {
        if isCurrentEpisode, playbackService.state.isPlaying {
            "pause.circle.fill"
        } else if rowShowsPartialBar {
            "play.circle.fill"
        } else {
            "play.circle"
        }
    }

    private func playPauseTapped() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        if isCurrentEpisode {
            playbackService.togglePlayPause()
        } else {
            Task { await playbackService.play(episode: ep, podcast: podcast) }
        }
    }

    private var downloadState: DownloadManager.State {
        if ep.isDownloaded {
            return .downloaded
        }
        return downloadManager.state(for: ep)
    }

    private var canUseEpisodeWhileOffline: Bool {
        ep.isDownloaded || downloadState == .downloaded
    }

    private var shouldRestrictNetworkOnlyEpisodeActions: Bool {
        !networkStatusService.isOnline && !canUseEpisodeWhileOffline
    }

    private func downloadTapped() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        switch downloadState {
        case .downloaded:
            downloadManager.deleteDownload(for: ep)
        case .downloading:
            downloadManager.deleteDownload(for: ep)
        case .notDownloaded, .failed:
            downloadManager.startDownload(for: ep, podcast: podcast)
        }
    }

    var body: some View {
        Group {
            if let onShowDetails {
                rowContent
                    .contextMenu {
                        Button("Details & transcript") {
                            onShowDetails()
                        }
                        if showsDownloadAffordance {
                            downloadContextMenuButton
                        }
                    }
            } else {
                rowContent
                    .contextMenu {
                        if showsDownloadAffordance {
                            downloadContextMenuButton
                        }
                    }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: onTap) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    AsyncCachedImage(url: ep.artworkURL ?? podcast.displayArtworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                            .fill(Color(.tertiarySystemFill))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(ep.title)
                            .font(DesignSystem.Typography.headlineSmall())
                            .foregroundColor(rowEffectivelyFinished ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.headlineColor)
                            .lineLimit(2)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(ep.publishDate, style: .date)
                                .font(DesignSystem.Typography.captionMedium())
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            if ep.duration > 0 {
                                Text("   ")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                if rowShowsPartialBar {
                                    HStack(spacing: 4) {
                                        Capsule()
                                            .fill(Color(.tertiarySystemFill))
                                            .frame(width: 28, height: 3)
                                            .overlay(alignment: .leading) {
                                                Capsule()
                                                    .fill(themeManager.currentTheme.accentColor)
                                                    .frame(width: max(3, 28 * rowProgressFraction), height: 3)
                                            }
                                        Text(ep.formattedDuration)
                                            .font(DesignSystem.Typography.captionMedium())
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                } else {
                                    Text(ep.formattedDuration)
                                        .font(DesignSystem.Typography.captionMedium())
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }

                            if ep.hasVideo {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: playPauseTapped) {
                Image(systemName: playPauseIconName)
                    .font(.system(size: 28))
                    .foregroundColor(shouldRestrictNetworkOnlyEpisodeActions
                        ? DesignSystem.Colors.textTertiary
                        : themeManager.currentTheme.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .disabled(shouldRestrictNetworkOnlyEpisodeActions)
            .accessibilityHint(shouldRestrictNetworkOnlyEpisodeActions ? "Unavailable offline until downloaded" : "")

            if showsDownloadAffordance {
                Button(action: downloadTapped) {
                    Group {
                        switch downloadState {
                        case .downloaded:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        case .downloading:
                            ProgressView()
                                .tint(themeManager.currentTheme.accentColor)
                        case .failed:
                            Image(systemName: "exclamationmark.arrow.circlepath")
                                .foregroundColor(.orange)
                        case .notDownloaded:
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(shouldRestrictNetworkOnlyEpisodeActions
                                    ? DesignSystem.Colors.textTertiary
                                    : themeManager.currentTheme.accentColor)
                        }
                    }
                    .font(.system(size: 28))
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .disabled(shouldRestrictNetworkOnlyEpisodeActions)
                .accessibilityLabel(downloadAccessibilityLabel)
                .accessibilityHint(shouldRestrictNetworkOnlyEpisodeActions ? "Unavailable offline" : "")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { output in
            guard (output.object as? String) == episode.id else { return }
            playbackMergeTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodeDownloadStateDidChange)) { output in
            guard (output.object as? String) == episode.id else { return }
            playbackMergeTick += 1
        }
    }

    @ViewBuilder
    private var downloadContextMenuButton: some View {
        switch downloadState {
        case .downloaded:
            Button("Remove download", role: .destructive) {
                downloadManager.deleteDownload(for: ep)
            }
        case .downloading:
            Button("Cancel download", role: .destructive) {
                downloadManager.deleteDownload(for: ep)
            }
        case .failed:
            if shouldRestrictNetworkOnlyEpisodeActions {
                Button("Retry download") {}
                    .disabled(true)
            } else {
                Button("Retry download") {
                    downloadManager.startDownload(for: ep, podcast: podcast)
                }
            }
        case .notDownloaded:
            if shouldRestrictNetworkOnlyEpisodeActions {
                Button("Download for offline") {}
                    .disabled(true)
            } else {
                Button("Download for offline") {
                    downloadManager.startDownload(for: ep, podcast: podcast)
                }
            }
        }
    }

    private var downloadAccessibilityLabel: String {
        switch downloadState {
        case .downloaded:
            return "Remove downloaded episode"
        case .downloading:
            return "Cancel episode download"
        case .failed:
            return "Retry episode download"
        case .notDownloaded:
            return "Download episode for offline play"
        }
    }
}

