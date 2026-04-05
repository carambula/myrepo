import SwiftUI

struct VideoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoUnmuteVideos") private var autoUnmuteVideos = true
    @AppStorage("backgroundPlaybackBehavior") private var backgroundPlaybackBehaviorRawValue = BackgroundPlaybackBehavior.continuePlaying.rawValue
    @AppStorage("videoDetailPresentationMode") private var videoDetailPresentationModeRawValue = VideoDetailPresentationMode.fullYouTubePage.rawValue
    @State private var collapseWatchPageToAppDetails = false
    @State private var pauseSignal = 0
    let video: YTVideo
    let channel: YTChannel?
    let theme: AppTheme
    let onPlayFullscreen: (YTVideo) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    switch videoDetailPresentationMode {
                    case .fullYouTubePage:
                        if collapseWatchPageToAppDetails {
                            thumbnailPlayerCard
                            videoMetadata
                            Button("Show YouTube page again") {
                                collapseWatchPageToAppDetails = false
                            }
                            .buttonStyle(DesignSystemButtonStyle(variant: .ghost, size: .small))
                        } else {
                            YouTubePlayerView(
                                videoID: video.videoID,
                                autoPlay: false,
                                allowInlinePlayback: true,
                                contentMode: .watchPage,
                                autoUnmute: autoUnmuteVideos,
                                pauseSignal: pauseSignal,
                                onWatchPageFullscreenExit: {
                                    collapseWatchPageToAppDetails = true
                                }
                            )
                            .frame(height: 620)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
                        }

                    case .videoOnlyWithAppUI:
                        embeddedVideoPlayer
                        Button("Play fullscreen") {
                            onPlayFullscreen(video)
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
                        videoMetadata

                    case .thumbnailAndPlayButton:
                        thumbnailPlayerCard
                        videoMetadata
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .themeBackground(using: theme)
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                            .viewControlIconStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                }
            }
        }
        .bottomSheetPullToDismiss()
        .onChange(of: scenePhase) {
            if scenePhase == .background, backgroundPlaybackBehavior == .pausePlayback {
                pauseSignal += 1
            }
        }
    }

    private var videoDetailPresentationMode: VideoDetailPresentationMode {
        VideoDetailPresentationMode(rawValue: videoDetailPresentationModeRawValue) ?? .fullYouTubePage
    }

    private var embeddedVideoPlayer: some View {
        ZStack(alignment: .bottomTrailing) {
            // Always render a visible poster so this area is never blank.
            CachedAsyncImage(url: URL(string: video.thumbnailURL), initialBlurRadius: 20) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(theme.surface.opacity(0.9))
            }

            YouTubePlayerView(
                videoID: video.videoID,
                autoPlay: false,
                allowInlinePlayback: true,
                contentMode: .embeddedFrame,
                autoUnmute: autoUnmuteVideos,
                pauseSignal: pauseSignal
            )

            Button {
                onPlayFullscreen(video)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Play fullscreen")
        }
        .frame(height: 220)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
    }

    private var thumbnailPlayerCard: some View {
        Button {
            onPlayFullscreen(video)
        } label: {
            ZStack {
                CachedAsyncImage(url: URL(string: video.thumbnailURL), initialBlurRadius: 28) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(theme.surface.opacity(0.85))
                }

                Image(systemName: "play.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(.black.opacity(0.68))
                    .clipShape(Circle())
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play video full screen")
    }

    private var backgroundPlaybackBehavior: BackgroundPlaybackBehavior {
        BackgroundPlaybackBehavior(rawValue: backgroundPlaybackBehaviorRawValue) ?? .continuePlaying
    }

    private var videoMetadata: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text(video.title.decodedHTMLEntities)
                .font(DesignSystem.Typography.displayMedium)
                .foregroundStyle(theme.text)

            if let channel {
                        Text(channel.title.decodedHTMLEntities)
                    .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Button {
                UIPasteboard.general.string = "https://www.youtube.com/watch?v=\(video.videoID)"
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .large))

                    if !video.summary.isEmpty {
                        Text(video.summary.decodedHTMLEntities)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }
}
