import SwiftUI

struct PodcastListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    @Binding var showAccountSheet: Bool
    @Binding var showSearch: Bool
    @Binding var selectedPodcast: Podcast?

    @AppStorage("posterSize") private var posterSize = "plus60"
    @AppStorage("layoutMode") private var layoutMode = "grid"
    @AppStorage("glassComponentStyle") private var glassStyle = "premium"
    @AppStorage("tapInteraction") private var tapInteraction = "bounce"
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = "floating"

    @State private var followedPodcasts: [Podcast] = []
    @State private var latestEpisodes: [String: Episode] = [:]
    @State private var isLoading = false
    
    private var bottomPadding: CGFloat {
        if miniPlayerDockMode == "docked" {
            return 70
        } else {
            return 120
        }
    }

    private var columns: [GridItem] {
        let size = artworkSize
        return [GridItem(.adaptive(minimum: size, maximum: size + 20), spacing: DesignSystem.Spacing.md)]
    }

    private var artworkSize: CGFloat {
        switch posterSize {
        case "plus10": return 110
        case "plus20": return 120
        case "plus40": return 140
        case "plus60": return 160
        default: return 160
        }
    }

    private var currentGlassStyle: GlassComponentStyle {
        GlassComponentStyle(rawValue: glassStyle) ?? .premium
    }

    private var currentTapStyle: TapInteractionStyle {
        TapInteractionStyle(rawValue: tapInteraction) ?? .bounce
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if followedPodcasts.isEmpty && !isLoading {
                    emptyState
                } else if layoutMode == "grid" {
                    gridLayout
                } else {
                    listLayout
                }
            }
            .refreshable {
                await refreshFeeds()
            }

            toolbar
        }
        .background(themeManager.currentTheme.backgroundTint.opacity(0.3))
        .task {
            await loadPodcasts()
        }
    }

    // MARK: - Grid Layout

    private var gridLayout: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
            ForEach(followedPodcasts) { podcast in
                podcastGridItem(podcast)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, bottomPadding)
    }

    private func podcastGridItem(_ podcast: Podcast) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .frame(width: artworkSize, height: artworkSize)

            Text(podcast.title)
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: artworkSize)
        }
        .tapInteraction(style: currentTapStyle) {
            selectedPodcast = podcast
        }
    }

    // MARK: - List Layout

    private var listLayout: some View {
        LazyVStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(followedPodcasts) { podcast in
                PodcastRowView(
                    podcast: podcast,
                    latestEpisode: latestEpisodes[podcast.id]
                )
                .tapInteraction(style: currentTapStyle) {
                    selectedPodcast = podcast
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, bottomPadding)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.currentTheme.accentColor)

            Text("No Podcasts Yet")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            Text("Search for podcasts to follow and start listening.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xxl)

            Button {
                showSearch = true
            } label: {
                Label("Find Podcasts", systemImage: "magnifyingglass")
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(themeManager.currentTheme.accentColor)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, bottomPadding)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: DesignSystem.Spacing.toolbarIconSpacing) {
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle(style: currentGlassStyle))

            Button { showAccountSheet = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle(style: currentGlassStyle))
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Data Loading

    private func loadPodcasts() async {
        isLoading = true
        // Load followed podcasts from UserDefaults/iCloud
        if let data = UserDefaults.standard.data(forKey: "followedPodcasts"),
           let podcasts = try? JSONDecoder().decode([Podcast].self, from: data) {
            followedPodcasts = podcasts
        }
        isLoading = false
    }

    private func refreshFeeds() async {
        for podcast in followedPodcasts {
            if let episodes = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL),
               let latest = episodes.first {
                latestEpisodes[podcast.id] = latest
            }
        }
    }
}
