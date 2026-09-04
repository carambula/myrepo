import SwiftUI

private let playerChromePlaybackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

/// Title + show row shared by every `EpisodePlayerSheet` presentation (same fonts, limits, colors).
struct PlayerEpisodeHeaderCore: View {
    @Environment(ThemeManager.self) private var themeManager

    let title: String
    let podcastTitle: String?
    /// When true, title uses secondary color (finished / effectively finished).
    let titleUsesSecondaryStyle: Bool
    /// When set, the show title is tappable (e.g. dismiss player and open the podcast).
    var onPodcastTitleTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(
                    titleUsesSecondaryStyle
                        ? DesignSystem.Colors.textSecondary
                        : DesignSystem.Colors.headlineColor
                )
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)

            if let podcastTitle {
                if let onPodcastTitleTap {
                    Button(action: onPodcastTitleTap) {
                        Text(podcastTitle)
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Podcast")
                    .accessibilityHint("Opens the podcast")
                } else {
                    Text(podcastTitle)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

enum PlayerChromeOverlaySheet: Identifiable {
    case queue
    case sleepTimer

    var id: String {
        switch self {
        case .queue: return "queue"
        case .sleepTimer: return "sleepTimer"
        }
    }
}

/// Shared layout for `EpisodePlayerSheet`: handle, artwork, header block, scrubber, transport, utility row, then tail content.
struct PlayerSheetChrome<Artwork: View, EpisodeHeader: View, BelowChrome: View>: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    @ViewBuilder var artwork: () -> Artwork
    @ViewBuilder var episodeHeader: () -> EpisodeHeader
    @ViewBuilder var belowChrome: () -> BelowChrome

    @Binding var overlaySheet: PlayerChromeOverlaySheet?
    @Binding var scrubTime: TimeInterval
    var scrubRange: ClosedRange<Double>
    var elapsedLabel: String
    var remainingLabel: String

    var onSkipBackward: () -> Void
    var onSkipForward: () -> Void
    var onPlayPause: () -> Void
    var onShowQueue: () -> Void
    var onPlayNextInQueue: (() -> Void)? = nil
    var hasQueuedEpisodes: Bool = false
    var isSkipBackwardEnabled: Bool = true
    var isSkipForwardEnabled: Bool = true
    var isPlayNextInQueueEnabled: Bool = true
    var isPlaying: Bool
    var isPlayPauseEnabled: Bool = true

    var onAddToQueue: () -> Void
    var isAddToQueueEnabled: Bool = true
    var onToggleDownload: () -> Void
    var downloadIconName: String
    var downloadIconColor: Color
    var downloadAccessibilityLabel: String
    var isDownloadInProgress: Bool = false
    var isDownloadEnabled: Bool = true
    var isSaved: Bool
    var onToggleSave: () -> Void

    var hasVideo: Bool
    var isVideoMode: Bool
    var onToggleVideo: () -> Void

    var shareURL: URL? = nil
    var shareSubject: String = ""
    var shareMessage: String = ""

    var scrollBottomPadding: CGFloat

    @State private var playPauseThrob = false

    private var isBufferingThisEpisode: Bool {
        isPlaying && playbackService.state.isBuffering
    }

    private func speedLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1×" : String(format: "%.2g×", rate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Artwork only: do not add a second grabber here — it scrolls with content and
                // duplicates the system sheet drag indicator (root sheet) or looks wrong when pushed.
                artwork()
                    .frame(maxWidth: .infinity)

                VStack(spacing: DesignSystem.Spacing.lg) {
                    episodeHeader()

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Slider(value: $scrubTime, in: scrubRange)
                            .tint(themeManager.currentTheme.accentColor)

                        HStack {
                            Text(elapsedLabel)
                            Spacer()
                            Text(remainingLabel)
                        }
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack(spacing: DesignSystem.Spacing.xxl) {
                        Button(action: onShowQueue) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Button(action: onSkipBackward) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 28))
                                .foregroundColor(isSkipBackwardEnabled
                                    ? DesignSystem.Colors.textPrimary
                                    : DesignSystem.Colors.textTertiary)
                        }
                        .disabled(!isSkipBackwardEnabled)

                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(isPlayPauseEnabled
                                    ? themeManager.currentTheme.accentColor
                                    : DesignSystem.Colors.textTertiary)
                                .opacity(playPauseThrob ? 0.35 : 1.0)
                                .onChange(of: isBufferingThisEpisode) { _, buffering in
                                    if buffering {
                                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                            playPauseThrob = true
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            playPauseThrob = false
                                        }
                                    }
                                }
                                .onAppear {
                                    guard isBufferingThisEpisode else { return }
                                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                        playPauseThrob = true
                                    }
                                }
                        }
                        .disabled(!isPlayPauseEnabled)

                        Button(action: onSkipForward) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 28))
                                .foregroundColor(isSkipForwardEnabled
                                    ? DesignSystem.Colors.textPrimary
                                    : DesignSystem.Colors.textTertiary)
                        }
                        .disabled(!isSkipForwardEnabled)

                        if let onPlayNextInQueue {
                            Button(action: onPlayNextInQueue) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(hasQueuedEpisodes && isPlayNextInQueueEnabled
                                        ? DesignSystem.Colors.textPrimary
                                        : DesignSystem.Colors.textTertiary)
                            }
                            .accessibilityLabel("Play next in queue")
                            .disabled(!hasQueuedEpisodes || !isPlayNextInQueueEnabled)
                        }
                    }

                    HStack(spacing: DesignSystem.Spacing.xxl) {
                        Menu {
                            ForEach(playerChromePlaybackSpeeds, id: \.self) { speed in
                                Button {
                                    playbackService.setRate(speed)
                                } label: {
                                    if playbackService.state.playbackRate == speed {
                                        Label(speedLabel(speed), systemImage: "checkmark")
                                    } else {
                                        Text(speedLabel(speed))
                                    }
                                }
                            }
                        } label: {
                            Text(speedLabel(playbackService.state.playbackRate))
                                .font(DesignSystem.Typography.bodySmall())
                                .monospacedDigit()
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Button(action: onAddToQueue) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 22))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .accessibilityLabel("Add to queue")
                        .disabled(!isAddToQueueEnabled)

                        Button(action: onToggleDownload) {
                            DownloadStatusIcon(
                                iconName: downloadIconName,
                                iconColor: downloadIconColor,
                                isDownloading: isDownloadInProgress,
                                iconSize: 22,
                                frameSize: 22
                            )
                        }
                        .accessibilityLabel(downloadAccessibilityLabel)
                        .disabled(!isDownloadEnabled)

                        Button(action: onToggleSave) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 22))
                                .foregroundColor(isSaved
                                    ? themeManager.currentTheme.accentColor
                                    : DesignSystem.Colors.textSecondary)
                        }
                        .accessibilityLabel(isSaved ? "Remove from saved" : "Save episode")

                        if let shareURL {
                            ShareLink(
                                item: shareURL,
                                subject: Text(shareSubject),
                                message: Text(shareMessage)
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .accessibilityLabel("Share episode")
                        }

                        AirPlayRoutePickerView(
                            activeTintColor: UIColor(themeManager.currentTheme.accentColor),
                            inactiveTintColor: UIColor(DesignSystem.Colors.textSecondary)
                        )
                        .frame(width: 26, height: 26)
                        .accessibilityLabel("AirPlay")

                        Menu {
                            Button {
                                overlaySheet = .sleepTimer
                            } label: {
                                Label("Sleep Timer", systemImage: "moon.zzz")
                            }

                            if hasVideo {
                                Button(action: onToggleVideo) {
                                    Label(
                                        isVideoMode ? "Play Audio Only" : "Play Video",
                                        systemImage: isVideoMode ? "speaker.wave.2.fill" : "video.fill"
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundColor(playbackService.state.sleepTimerEnd != nil
                                    ? themeManager.currentTheme.accentColor
                                    : DesignSystem.Colors.textSecondary)
                        }
                        .accessibilityLabel("More options")
                    }

                    belowChrome()
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
            .padding(.bottom, scrollBottomPadding)
        }
    }
}
