import SwiftUI

struct SearchResultsView: View {
    let results: [Podcast]

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { podcast in
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
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))

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
                                Text(podcast.categories.joined(separator: " · "))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)

                    Divider()
                        .padding(.leading, 92)
                }
            }
        }
    }
}
