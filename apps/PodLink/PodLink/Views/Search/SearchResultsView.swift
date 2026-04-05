import SwiftUI

struct SearchResultsView: View {
    let results: [Podcast]
    let followedIds: Set<String>
    let onSelectPodcast: (Podcast) -> Void
    let onToggleFollow: (Podcast) -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        LazyVStack(spacing: 0) {
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
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .fill(Color(.tertiarySystemFill))
                                        .overlay {
                                            Image(systemName: "mic.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))

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
                            Image(systemName: followedIds.contains(podcast.id) ? "minus.circle" : "plus.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    followedIds.contains(podcast.id)
                                        ? themeManager.currentTheme.accentColor
                                        : DesignSystem.Colors.textPrimary
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            followedIds.contains(podcast.id) ? "Remove podcast from library" : "Add podcast to library"
                        )
                    }
                    .padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.trailing, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.md)

                    Divider()
                        .padding(.leading, 92)
                }
        }
    }
}
