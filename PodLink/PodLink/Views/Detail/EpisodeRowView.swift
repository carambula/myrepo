import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    let podcast: Podcast
    let onPlay: () -> Void
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Episode artwork or podcast artwork
                AsyncCachedImage(url: episode.artworkURL ?? podcast.displayArtworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .fill(Color(.tertiarySystemFill))
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(episode.title)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(episode.isPlayed ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(episode.publishDate, style: .date)
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        if episode.duration > 0 {
                            Text("·")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(episode.formattedDuration)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        if episode.hasVideo {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }
                    }

                    // Progress bar
                    if episode.isInProgress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(height: 3)

                                Capsule()
                                    .fill(themeManager.currentTheme.accentColor)
                                    .frame(width: geo.size.width * episode.progressPercent, height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }

                Spacer()

                // Play button
                Button(action: onPlay) {
                    Image(systemName: episode.isInProgress ? "play.circle.fill" : "play.circle")
                        .font(.system(size: 28))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}
