import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    var podcast: Podcast?

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService
    @Environment(\.dismiss) private var dismiss

    @State private var mediaLinks: [MediaLink] = []
    @State private var isLoadingLinks = false
    @State private var showFullNotes = false
    @State private var fullTranscript: FullTranscript?
    @State private var isLoadingTranscript = false

    private var mergedEpisode: Episode {
        EpisodePlaybackStore.merge(episode)
    }

    private var downloadState: DownloadManager.State {
        if mergedEpisode.isDownloaded {
            return .downloaded
        }
        return downloadManager.state(for: mergedEpisode)
    }

    private var canUseEpisodeWhileOffline: Bool {
        mergedEpisode.isDownloaded || downloadState == .downloaded
    }

    private var shouldRestrictNetworkOnlyEpisodeActions: Bool {
        !networkStatusService.isOnline && !canUseEpisodeWhileOffline
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.lg)

                header
                playControls
                mediaLinksSection
                showNotesSection
                chaptersSection
                EpisodeTranscriptDetailSection(
                    episode: mergedEpisode,
                    isLoading: isLoadingTranscript,
                    fullTranscript: fullTranscript,
                    onSeekFromTranscript: { playbackService.seek(to: $0) },
                    onReloadTranscript: reloadTranscript,
                    onRequestDownloadForTranscription: startDownloadForTranscription,
                    isDownloadForTranscriptionInProgress: downloadState == .downloading,
                    isDownloadForTranscriptionEnabled: !shouldRestrictNetworkOnlyEpisodeActions && downloadState != .downloaded
                )
            }
            .font(DesignSystem.Typography.bodyMedium())
            .padding(.bottom, 80)
        }
        .themeBackground()
        .bottomSheetPullToDismiss()
        .task {
            await loadMediaLinks()
            await reloadTranscript()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            AsyncCachedImage(url: mergedEpisode.resolvedArtworkURL(podcast: podcast)) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            Text(mergedEpisode.title)
                .font(DesignSystem.Typography.displayLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            if let podcast {
                Button {
                    dismiss()
                } label: {
                    Text(podcast.title)
                        .font(DesignSystem.Typography.labelMedium())
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Podcast")
                .accessibilityHint("Returns to the podcast")
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(mergedEpisode.publishDate, style: .date)
                if mergedEpisode.duration > 0 {
                    Text("   ")
                    Text(mergedEpisode.formattedDuration)
                }
                if mergedEpisode.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
            .font(DesignSystem.Typography.captionMedium())
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Play Controls

    private var playControls: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            Button {
                Task { await playbackService.play(episode: mergedEpisode, podcast: podcast) }
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .disabled(shouldRestrictNetworkOnlyEpisodeActions)

            Button {
                playbackService.addToQueue(mergedEpisode)
            } label: {
                Image(systemName: "text.append")
                    .font(.system(size: 18))
                    .foregroundColor(detailControlsIconColor)
                    .frame(width: DesignSystem.Controls.iconButtonSize, height: DesignSystem.Controls.iconButtonSize)
            }
            .buttonStyle(.liquidGlassCompact)
            .disabled(shouldRestrictNetworkOnlyEpisodeActions)

            Button {
                toggleDownload()
            } label: {
                DownloadStatusIcon(
                    iconName: downloadIconName,
                    iconColor: downloadIconColor,
                    isDownloading: downloadState == .downloading,
                    iconSize: 18,
                    frameSize: 20
                )
                .frame(width: DesignSystem.Controls.iconButtonSize, height: DesignSystem.Controls.iconButtonSize)
            }
            .buttonStyle(.liquidGlassCompact)
            .disabled(shouldRestrictNetworkOnlyEpisodeActions)
            .accessibilityLabel(downloadAccessibilityLabel)

            Button {
                // Toggle bookmark
            } label: {
                Image(systemName: mergedEpisode.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(detailControlsIconColor)
                    .frame(width: DesignSystem.Controls.iconButtonSize, height: DesignSystem.Controls.iconButtonSize)
            }
            .buttonStyle(.liquidGlassCompact)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    private var downloadIconName: String {
        switch downloadState {
        case .downloaded:
            return "checkmark.circle.fill"
        case .downloading:
            return "arrow.down.circle.fill"
        case .failed:
            return "exclamationmark.arrow.circlepath"
        case .notDownloaded:
            return "arrow.down.circle.fill"
        }
    }

    private var downloadIconColor: Color {
        if shouldRestrictNetworkOnlyEpisodeActions {
            return DesignSystem.Colors.textTertiary
        }
        return detailControlsIconColor
    }

    private var detailControlsIconColor: Color {
        DesignSystem.Colors.textPrimary
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

    private func toggleDownload() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        switch downloadState {
        case .downloaded:
            downloadManager.deleteDownload(for: mergedEpisode)
        case .downloading:
            downloadManager.deleteDownload(for: mergedEpisode)
        case .notDownloaded, .failed:
            downloadManager.startDownload(for: mergedEpisode, podcast: podcast)
        }
    }

    private func startDownloadForTranscription() {
        guard !shouldRestrictNetworkOnlyEpisodeActions else { return }
        guard downloadState != .downloading, downloadState != .downloaded else { return }
        downloadManager.startDownload(for: mergedEpisode, podcast: podcast)
    }

    // MARK: - Media Links

    private var mediaLinksSection: some View {
        Group {
            if !mediaLinks.isEmpty || isLoadingLinks {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Connected Media")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                    if isLoadingLinks {
                        HStack {
                            ProgressView()
                            Text("Analyzing episode...")
                                .font(DesignSystem.Typography.captionMedium())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(mediaLinks) { link in
                                    MediaLinkCardView(link: link)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Show Notes

    private var showNotesSection: some View {
        Group {
            if !mergedEpisode.description.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Show Notes")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    Button {
                        withAnimation { showFullNotes.toggle() }
                    } label: {
                        Text(mergedEpisode.description.strippingHTML)
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(showFullNotes ? nil : 6)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        Group {
            if let chapters = mergedEpisode.chapters, !chapters.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Chapters")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    ForEach(chapters) { chapter in
                        Button {
                            playbackService.seek(to: chapter.startTime)
                        } label: {
                            HStack {
                                Text(formatTime(chapter.startTime))
                                    .font(DesignSystem.Typography.captionSmall())
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .frame(width: 50, alignment: .leading)

                                Text(chapter.title)
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Data Loading

    private func loadMediaLinks() async {
        isLoadingLinks = true
        mediaLinks = await MediaLinkingService.shared.extractMediaLinks(from: mergedEpisode)
        isLoadingLinks = false
    }

    private func reloadTranscript() async {
        isLoadingTranscript = true
        fullTranscript = await TranscriptService.shared.getFullTranscript(for: mergedEpisode)
        isLoadingTranscript = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
