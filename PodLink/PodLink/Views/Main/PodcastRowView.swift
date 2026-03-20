import SwiftUI

struct PodcastRowView: View {
    let podcast: Podcast
    let latestEpisode: Episode?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(podcast.title)
                    .font(DesignSystem.Typography.headlineSmall())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Text(podcast.author)
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                if let episode = latestEpisode {
                    Text(episode.title)
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if latestEpisode != nil {
                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
