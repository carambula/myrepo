import SwiftUI
import SwiftData

struct ChannelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var videos: [YTVideo]

    let channel: YTChannel
    let theme: AppTheme
    let onVideoSelected: (YTVideo) -> Void
    let onVideoPlaySelected: (YTVideo) -> Void

    init(
        channel: YTChannel,
        theme: AppTheme,
        onVideoSelected: @escaping (YTVideo) -> Void,
        onVideoPlaySelected: @escaping (YTVideo) -> Void
    ) {
        self.channel = channel
        self.theme = theme
        self.onVideoSelected = onVideoSelected
        self.onVideoPlaySelected = onVideoPlaySelected
        let channelID = channel.channelID
        _videos = Query(
            filter: #Predicate<YTVideo> { $0.channelID == channelID },
            sort: [SortDescriptor(\YTVideo.publishedAt, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    channelHero

                    if !channel.summary.isEmpty {
                        Text(channel.summary.decodedHTMLEntities)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(theme.secondaryText)
                    }

                    Text("Videos")
                        .font(DesignSystem.Typography.displayMedium)
                        .foregroundStyle(theme.text)

                    if videos.isEmpty {
                        ContentUnavailableView(
                            "No Videos Yet",
                            systemImage: "play.rectangle",
                            description: Text("Pull to refresh from the main feed to load this channel’s latest uploads.")
                        )
                    } else {
                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(videos) { video in
                                ChannelVideoRowView(
                                    video: video,
                                    theme: theme,
                                    onOpenDetail: { onVideoSelected(video) },
                                    onPlay: { onVideoPlaySelected(video) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .themeBackground(using: theme)
            .navigationTitle(channel.title.decodedHTMLEntities)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                            .viewControlIconStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                }
            }
        }
        .bottomSheetPullToDismiss()
    }

    private var channelHero: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            CachedAsyncImage(url: URL(string: channel.thumbnailURL), initialBlurRadius: 24) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(theme.surface.opacity(0.9))
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(channel.title.decodedHTMLEntities)
                    .font(DesignSystem.Typography.displayMedium)
                    .foregroundStyle(theme.text)
                    .lineLimit(2)

                Text("\(videos.count) videos")
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ChannelVideoRowView: View {
    let video: YTVideo
    let theme: AppTheme
    let onOpenDetail: () -> Void
    let onPlay: () -> Void

    private var publishedText: String {
        SubscriptionsFeedView.relativeDateFormatter.localizedString(for: video.publishedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Button {
                onPlay()
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), initialBlurRadius: 24) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(theme.surface.opacity(0.8))
                    }

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.65))
                        .clipShape(Circle())
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(width: 146, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile, style: .continuous))

            Button {
                onOpenDetail()
            } label: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(video.title.decodedHTMLEntities)
                        .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                    Text(publishedText)
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
    }
}
