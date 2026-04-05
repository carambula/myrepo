import SwiftUI

struct PodcastPickerView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var suggestedPodcasts: [Podcast] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading suggestions...")
                    .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
                    ForEach(suggestedPodcasts) { podcast in
                        podcastCell(podcast)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
        }
        .task {
            await loadSuggestions()
        }
    }

    private func podcastCell(_ podcast: Podcast) -> some View {
        let isSelected = selectedIDs.contains(podcast.id)

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                if isSelected {
                    selectedIDs.remove(podcast.id)
                } else {
                    selectedIDs.insert(podcast.id)
                }
            }
            updateFollowed()
        } label: {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(Color(.tertiarySystemFill))
                            .aspectRatio(1, contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: 4)
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .strokeBorder(themeManager.currentTheme.accentColor, lineWidth: 2)
                    }
                }

                Text(podcast.title)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadSuggestions() async {
        isLoading = true
        do {
            suggestedPodcasts = try await PodcastSearchService.shared.topPodcasts(limit: 30)
        } catch {
            suggestedPodcasts = []
        }
        isLoading = false
    }

    private func updateFollowed() {
        let followed = suggestedPodcasts.filter { selectedIDs.contains($0.id) }.map { podcast in
            var p = podcast
            p.isFollowed = true
            return p
        }
        Podcast.saveFollowedPodcasts(followed)
    }
}
