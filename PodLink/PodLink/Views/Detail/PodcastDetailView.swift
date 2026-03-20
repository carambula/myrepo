import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast
    @Binding var selectedEpisode: Episode?

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var isFollowed: Bool = false
    @State private var showDescription = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                actionBar
                episodeList
            }
        }
        .background(themeManager.currentTheme.backgroundTint.opacity(0.3))
        .bottomSheetPullToDismiss()
        .task {
            await loadEpisodes()
            isFollowed = podcast.isFollowed
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Drag handle
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, DesignSystem.Spacing.sm)

            AsyncCachedImage(url: podcast.artworkURL600 ?? podcast.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(podcast.title)
                    .font(DesignSystem.Typography.headlineLarge())
                    .foregroundColor(DesignSystem.Colors.headlineColor)
                    .multilineTextAlignment(.center)

                Text(podcast.author)
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            if !podcast.description.isEmpty {
                Button {
                    withAnimation { showDescription.toggle() }
                } label: {
                    Text(podcast.description.strippingHTML)
                        .font(DesignSystem.Typography.bodySmall())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(showDescription ? nil : 3)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Play Latest
            Button {
                if let latest = episodes.first {
                    Task { await playbackService.play(episode: latest, podcast: podcast) }
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle())

            // Follow/Unfollow
            Button {
                isFollowed.toggle()
                toggleFollow()
            } label: {
                Image(systemName: isFollowed ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(isFollowed ? themeManager.currentTheme.accentColor : DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle())

            // Share
            Button {
                // Share podcast
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Episode List

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Episodes")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.headlineColor)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { episode in
                        EpisodeRowView(
                            episode: episode,
                            podcast: podcast,
                            onPlay: {
                                Task { await playbackService.play(episode: episode, podcast: podcast) }
                            },
                            onTap: {
                                selectedEpisode = episode
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadEpisodes() async {
        isLoading = true
        do {
            episodes = try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
        } catch {
            episodes = []
        }
        isLoading = false
    }

    private func toggleFollow() {
        var podcasts = loadFollowedPodcasts()
        if isFollowed {
            var updated = podcast
            updated.isFollowed = true
            if !podcasts.contains(where: { $0.id == podcast.id }) {
                podcasts.append(updated)
            }
        } else {
            podcasts.removeAll { $0.id == podcast.id }
        }
        saveFollowedPodcasts(podcasts)
    }

    private func loadFollowedPodcasts() -> [Podcast] {
        guard let data = UserDefaults.standard.data(forKey: "followedPodcasts"),
              let podcasts = try? JSONDecoder().decode([Podcast].self, from: data) else {
            return []
        }
        return podcasts
    }

    private func saveFollowedPodcasts(_ podcasts: [Podcast]) {
        if let data = try? JSONEncoder().encode(podcasts) {
            UserDefaults.standard.set(data, forKey: "followedPodcasts")
            NSUbiquitousKeyValueStore.default.set(data, forKey: "followedPodcasts")
        }
    }
}
