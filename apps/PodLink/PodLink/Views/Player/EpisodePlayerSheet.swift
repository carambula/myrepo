import SwiftUI
import UIKit

/// The episode surface: full player chrome, show context (notes, chapters, etc.), and playback.
/// Presented from podcast detail (nested sheet), the mini player / root sheet, etc.—same UI, one concept.
struct EpisodePlayerSheet: View {
    let episode: Episode
    /// Used when the episode is opened from listening history or another path where the show may not be followed.
    var fallbackPodcast: Podcast? = nil
    /// After the player dismisses, run extra navigation (e.g. present the podcast from the root sheet).
    var onOpenPodcast: ((Podcast) -> Void)? = nil

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService
    @Environment(\.dismiss) private var dismiss

    @State private var mediaLinks: [MediaLink] = []
    @State private var isLoadingLinks = false
    @State private var showFullNotes = false
    @State private var showNotesAttributed = AttributedString()
    @State private var isAIRefiningNotes = false
    @State private var fullTranscript: FullTranscript?
    @State private var isLoadingTranscript = false
    @State private var playbackMergeTick = 0
    @State private var overlaySheet: PlayerChromeOverlaySheet?

    private var mergedEpisode: Episode {
        _ = playbackMergeTick
        return EpisodePlaybackStore.merge(episode)
    }

    private var isCurrentEpisode: Bool {
        playbackService.state.currentEpisode?.id == episode.id
    }

    private var listeningDuration: TimeInterval {
        if isCurrentEpisode, playbackService.state.duration > 0 {
            return PlaybackProgressPolicy.current.effectiveDuration(
                feedDuration: episode.duration,
                observedDuration: playbackService.state.duration
            )
        }
        return mergedEpisode.duration
    }

    private var listeningPosition: TimeInterval {
        if isCurrentEpisode { return playbackService.state.currentTime }
        return mergedEpisode.playbackPosition
    }

    private var detailFinished: Bool {
        if mergedEpisode.isPlayed { return true }
        guard listeningDuration > 0 else { return false }
        return PlaybackProgressPolicy.current.isFinished(
            playbackPosition: listeningPosition,
            duration: listeningDuration
        )
    }

    private var scrubRange: ClosedRange<Double> {
        0...max(listeningDuration, 1)
    }

    private var contextPodcast: Podcast? {
        if let fallbackPodcast { return fallbackPodcast }
        let followed = Podcast.loadFollowedPodcasts()
        if let p = followed.first(where: { $0.id == episode.podcastID }) { return p }
        return followed.first(where: { $0.feedURL.absoluteString == episode.podcastID })
    }

    private var scrubBinding: Binding<TimeInterval> {
        Binding(
            get: { listeningPosition },
            set: { newTime in
                if isCurrentEpisode {
                    playbackService.seek(to: newTime)
                } else {
                    EpisodePlaybackStore.persistPosition(newTime, episodeID: episode.id)
                    playbackMergeTick += 1
                    var snap = EpisodePlaybackStore.merge(episode)
                    snap.playbackPosition = newTime
                    ListeningHistoryStore.recordListening(
                        episode: snap,
                        podcast: contextPodcast,
                        position: newTime,
                        duration: listeningDuration
                    )
                }
            }
        )
    }

    private var progressElapsedLabel: String {
        if isCurrentEpisode {
            return playbackService.state.formattedCurrentTime
        }
        return formatListeningTime(listeningPosition)
    }

    private var progressRemainingLabel: String {
        if isCurrentEpisode {
            return playbackService.state.formattedRemainingTime
        }
        let rem = max(0, listeningDuration - listeningPosition)
        return "-\(formatListeningTime(rem))"
    }

    private var isPlayingThisEpisode: Bool {
        isCurrentEpisode && playbackService.state.isPlaying
    }

    private var shouldDisableTransportForDifferentActiveEpisode: Bool {
        playbackService.state.isPlaying && !isCurrentEpisode
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

    // MARK: - Sharing

    /// Direct, playable link to the episode — works for recipients regardless of whether they have PodLink.
    private var episodeShareURL: URL? {
        mergedEpisode.audioURL
    }

    private var episodeShareSubject: String {
        mergedEpisode.title
    }

    private var episodeShareMessage: String {
        if let podcastTitle = contextPodcast?.title, !podcastTitle.isEmpty {
            return "\(mergedEpisode.title) from \(podcastTitle)"
        }
        return mergedEpisode.title
    }

    var body: some View {
        PlayerSheetChrome(
            artwork: { episodeArtwork },
            episodeHeader: { episodeInfoBlock },
            belowChrome: { episodeBelowChrome },
            overlaySheet: $overlaySheet,
            scrubTime: scrubBinding,
            scrubRange: scrubRange,
            elapsedLabel: progressElapsedLabel,
            remainingLabel: progressRemainingLabel,
            onSkipBackward: skipBackward,
            onSkipForward: skipForward,
            onPlayPause: togglePlayPause,
            onShowQueue: { overlaySheet = .queue },
            onPlayNextInQueue: { Task { await playbackService.playNextInQueue() } },
            hasQueuedEpisodes: !playbackService.state.queue.isEmpty,
            isSkipBackwardEnabled: !shouldDisableTransportForDifferentActiveEpisode,
            isSkipForwardEnabled: !shouldDisableTransportForDifferentActiveEpisode,
            isPlayNextInQueueEnabled: !shouldDisableTransportForDifferentActiveEpisode,
            isPlaying: isPlayingThisEpisode,
            isPlayPauseEnabled: !shouldRestrictNetworkOnlyEpisodeActions,
            onAddToQueue: { playbackService.addToQueue(mergedEpisode) },
            isAddToQueueEnabled: !shouldRestrictNetworkOnlyEpisodeActions,
            onToggleDownload: toggleDownload,
            downloadIconName: downloadIconName,
            downloadIconColor: downloadIconColor,
            downloadAccessibilityLabel: downloadAccessibilityLabel,
            isDownloadInProgress: downloadState == .downloading,
            isDownloadEnabled: !shouldRestrictNetworkOnlyEpisodeActions,
            isSaved: mergedEpisode.isBookmarked,
            onToggleSave: toggleSaved,
            hasVideo: mergedEpisode.hasVideo,
            isVideoMode: isCurrentEpisode && playbackService.state.isVideoMode,
            onToggleVideo: toggleVideoForThisEpisode,
            shareURL: episodeShareURL,
            shareSubject: episodeShareSubject,
            shareMessage: episodeShareMessage,
            scrollBottomPadding: SheetPullToDismissLayout.scrollContentBottomInset(playbackService: playbackService)
        )
        .background((themeManager.currentTheme.backgroundTint ?? .clear).opacity(0.5))
        .bottomSheetPullToDismiss()
        .sheet(item: $overlaySheet) { sheet in
            switch sheet {
            case .queue:
                QueueView()
                    .environment(themeManager)
                    .environment(playbackService)
            case .sleepTimer:
                SleepTimerView()
                    .environment(themeManager)
                    .environment(playbackService)
            }
        }
        .task {
            await loadMediaLinks()
            await reloadTranscript()
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { output in
            guard (output.object as? String) == episode.id else { return }
            playbackMergeTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodeDownloadStateDidChange)) { output in
            guard (output.object as? String) == episode.id else { return }
            playbackMergeTick += 1
        }
        .onAppear {
            playbackService.pushEpisodePlayerUISession()
            syncShowNotesFromEpisode()
        }
        .onDisappear { playbackService.popEpisodePlayerUISession() }
        .task(id: "\(mergedEpisode.id)-\(themeManager.currentTheme.id)") {
            syncShowNotesFromEpisode()
            let accent = UIColor(themeManager.currentTheme.accentColor)
            await refineShowNotesIfNeeded(raw: mergedEpisode.description, accent: accent)
        }
    }

    // MARK: - Artwork

    private var episodeArtwork: some View {
        Group {
            if isCurrentEpisode,
               playbackService.state.isVideoMode,
               mergedEpisode.videoURL != nil {
                VideoPlayerView()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                AsyncCachedImage(url: mergedEpisode.resolvedArtworkURL(podcast: contextPodcast)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Color(.tertiarySystemFill)
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                        .aspectRatio(1, contentMode: .fill)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()
            }
        }
    }

    // MARK: - Episode info

    private var podcastTitleTap: (() -> Void)? {
        guard let podcast = contextPodcast else { return nil }
        return {
            onOpenPodcast?(podcast)
            dismiss()
        }
    }

    private var episodeInfoBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            PlayerEpisodeHeaderCore(
                title: mergedEpisode.title,
                podcastTitle: contextPodcast?.title,
                titleUsesSecondaryStyle: detailFinished,
                onPodcastTitleTap: podcastTitleTap
            )

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
            .font(DesignSystem.Typography.bodySmall())
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Below chrome

    @ViewBuilder
    private var episodeBelowChrome: some View {
        mediaLinksSection
        showNotesSection
        chaptersSection
        transcriptSection
    }

    private func togglePlayPause() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        if isCurrentEpisode {
            playbackService.togglePlayPause()
        } else {
            Task { await playbackService.play(episode: mergedEpisode, podcast: contextPodcast) }
        }
    }

    private func skipBackward() {
        if isCurrentEpisode {
            playbackService.skipBackward()
        } else {
            let t = max(0, listeningPosition - 15)
            EpisodePlaybackStore.persistPosition(t, episodeID: episode.id)
            playbackMergeTick += 1
            var snap = EpisodePlaybackStore.merge(episode)
            snap.playbackPosition = t
            ListeningHistoryStore.recordListening(episode: snap, podcast: contextPodcast, position: t, duration: listeningDuration)
        }
    }

    private func skipForward() {
        if isCurrentEpisode {
            playbackService.skipForward()
        } else {
            let t = min(max(listeningDuration, 0), listeningPosition + 30)
            EpisodePlaybackStore.persistPosition(t, episodeID: episode.id)
            playbackMergeTick += 1
            var snap = EpisodePlaybackStore.merge(episode)
            snap.playbackPosition = t
            ListeningHistoryStore.recordListening(episode: snap, podcast: contextPodcast, position: t, duration: listeningDuration)
        }
    }

    private func toggleSaved() {
        let next = !mergedEpisode.isBookmarked
        EpisodePlaybackStore.persistBookmark(next, episodeID: episode.id)
        playbackMergeTick += 1
    }

    private func toggleDownload() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        switch downloadState {
        case .downloaded:
            downloadManager.deleteDownload(for: mergedEpisode)
        case .downloading:
            downloadManager.deleteDownload(for: mergedEpisode)
        case .notDownloaded, .failed:
            downloadManager.startDownload(for: mergedEpisode, podcast: contextPodcast)
        }
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
        return DesignSystem.Colors.textSecondary
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

    private func toggleVideoForThisEpisode() {
        if shouldRestrictNetworkOnlyEpisodeActions { return }
        if isCurrentEpisode {
            if playbackService.state.isVideoMode {
                playbackService.disableVideoPlayback()
            } else {
                playbackService.enableVideoPlayback()
            }
        } else {
            Task {
                await playbackService.play(episode: mergedEpisode, podcast: contextPodcast)
                playbackService.enableVideoPlayback()
            }
        }
    }

    // MARK: - Media Links

    private var mediaLinksSection: some View {
        Group {
            if !mediaLinks.isEmpty || isLoadingLinks {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Connected Media")
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    if isLoadingLinks {
                        HStack {
                            ProgressView()
                            Text("Analyzing episode...")
                                .font(DesignSystem.Typography.bodySmall())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                ForEach(mediaLinks) { link in
                                    MediaLinkCardView(link: link)
                                }
                            }
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Show Notes

    private var showNotesExpansionControl: Bool {
        mergedEpisode.description.count > 320
    }

    private var showNotesSection: some View {
        Group {
            if !mergedEpisode.description.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                        Text("Show Notes")
                            .font(DesignSystem.Typography.headlineMedium())
                            .foregroundColor(DesignSystem.Colors.headlineColor)
                        if isAIRefiningNotes {
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                    }

                    Text(showNotesAttributed)
                        .lineLimit(showFullNotes ? nil : 8)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .tint(themeManager.currentTheme.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showNotesExpansionControl {
                        Button {
                            withAnimation(DesignSystem.Animation.quick) { showFullNotes.toggle() }
                        } label: {
                            Text(showFullNotes ? "Show less" : "Show more")
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    private func syncShowNotesFromEpisode() {
        showNotesAttributed = ShowNotesFormattedContent.attributedString(
            from: mergedEpisode.description,
            linkUIColor: UIColor(themeManager.currentTheme.accentColor)
        )
    }

    private func refineShowNotesIfNeeded(raw: String, accent: UIColor) async {
        guard ShowNotesAIMarkupService.shouldOffer(for: raw) else { return }
        isAIRefiningNotes = true
        defer { isAIRefiningNotes = false }
        if let md = await ShowNotesAIMarkupService.structuredMarkdown(from: raw) {
            showNotesAttributed = ShowNotesFormattedContent.attributedString(from: md, linkUIColor: accent)
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
                            seekToChapter(chapter.startTime)
                        } label: {
                            HStack {
                                Text(formatTime(chapter.startTime))
                                    .font(DesignSystem.Typography.caption())
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
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
    }

    private func seekToChapter(_ time: TimeInterval) {
        if isCurrentEpisode {
            playbackService.seek(to: time)
        } else {
            if shouldRestrictNetworkOnlyEpisodeActions { return }
            Task {
                await playbackService.play(episode: mergedEpisode, podcast: contextPodcast, startAt: time)
            }
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        EpisodeTranscriptDetailSection(
            episode: mergedEpisode,
            isLoading: isLoadingTranscript,
            fullTranscript: fullTranscript,
            onSeekFromTranscript: seekToChapter,
            onReloadTranscript: reloadTranscript,
            onRequestDownloadForTranscription: startDownloadForTranscription,
            isDownloadForTranscriptionInProgress: downloadState == .downloading,
            isDownloadForTranscriptionEnabled: !shouldRestrictNetworkOnlyEpisodeActions && downloadState != .downloaded,
            presentationContext: .player
        )
    }

    private func startDownloadForTranscription() {
        guard !shouldRestrictNetworkOnlyEpisodeActions else { return }
        guard downloadState != .downloading, downloadState != .downloaded else { return }
        downloadManager.startDownload(for: mergedEpisode, podcast: contextPodcast)
    }

    // MARK: - Data Loading

    private func loadMediaLinks() async {
        isLoadingLinks = true
        mediaLinks = await MediaLinkingService.shared.extractMediaLinks(from: episode)
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

    private func formatListeningTime(_ time: TimeInterval) -> String {
        let total = Int(max(0, time))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
