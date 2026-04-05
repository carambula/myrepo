import SwiftUI

struct PodcastRowView: View {
    let podcast: Podcast
    let latestEpisode: Episode?
    /// When false, hides title/metadata; unplayed badge is shown on the artwork (large circle, top-trailing).
    var showTitles: Bool = true
    var artEmphasis: MainScreenArtEmphasis = .standard
    var badgeMode: NewEpisodeBadgeMode = .notStartedLatest
    var tapStyle: TapInteractionStyle = .bounce
    var onRowTap: () -> Void = {}

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    /// WatchedIt `CollectionMovieCard` podcast badge on collections home.
    private static let podcastInsetArtSize: CGFloat = 24
    private static let podcastInsetCornerRadius: CGFloat = 4

    private static let sameYearDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    private static let crossYearDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private var latestMerged: Episode? {
        latestEpisode.map { EpisodePlaybackStore.merge($0) }
    }

    private var listArtSize: CGFloat {
        artEmphasis.listArtworkSideLength()
    }

    private var unplayed: Bool {
        badgeMode.shouldShowBadge(for: latestMerged)
    }

    /// Primary row artwork: latest episode art when available, else podcast art.
    private var mainThumbnailURL: URL? {
        if let episode = latestMerged {
            return episode.resolvedArtworkURL(podcast: podcast)
        }
        return podcast.displayArtworkURL
    }

    /// Show podcast art inset only when the episode has its own image (main is not duplicate podcast art).
    private var showPodcastInsetThumbnail: Bool {
        guard let episodeArtURL = latestMerged?.artworkURL,
              let podcastArtURL = podcast.displayArtworkURL else {
            return false
        }
        return normalizedArtworkURLString(episodeArtURL) != normalizedArtworkURLString(podcastArtURL)
    }

    private var isCurrentEpisode: Bool {
        guard let latestMerged else { return false }
        return playbackService.state.currentEpisode?.id == latestMerged.id
    }

    private var displayDuration: TimeInterval {
        guard let latestMerged else { return 0 }
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return max(latestMerged.duration, playbackService.state.duration)
        }
        return latestMerged.duration
    }

    private var displayPosition: TimeInterval {
        guard let latestMerged else { return 0 }
        if isCurrentEpisode {
            return playbackService.state.currentTime
        }
        return latestMerged.playbackPosition
    }

    private var rowEffectivelyFinished: Bool {
        guard let latestMerged else { return false }
        if latestMerged.isPlayed { return true }
        guard displayDuration > 0 else { return false }
        return PlaybackProgressPolicy.current.isFinished(playbackPosition: displayPosition, duration: displayDuration)
    }

    private var rowShowsPartialBar: Bool {
        guard let latestMerged else { return false }
        return PlaybackProgressPolicy.current.shouldShowPartialProgress(
            isPlayed: latestMerged.isPlayed,
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
            return "pause.circle.fill"
        }
        return "play.circle.fill"
    }

    private func playPauseTapped() {
        guard let latestMerged else { return }
        if isCurrentEpisode {
            playbackService.togglePlayPause()
        } else {
            Task { await playbackService.play(episode: latestMerged, podcast: podcast) }
        }
    }

    private func normalizedArtworkURLString(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return (components.url ?? url).absoluteString
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return Self.sameYearDateFormatter.string(from: date)
        } else {
            return Self.crossYearDateFormatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    AsyncCachedImage(url: mainThumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                            .fill(Color(.tertiarySystemFill))
                            .overlay {
                                Image(systemName: "mic.fill")
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(width: listArtSize, height: listArtSize)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
                    .overlay(alignment: .bottomLeading) {
                        if showPodcastInsetThumbnail {
                            podcastInsetThumbnail
                        }
                    }

                    if unplayed {
                        Circle()
                            .fill(themeManager.currentTheme.accentColor)
                            .frame(width: 14, height: 14)
                            .padding(5)
                            .accessibilityLabel("Unplayed latest episode")
                    }
                }

                if showTitles {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        if let episode = latestMerged {
                            Text(episode.title)
                                .font(DesignSystem.Typography.headlineSmall())
                                .foregroundColor(rowEffectivelyFinished ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                                .lineLimit(2)

                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Text(formatDate(episode.publishDate))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)

                                if displayDuration > 0 {
                                    Text("   ")
                                        .font(DesignSystem.Typography.caption())
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
                                            Text(episode.formattedDuration)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                    } else {
                                        Text(episode.formattedDuration)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }

                                if episode.hasVideo {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(themeManager.currentTheme.accentColor)
                                }
                            }
                        } else {
                            Text(podcast.title)
                                .font(DesignSystem.Typography.headlineSmall())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineLimit(2)

                            Text(podcast.author)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                } else {
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
            .tapInteraction(style: tapStyle) {
                onRowTap()
            }

            Button(action: playPauseTapped) {
                Image(systemName: playPauseIconName)
                    .font(.system(size: 28))
                    .foregroundColor(latestMerged == nil
                        ? DesignSystem.Colors.textTertiary
                        : themeManager.currentTheme.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .disabled(latestMerged == nil)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .modifier(PodcastRowListAccessibility(showTitles: showTitles, podcastTitle: podcast.title))
    }

    @ViewBuilder
    private var podcastInsetThumbnail: some View {
        Group {
            if let url = podcast.displayArtworkURL {
                AsyncCachedImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: Self.podcastInsetCornerRadius)
                        .fill(.ultraThinMaterial)
                }
            } else {
                RoundedRectangle(cornerRadius: Self.podcastInsetCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.podcastInsetCornerRadius)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    }
            }
        }
        .frame(width: Self.podcastInsetArtSize, height: Self.podcastInsetArtSize)
        .clipShape(RoundedRectangle(cornerRadius: Self.podcastInsetCornerRadius))
        .padding(.leading, 4)
        .padding(.bottom, 4)
    }
}

private struct PodcastRowListAccessibility: ViewModifier {
    let showTitles: Bool
    let podcastTitle: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if showTitles {
            content
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(podcastTitle)
        }
    }
}
