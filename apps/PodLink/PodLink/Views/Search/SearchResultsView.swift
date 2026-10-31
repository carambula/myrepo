import SwiftUI

struct SearchResultsView: View {
    let results: [Podcast]
    let followedPodcasts: [Podcast]
    let onSelectPodcast: (Podcast) -> Void
    let onToggleFollow: (Podcast) -> Void

    private func isFollowed(_ podcast: Podcast) -> Bool {
        followedPodcasts.contains { Podcast.isSameFollowedShow($0, podcast) }
    }

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        LazyVStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(results) { podcast in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button {
                            onSelectPodcast(podcast)
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                                        .fill(Color(.tertiarySystemFill))
                                        .overlay {
                                            Image(systemName: "mic.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))

                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(podcast.title)
                                        .font(DesignSystem.Typography.headlineSmall())
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)

                                    Text(podcast.author)
                                        .font(DesignSystem.Typography.bodySmall())
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .lineLimit(1)

                                    if !podcast.categories.isEmpty {
                                        Text(podcast.categories.joined(separator: "   "))
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(themeManager.currentTheme.accentColor)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 0)

                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            onToggleFollow(podcast)
                        } label: {
                            Image(systemName: isFollowed(podcast) ? "minus.circle" : "plus.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    isFollowed(podcast)
                                        ? themeManager.currentTheme.accentColor
                                        : DesignSystem.Colors.textPrimary
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            isFollowed(podcast) ? "Remove podcast from library" : "Add podcast to library"
                        )
                    }
                    .padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.trailing, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
        }
    }
}
