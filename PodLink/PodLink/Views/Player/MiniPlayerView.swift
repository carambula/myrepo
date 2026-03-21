import SwiftUI

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
        case .floating: return "Mini player floats above content"
        case .docked: return "Mini player docked at top of main view"
        }
    }
}

enum MiniPlayerSize: String, CaseIterable {
    case slim
    case medium
    case large
    
    var displayName: String {
        switch self {
        case .slim: return "Slim"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var description: String {
        switch self {
        case .slim: return "Compact bar with basic controls"
        case .medium: return "Expanded with more controls"
        case .large: return "Full controls in compact layout"
        }
    }
}

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    
    @AppStorage("miniPlayerDockMode") private var dockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var playerSize = MiniPlayerSize.slim.rawValue
    
    private var currentDockMode: MiniPlayerDockMode {
        MiniPlayerDockMode(rawValue: dockMode) ?? .floating
    }
    
    private var currentSize: MiniPlayerSize {
        MiniPlayerSize(rawValue: playerSize) ?? .slim
    }

    var body: some View {
        if playbackService.state.currentEpisode != nil {
            if currentDockMode == .docked {
                dockedPlayerView
            } else {
                floatingPlayerView
            }
        }
    }
    
    // MARK: - Floating Player (Original Style)
    
    private var floatingPlayerView: some View {
        VStack(spacing: 0) {
            slimPlayerContent
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                }
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
    
    // MARK: - Docked Player
    
    private var dockedPlayerView: some View {
        VStack(spacing: 0) {
            switch currentSize {
            case .slim:
                slimDockedPlayer
            case .medium:
                mediumDockedPlayer
            case .large:
                largeDockedPlayer
            }
        }
    }
    
    private var slimDockedPlayer: some View {
        VStack(spacing: 0) {
            Button { showFullPlayer = true } label: {
                slimPlayerContent
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(.ultraThinMaterial)
            
            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 3)
            }
            .frame(height: 3)
        }
    }
    
    private var mediumDockedPlayer: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button { showFullPlayer = true } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    artwork(size: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let episode = playbackService.state.currentEpisode {
                            Text(episode.title)
                                .font(DesignSystem.Typography.bodyMedium())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
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
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
            
            // Controls
            HStack(spacing: DesignSystem.Spacing.xxl) {
                Button {
                    playbackService.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                
                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                
                Button {
                    playbackService.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)
            
            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 3)
            }
            .frame(height: 3)
        }
        .background(.ultraThinMaterial)
    }
    
    private var largeDockedPlayer: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                artwork(size: 100)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let episode = playbackService.state.currentEpisode {
                        Text(episode.title)
                            .font(DesignSystem.Typography.headlineSmall())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    
                    if let podcast = playbackService.state.currentPodcast {
                        Text(podcast.title)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Time labels
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
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            
            // Seek slider
            Slider(
                value: Binding(
                    get: { playbackService.state.currentTime },
                    set: { playbackService.seek(to: $0) }
                ),
                in: 0...max(playbackService.state.duration, 1)
            )
            .tint(themeManager.currentTheme.accentColor)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Controls
            HStack(spacing: DesignSystem.Spacing.xxl) {
                Button {
                    playbackService.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                
                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                
                Button {
                    playbackService.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Speed and utility controls
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Speed control
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
                
                Button { showFullPlayer = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)
            
            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: geo.size.width * playbackService.state.progress, height: 3)
            }
            .frame(height: 3)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Shared Components
    
    private var slimPlayerContent: some View {
        Button { showFullPlayer = true } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                artwork(size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let episode = playbackService.state.currentEpisode {
                        Text(episode.title)
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    
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
        }
        .buttonStyle(.plain)
    }
    
    private func artwork(size: CGFloat) -> some View {
        Group {
            if let episode = playbackService.state.currentEpisode {
                AsyncCachedImage(url: episode.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .fill(Color(.tertiarySystemFill))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            }
        }
    }
}
