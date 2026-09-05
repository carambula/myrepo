import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    let podcast: Podcast
    let onTap: () -> Void
    var onShowDetails: (() -> Void)? = nil
    var showsDownloadAffordance = true

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Group {
            if let onShowDetails {
                rowContent
                    .contextMenu {
                        Button("Details & transcript") {
                            onShowDetails()
                        }
                        if showsDownloadAffordance {
                            EpisodeRowDownloadMenu(episode: episode, podcast: podcast)
                        }
                    }
            } else {
                rowContent
                    .contextMenu {
                        if showsDownloadAffordance {
                            EpisodeRowDownloadMenu(episode: episode, podcast: podcast)
                        }
                    }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: onTap) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    AsyncCachedImage(url: episode.artworkURL ?? podcast.displayArtworkURL) { image in
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
                        EpisodeRowTitle(episode: episode)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(episode.publishDate, style: .date)
                                .font(DesignSystem.Typography.captionMedium())
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            EpisodeRowDurationMeta(episode: episode)

                            if episode.hasVideo {
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

            EpisodeRowPlayButton(episode: episode, podcast: podcast)

            if showsDownloadAffordance {
                EpisodeRowDownloadButton(episode: episode, podcast: podcast)
            }
        }
    }
}

// MARK: - Playback-isolated chrome

/// Title color follows live progress only for the current episode so artwork/layout stay still.
private struct EpisodeRowTitle: View {
    let episode: Episode

    @Environment(PlaybackService.self) private var playbackService

    var body: some View {
        Text(episode.title)
            .font(DesignSystem.Typography.headlineSmall())
            .foregroundColor(isEffectivelyFinished ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.headlineColor)
            .lineLimit(2)
    }

    private var isEffectivelyFinished: Bool {
        if episode.isPlayed { return true }
        let duration = displayDuration
        guard duration > 0 else { return false }
        return PlaybackProgressPolicy.current.isFinished(playbackPosition: displayPosition, duration: duration)
    }

    private var isCurrentEpisode: Bool {
        playbackService.state.currentEpisode?.id == episode.id
    }

    private var displayDuration: TimeInterval {
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return max(episode.duration, playbackService.state.duration)
        }
        return episode.duration
    }

    private var displayPosition: TimeInterval {
        if isCurrentEpisode { return playbackService.state.currentTime }
        return episode.playbackPosition
    }
}

private struct EpisodeRowDurationMeta: View {
    let episode: Episode

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    var body: some View {
        if episode.duration > 0 {
            Text("   ")
                .foregroundColor(DesignSystem.Colors.textSecondary)
            if showsPartialBar {
                HStack(spacing: 4) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 28, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(themeManager.currentTheme.accentColor)
                                .frame(width: max(3, 28 * progressFraction), height: 3)
                        }
                    Text(episode.formattedDuration)
                        .font(DesignSystem.Typography.captionMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                Text(episode.formattedDuration)
                    .font(DesignSystem.Typography.captionMedium())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var isCurrentEpisode: Bool {
        playbackService.state.currentEpisode?.id == episode.id
    }

    private var displayDuration: TimeInterval {
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return max(episode.duration, playbackService.state.duration)
        }
        return episode.duration
    }

    private var displayPosition: TimeInterval {
        if isCurrentEpisode { return playbackService.state.currentTime }
        return episode.playbackPosition
    }

    private var showsPartialBar: Bool {
        PlaybackProgressPolicy.current.shouldShowPartialProgress(
            isPlayed: episode.isPlayed,
            playbackPosition: displayPosition,
            duration: displayDuration
        )
    }

    private var progressFraction: Double {
        guard displayDuration > 0 else { return 0 }
        return min(1, max(0, displayPosition / displayDuration))
    }
}

private struct EpisodeRowPlayButton: View {
    let episode: Episode
    let podcast: Podcast

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(NetworkStatusService.self) private var networkStatusService

    var body: some View {
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
    }

    private var isCurrentEpisode: Bool {
        playbackService.state.currentEpisode?.id == episode.id
    }

    private var displayDuration: TimeInterval {
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return max(episode.duration, playbackService.state.duration)
        }
        return episode.duration
    }

    private var displayPosition: TimeInterval {
        if isCurrentEpisode { return playbackService.state.currentTime }
        return episode.playbackPosition
    }

    private var showsPartialBar: Bool {
        PlaybackProgressPolicy.current.shouldShowPartialProgress(
            isPlayed: episode.isPlayed,
            playbackPosition: displayPosition,
            duration: displayDuration
        )
    }

    private var playPauseIconName: String {
        if isCurrentEpisode, playbackService.state.isPlaying {
            "pause.circle.fill"
        } else if showsPartialBar {
            "play.circle.fill"
        } else {
            "play.circle"
        }
    }

    private var shouldRestrictNetworkOnlyEpisodeActions: Bool {
        !networkStatusService.isOnline && !episode.isDownloaded
    }

    private func playPauseTapped() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        if isCurrentEpisode {
            playbackService.togglePlayPause()
        } else {
            Task { await playbackService.play(episode: episode, podcast: podcast) }
        }
    }
}

private struct EpisodeRowDownloadButton: View {
    let episode: Episode
    let podcast: Podcast

    @Environment(ThemeManager.self) private var themeManager
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService

    var body: some View {
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

    private var downloadState: DownloadManager.State {
        if episode.isDownloaded {
            return .downloaded
        }
        return downloadManager.state(for: episode)
    }

    private var shouldRestrictNetworkOnlyEpisodeActions: Bool {
        !networkStatusService.isOnline && !episode.isDownloaded && downloadState != .downloaded
    }

    private func downloadTapped() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        switch downloadState {
        case .downloaded:
            downloadManager.deleteDownload(for: episode)
        case .downloading:
            downloadManager.deleteDownload(for: episode)
        case .notDownloaded, .failed:
            downloadManager.startDownload(for: episode, podcast: podcast)
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

private struct EpisodeRowDownloadMenu: View {
    let episode: Episode
    let podcast: Podcast

    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService

    var body: some View {
        switch downloadState {
        case .downloaded:
            Button("Remove download", role: .destructive) {
                downloadManager.deleteDownload(for: episode)
            }
        case .downloading:
            Button("Cancel download", role: .destructive) {
                downloadManager.deleteDownload(for: episode)
            }
        case .failed:
            if shouldRestrictNetworkOnlyEpisodeActions {
                Button("Retry download") {}
                    .disabled(true)
            } else {
                Button("Retry download") {
                    downloadManager.startDownload(for: episode, podcast: podcast)
                }
            }
        case .notDownloaded:
            if shouldRestrictNetworkOnlyEpisodeActions {
                Button("Download for offline") {}
                    .disabled(true)
            } else {
                Button("Download for offline") {
                    downloadManager.startDownload(for: episode, podcast: podcast)
                }
            }
        }
    }

    private var downloadState: DownloadManager.State {
        if episode.isDownloaded {
            return .downloaded
        }
        return downloadManager.state(for: episode)
    }

    private var shouldRestrictNetworkOnlyEpisodeActions: Bool {
        !networkStatusService.isOnline && !episode.isDownloaded && downloadState != .downloaded
    }
}
