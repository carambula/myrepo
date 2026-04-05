import SwiftUI

/// Vertical edge for the draggable floating mini player (overlay only).
enum MiniPlayerFloatVerticalSnap: String, CaseIterable {
    case bottom
    case top
}

enum MiniPlayerDockMode: String, CaseIterable {
    case floating
    case docked

    var displayName: String {
        switch self {
        case .floating: return "Floating"
        case .docked: return "Docked"
        }
    }

    var description: String {
        switch self {
        case .floating: return "Mini player floats above content in a separate layer"
        case .docked: return "Mini player sits at the top of the main library screen only"
        }
    }
}

/// Layout of the docked mini player along the top of the main screen.
enum MiniPlayerDockPresentation: String, CaseIterable {
    case fullBleed
    case card
    case inset

    var displayName: String {
        switch self {
        case .fullBleed: return "Full bleed"
        case .card: return "Card"
        case .inset: return "Inset"
        }
    }

    var description: String {
        switch self {
        case .fullBleed: return "Edge to edge under the navigation bar"
        case .card: return "Inset with rounded rectangle and shadow"
        case .inset: return "Inset margins, flush shape (no card chrome)"
        }
    }
}

enum MiniPlayerSize: String, CaseIterable {
    case microplayer
    case slim
    case medium
    case large

    var displayName: String {
        switch self {
        case .microplayer: return "Microplayer"
        case .slim: return "Slim"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var description: String {
        switch self {
        case .microplayer: return "Compact capsule with circular art progress and core transport controls"
        case .slim: return "Compact bar with basic controls"
        case .medium: return "Expanded with more controls"
        case .large: return "Full controls in compact layout"
        }
    }
}

struct MiniPlayerView: View {
    @Binding var showNowPlayingSheet: Bool

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(NetworkStatusService.self) private var networkStatusService

    @AppStorage("miniPlayerDockMode") private var dockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var playerSize = MiniPlayerSize.slim.rawValue
    @AppStorage("miniPlayerDockPresentation") private var dockPresentationRaw = MiniPlayerDockPresentation.fullBleed.rawValue
    @AppStorage("miniPlayerFloatVerticalSnap") private var floatVerticalSnapRaw = MiniPlayerFloatVerticalSnap.bottom.rawValue
    @State private var floatingDragOffsetY: CGFloat = 0
    @State private var artworkBufferThrob = false

    private var dockPresentation: MiniPlayerDockPresentation {
        MiniPlayerDockPresentation(rawValue: dockPresentationRaw) ?? .fullBleed
    }

    private var currentDockMode: MiniPlayerDockMode {
        MiniPlayerDockMode(rawValue: dockMode) ?? .floating
    }

    private var currentSize: MiniPlayerSize {
        MiniPlayerSize(rawValue: playerSize) ?? .slim
    }

    private var floatVerticalSnap: MiniPlayerFloatVerticalSnap {
        MiniPlayerFloatVerticalSnap(rawValue: floatVerticalSnapRaw) ?? .bottom
    }

    private var currentEpisodeEffectivelyFinished: Bool {
        guard let episode = playbackService.state.currentEpisode else { return false }
        if episode.isPlayed { return true }
        let d = PlaybackProgressPolicy.current.effectiveDuration(
            feedDuration: episode.duration,
            observedDuration: playbackService.state.duration
        )
        guard d > 0 else { return false }
        return PlaybackProgressPolicy.current.isFinished(
            playbackPosition: playbackService.state.currentTime,
            duration: d
        )
    }

    private var currentEpisodeCanPlayOffline: Bool {
        guard let episode = playbackService.state.currentEpisode else { return true }
        let merged = EpisodePlaybackStore.merge(episode)
        return merged.isDownloaded || merged.downloadedFileURL != nil
    }

    private var restrictTransportForOfflineStream: Bool {
        !networkStatusService.isOnline && !currentEpisodeCanPlayOffline
    }

    private func episodeListArtworkURL(episode: Episode) -> URL? {
        episode.artworkURL ?? playbackService.state.currentPodcast?.displayArtworkURL
    }

    var body: some View {
        if playbackService.state.currentEpisode != nil {
            if currentSize == .microplayer {
                floatingMicroplayerView
            } else if currentDockMode == .docked {
                dockedPlayerView
            } else {
                floatingPlayerView
            }
        }
    }

    // MARK: - Floating (rounded rectangle + drag / fling snap)

    /// Lays out inside the overlay’s short UIKit strip (pinned top or bottom); avoids a full-screen SwiftUI layer that eats all touches.
    private var floatingPlayerView: some View {
        let pinnedBottom = floatVerticalSnap == .bottom
        return VStack(spacing: 0) {
            if pinnedBottom {
                Spacer(minLength: 0)
                floatingRoundedRectangleCard
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                    .offset(y: floatingDragOffsetY)
            } else {
                floatingRoundedRectangleCard
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .offset(y: floatingDragOffsetY)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: pinnedBottom ? .bottom : .top)
    }

    /// Matches the pre-merge floating chrome: material rounded rect, artwork + title + play, progress inside the card.
    private var floatingRoundedRectangleCard: some View {
        Group {
            if let episode = playbackService.state.currentEpisode {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button {
                            showNowPlayingSheet = true
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                AsyncCachedImage(url: episodeListArtworkURL(episode: episode)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .fill(Color(.tertiarySystemFill))
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))

                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(episode.title)
                                        .font(DesignSystem.Typography.bodyMedium())
                                        .foregroundColor(
                                            currentEpisodeEffectivelyFinished
                                                ? DesignSystem.Colors.textSecondary
                                                : DesignSystem.Colors.textPrimary
                                        )
                                        .lineLimit(2)

                                    if let podcast = playbackService.state.currentPodcast {
                                        Text(podcast.title)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            playbackService.togglePlayPause()
                        } label: {
                            Image(systemName: playbackService.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, DesignSystem.Spacing.md)
                        .disabled(restrictTransportForOfflineStream)
                    }

                    GeometryReader { progressGeo in
                        let w = progressGeo.size.width
                        let fraction = playbackService.state.progress
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 3)
                            Capsule()
                                .fill(themeManager.currentTheme.accentColor)
                                .frame(width: max(3, w * fraction), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                        .fill(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                }
                .simultaneousGesture(floatingSnapDragGesture)
            }
        }
    }

    private var floatingSnapDragGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                floatingDragOffsetY = value.translation.height
            }
            .onEnded { value in
                let translation = value.translation.height
                let flingDelta = value.predictedEndTranslation.height - translation
                let fromBottom = floatVerticalSnap == .bottom

                let shouldSnapTop: Bool
                if fromBottom {
                    shouldSnapTop = translation < -64 || flingDelta < -320
                } else {
                    shouldSnapTop = !(translation > 64 || flingDelta > 320)
                }

                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    floatVerticalSnapRaw = shouldSnapTop
                        ? MiniPlayerFloatVerticalSnap.top.rawValue
                        : MiniPlayerFloatVerticalSnap.bottom.rawValue
                    floatingDragOffsetY = 0
                }
            }
    }

    @ViewBuilder
    private var openNowPlayingLabel: some View {
        if let episode = playbackService.state.currentEpisode {
            Button {
                showNowPlayingSheet = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    AsyncCachedImage(url: episodeListArtworkURL(episode: episode)) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color(.tertiarySystemFill))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(
                                currentEpisodeEffectivelyFinished
                                    ? DesignSystem.Colors.textSecondary
                                    : DesignSystem.Colors.textPrimary
                            )
                            .lineLimit(1)

                        if let podcast = playbackService.state.currentPodcast {
                            Text(podcast.title)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Docked

    private var dockedPlayerView: some View {
        VStack(spacing: 0) {
            switch currentSize {
            case .microplayer:
                microplayerDockedPlayer
            case .slim:
                slimDockedPlayer
            case .medium:
                mediumDockedPlayer
            case .large:
                largeDockedPlayer
            }
        }
    }

    private var microplayerContainerHeight: CGFloat { 56 }
    private var microplayerArtworkOuterSize: CGFloat { 42 }
    private var microplayerArtworkInnerSize: CGFloat { 34 }
    private var microplayerIconHitSize: CGFloat { 32 }

    private var microplayerRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if let episode = playbackService.state.currentEpisode {
                Button {
                    showNowPlayingSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2.5)

                        Circle()
                            .trim(from: 0, to: min(max(playbackService.state.progress, 0), 1))
                            .stroke(
                                themeManager.currentTheme.accentColor,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        AsyncCachedImage(url: episodeListArtworkURL(episode: episode)) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                        }
                        .frame(width: microplayerArtworkInnerSize, height: microplayerArtworkInnerSize)
                        .clipShape(Circle())
                    }
                    .frame(width: microplayerArtworkOuterSize, height: microplayerArtworkOuterSize)
                    .scaleEffect(artworkBufferThrob ? 0.85 : 1.0)
                    .opacity(artworkBufferThrob ? 0.5 : 1.0)
                    .onChange(of: playbackService.state.isBuffering) { _, buffering in
                        if buffering {
                            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                artworkBufferThrob = true
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                artworkBufferThrob = false
                            }
                        }
                    }
                    .onAppear {
                        guard playbackService.state.isBuffering else { return }
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            artworkBufferThrob = true
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open now playing")
            }

            Button {
                playbackService.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: microplayerIconHitSize, height: microplayerIconHitSize)
            }
            .buttonStyle(.plain)
            .disabled(restrictTransportForOfflineStream)

            Button {
                playbackService.togglePlayPause()
            } label: {
                Image(systemName: playbackService.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: microplayerIconHitSize, height: microplayerIconHitSize)
            }
            .buttonStyle(.plain)
            .disabled(restrictTransportForOfflineStream)

            Button {
                playbackService.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: microplayerIconHitSize, height: microplayerIconHitSize)
            }
            .buttonStyle(.plain)
            .disabled(restrictTransportForOfflineStream)

            if !playbackService.state.queue.isEmpty {
                Button {
                    Task { await playbackService.playNextInQueue() }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: microplayerIconHitSize, height: microplayerIconHitSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play next in queue")
            }
        }
        .padding(.leading, DesignSystem.Spacing.sm)
        .padding(.trailing, DesignSystem.Spacing.sm)
        .frame(height: microplayerContainerHeight)
        .frostedSurface(Capsule())
    }

    private var floatingMicroplayerView: some View {
        let pinnedBottom = floatVerticalSnap == .bottom
        return VStack(spacing: 0) {
            if pinnedBottom {
                Spacer(minLength: 0)
                microplayerRow
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            } else {
                microplayerRow
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.top, DesignSystem.Spacing.sm)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: pinnedBottom ? .bottom : .top)
    }

    private var microplayerDockedPlayer: some View {
        Group {
            switch dockPresentation {
            case .fullBleed, .inset:
                microplayerRow
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            case .card:
                microplayerRow
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    private var slimDockedControlRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            openNowPlayingLabel
            Spacer(minLength: 0)
            Button {
                playbackService.togglePlayPause()
            } label: {
                Image(systemName: playbackService.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(restrictTransportForOfflineStream)
            Button {
                playbackService.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(restrictTransportForOfflineStream)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var slimDockedProgress: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(themeManager.currentTheme.accentColor)
                .frame(width: geo.size.width * playbackService.state.progress, height: 3)
        }
        .frame(height: 3)
    }

    private var slimDockedPlayer: some View {
        Group {
            switch dockPresentation {
            case .fullBleed:
                VStack(spacing: 0) {
                    slimDockedControlRow
                        .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    slimDockedProgress
                }
            case .inset:
                VStack(spacing: 0) {
                    slimDockedControlRow
                    slimDockedProgress
                }
                .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.sm)
            case .card:
                VStack(spacing: 0) {
                    slimDockedControlRow
                    slimDockedProgress
                }
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous)
                        .fill(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    private var mediumDockedBody: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                showNowPlayingSheet = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    if let episode = playbackService.state.currentEpisode {
                        dockArtwork(episode: episode, size: 60)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let episode = playbackService.state.currentEpisode {
                            Text(episode.title)
                                .font(DesignSystem.Typography.bodyMedium())
                                .foregroundColor(
                                    currentEpisodeEffectivelyFinished
                                        ? DesignSystem.Colors.textSecondary
                                        : DesignSystem.Colors.textPrimary
                                )
                                .lineLimit(2)
                        }

                        if let podcast = playbackService.state.currentPodcast {
                            Text(podcast.title)
                                .font(DesignSystem.Typography.bodySmall())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.sm)

            HStack(spacing: DesignSystem.Spacing.xxl) {
                Button {
                    playbackService.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)

                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)

                Button {
                    playbackService.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.sm)

            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 3)
            }
            .frame(height: 3)
        }
    }

    private var mediumDockedPlayer: some View {
        Group {
            switch dockPresentation {
            case .fullBleed:
                mediumDockedBody
                    .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
            case .inset:
                mediumDockedBody
                    .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            case .card:
                mediumDockedBody
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous)
                            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    private var largeDockedBody: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                if let episode = playbackService.state.currentEpisode {
                    dockArtwork(episode: episode, size: 100)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let episode = playbackService.state.currentEpisode {
                        Text(episode.title)
                            .font(DesignSystem.Typography.headlineSmall())
                            .foregroundColor(
                                currentEpisodeEffectivelyFinished
                                    ? DesignSystem.Colors.textSecondary
                                    : DesignSystem.Colors.textPrimary
                            )
                            .lineLimit(2)
                    }

                    if let podcast = playbackService.state.currentPodcast {
                        Text(podcast.title)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack {
                        Text(playbackService.state.formattedCurrentTime)
                        Spacer()
                        Text(playbackService.state.formattedRemainingTime)
                    }
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.trailing, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                showNowPlayingSheet = true
            }

            Slider(
                value: Binding(
                    get: { playbackService.state.currentTime },
                    set: { playbackService.seek(to: $0) }
                ),
                in: 0...max(playbackService.state.duration, 1)
            )
            .tint(themeManager.currentTheme.accentColor)
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            HStack(spacing: DesignSystem.Spacing.xxl) {
                Button {
                    playbackService.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)

                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)

                Button {
                    playbackService.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(restrictTransportForOfflineStream)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            HStack(spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
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

                Spacer()

                Button { showNowPlayingSheet = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.sm)

            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 3)
            }
            .frame(height: 3)
        }
    }

    private var largeDockedPlayer: some View {
        Group {
            switch dockPresentation {
            case .fullBleed:
                largeDockedBody
                    .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
            case .inset:
                largeDockedBody
                    .background(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            case .card:
                largeDockedBody
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous)
                            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.92))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    private func dockArtwork(episode: Episode, size: CGFloat) -> some View {
        AsyncCachedImage(url: episodeListArtworkURL(episode: episode)) { image in
            image
                .resizable()
                .aspectRatio(1, contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(.tertiarySystemFill))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }
}

// MARK: - Main screen (non-overlay) docked slot

/// Docked mini player lives in the primary `NavigationStack` so it does not float above sheets.
struct MainScreenDockedMiniPlayerSlot: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(NetworkStatusService.self) private var networkStatusService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue

    private var shouldShow: Bool {
        hasCompletedOnboarding
            && miniPlayerDockMode == MiniPlayerDockMode.docked.rawValue
            && miniPlayerSize != MiniPlayerSize.microplayer.rawValue
            && playbackService.state.currentEpisode != nil
            && !playbackService.isEpisodePlayerUIVisible
    }

    var body: some View {
        Group {
            if shouldShow {
                MiniPlayerView(showNowPlayingSheet: Binding(
                    get: { playbackService.isNowPlayingSheetPresented },
                    set: { playbackService.isNowPlayingSheetPresented = $0 }
                ))
                .environment(themeManager)
                .environment(playbackService)
                .environment(networkStatusService)
                .frame(maxWidth: .infinity)
                .transition(.offset(y: -UIScreen.main.bounds.height))
            }
        }
        .animation(.spring(response: 0.35), value: shouldShow)
        .animation(.spring(response: 0.35), value: playbackService.state.currentEpisode != nil)
        .animation(.spring(response: 0.35), value: playbackService.isEpisodePlayerUIVisible)
    }
}
