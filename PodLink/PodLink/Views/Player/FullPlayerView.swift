import SwiftUI

struct FullPlayerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @State private var showQueue = false
    @State private var showSleepTimer = false
    @State private var mediaLinks: [MediaLink] = []

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Drag handle
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .padding(.top, DesignSystem.Spacing.sm)

                artwork
                episodeInfo
                progressSection
                controlsSection
                speedControl
                utilityButtons
                mediaLinksCarousel
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, 40)
        }
        .background(themeManager.currentTheme.backgroundTint.opacity(0.5))
        .bottomSheetPullToDismiss()
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(themeManager)
                .environment(playbackService)
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerView()
                .environment(themeManager)
                .environment(playbackService)
        }
        .task {
            if let episode = playbackService.state.currentEpisode {
                mediaLinks = await MediaLinkingService.shared.extractMediaLinks(from: episode)
            }
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        Group {
            if playbackService.state.isVideoMode,
               let episode = playbackService.state.currentEpisode,
               episode.videoURL != nil {
                VideoPlayerView()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            } else {
                AsyncCachedImage(url: playbackService.state.currentEpisode?.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
    }

    // MARK: - Episode Info

    private var episodeInfo: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            if let episode = playbackService.state.currentEpisode {
                Text(episode.title)
                    .font(DesignSystem.Typography.headlineLarge())
                    .foregroundColor(DesignSystem.Colors.headlineColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let podcast = playbackService.state.currentPodcast {
                Text(podcast.title)
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Slider(
                value: Binding(
                    get: { playbackService.state.currentTime },
                    set: { playbackService.seek(to: $0) }
                ),
                in: 0...max(playbackService.state.duration, 1)
            )
            .tint(themeManager.currentTheme.accentColor)

            HStack {
                Text(playbackService.state.formattedCurrentTime)
                Spacer()
                Text(playbackService.state.formattedRemainingTime)
            }
            .font(DesignSystem.Typography.caption())
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: DesignSystem.Spacing.xxl) {
            Button { playbackService.skipBackward() } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Button { playbackService.togglePlayPause() } label: {
                Image(systemName: playbackService.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }

            Button { playbackService.skipForward() } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text("Speed")
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
            ForEach(speeds, id: \.self) { speed in
                Button {
                    playbackService.setRate(speed)
                } label: {
                    Text(speed == 1.0 ? "1×" : String(format: "%.2g×", speed))
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(playbackService.state.playbackRate == speed
                            ? themeManager.currentTheme.accentColor
                            : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background {
                            if playbackService.state.playbackRate == speed {
                                Capsule()
                                    .fill(themeManager.currentTheme.accentColor.opacity(0.15))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Utility Buttons

    private var utilityButtons: some View {
        HStack(spacing: DesignSystem.Spacing.xxl) {
            Button { showQueue = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                    Text("Queue")
                        .font(DesignSystem.Typography.caption())
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Button { showSleepTimer = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 18))
                    Text(playbackService.state.sleepTimerRemainingMinutes.map { "\($0) min" } ?? "Sleep")
                        .font(DesignSystem.Typography.caption())
                }
                .foregroundColor(playbackService.state.sleepTimerEnd != nil
                    ? themeManager.currentTheme.accentColor
                    : DesignSystem.Colors.textSecondary)
            }

            if playbackService.state.currentEpisode?.hasVideo == true {
                Button {
                    if playbackService.state.isVideoMode {
                        playbackService.disableVideoPlayback()
                    } else {
                        playbackService.enableVideoPlayback()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: playbackService.state.isVideoMode ? "video.fill" : "video")
                            .font(.system(size: 18))
                        Text("Video")
                            .font(DesignSystem.Typography.caption())
                    }
                    .foregroundColor(playbackService.state.isVideoMode
                        ? themeManager.currentTheme.accentColor
                        : DesignSystem.Colors.textSecondary)
                }
            }

            Button {} label: {
                VStack(spacing: 4) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 18))
                    Text("AirPlay")
                        .font(DesignSystem.Typography.caption())
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Media Links

    private var mediaLinksCarousel: some View {
        Group {
            if !mediaLinks.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Connected Media")
                        .font(DesignSystem.Typography.headlineSmall())
                        .foregroundColor(DesignSystem.Colors.headlineColor)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(mediaLinks) { link in
                                MediaLinkCardView(link: link)
                            }
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
    }
}
