import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SubscriptionsFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var watchStates: [WatchState]
    @AppStorage("filterShorts") private var filterShorts = true
    @Bindable var viewModel: SubscriptionsFeedViewModel
    let theme: AppTheme
    var onVideoSelected: (YTVideo) -> Void
    var onVideoPlaySelected: (YTVideo) -> Void
    var onChannelSelected: (YTChannel) -> Void
    var onConnectGoogle: () -> Void
    var onAddChannel: () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)
    ]
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    @State private var draggedChannelID: String?
    @State private var hiddenSourceChannelID: String?
    @State private var dragSessionNonce = 0
    @State private var settlingChannelID: String?
    @State private var titleTypeInitialY: CGFloat? = nil
    static func compactRelativeTimestamp(from date: Date, now: Date = Date()) -> String {
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(date)))
        let elapsedMinutes = max(1, elapsedSeconds / 60)
        if elapsedMinutes < 60 { return "\(elapsedMinutes)m" }

        let elapsedHours = elapsedMinutes / 60
        if elapsedHours < 24 { return "\(elapsedHours)hr" }

        let elapsedDays = elapsedHours / 24
        if elapsedDays < 7 { return "\(elapsedDays)d" }

        let elapsedWeeks = elapsedDays / 7
        if elapsedWeeks < 5 { return "\(elapsedWeeks)w" }

        let elapsedMonths = elapsedDays / 30
        if elapsedMonths < 12 { return "\(elapsedMonths)mo" }

        let elapsedYears = elapsedDays / 365
        return "\(elapsedYears)y"
    }
    private var channelTitleByID: [String: String] {
        Dictionary(uniqueKeysWithValues: viewModel.channels.map { ($0.channelID, $0.title.decodedHTMLEntities) })
    }
    private var latestVideoByChannelID: [String: YTVideo] {
        viewModel.videos.reduce(into: [:]) { partial, video in
            guard let existing = partial[video.channelID] else {
                partial[video.channelID] = video
                return
            }
            if video.publishedAt > existing.publishedAt {
                partial[video.channelID] = video
            }
        }
    }
    private var watchStateByVideoID: [String: WatchState] {
        Dictionary(uniqueKeysWithValues: watchStates.map { ($0.videoID, $0) })
    }

    private var titleTypeMark: some View {
        Image("Title Type")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(theme.accent)
            .frame(maxWidth: MinSpacing.TitleType.maxWidth,
                   maxHeight: MinSpacing.TitleType.maxHeight,
                   alignment: .leading)
            .compositingGroup()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("feedScroll")).minY
            } action: { newValue in
                if titleTypeInitialY == nil {
                    titleTypeInitialY = newValue
                }
            }
            .visualEffect { content, proxy in
                let scrollY = proxy.frame(in: .named("feedScroll")).minY
                let initial = titleTypeInitialY ?? scrollY
                let drift = initial - scrollY
                let progress = min(max(drift / MinSpacing.TitleType.blurDistance, 0), 1.0)
                return content
                    .offset(y: drift)
                    .blur(radius: progress * MinSpacing.TitleType.maxBlurRadius)
                    .opacity(1.0 - progress * MinSpacing.TitleType.maxOpacityReduction)
            }
            .zIndex(-1)
            .accessibilityHidden(true)
    }

    var body: some View {
        Group {
            if !viewModel.hasCompletedInitialLoad || (viewModel.isLoading && viewModel.channels.isEmpty) {
                ProgressView("Loading latest videos...")
                    .tint(theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.channels.isEmpty {
                ContentUnavailableView(
                    "Couldn’t load subscriptions",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.channels.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    Spacer()

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("No videos yet")
                            .font(DesignSystem.Typography.displayMedium)
                            .foregroundStyle(theme.text)

                        Text("Connect Google, then add subscriptions to see the latest uploads here.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Connect Google Account") {
                            onConnectGoogle()
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .medium))

                        Button("Add Channel Manually") {
                            onAddChannel()
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .medium))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleTypeMark
                            .padding(.horizontal, MinSpacing.TitleType.horizontalPadding)
                            .offset(y: MinSpacing.TitleType.markOffsetY)

                        if let error = viewModel.errorMessage {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .lineLimit(2)
                                Spacer()
                                Button {
                                    viewModel.errorMessage = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.bold))
                                }
                            }
                            .font(DesignSystem.Typography.captionLarge)
                            .foregroundStyle(theme.text)
                            .padding(DesignSystem.Spacing.sm)
                            .background(theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                            .padding(.bottom, DesignSystem.Spacing.sm)
                        }

                        if viewModel.isGrid {
                            LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.lg) {
                                ForEach(viewModel.orderedChannels) { channel in
                                    ChannelTileView(
                                        channel: channel,
                                        isLatestUnwatched: latestVideoByChannelID[channel.channelID].map {
                                            !(watchStateByVideoID[$0.videoID]?.isCompleted ?? false)
                                        } ?? false,
                                        theme: theme,
                                        onOpenDetail: { onChannelSelected(channel) }
                                    )
                                    .opacity(hiddenSourceChannelID == channel.channelID ? 0 : 1)
                                    .scaleEffect(settlingChannelID == channel.channelID ? 1.035 : 1)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: settlingChannelID)
                                    .onDrag {
                                        dragSessionNonce += 1
                                        let currentSession = dragSessionNonce
                                        draggedChannelID = channel.channelID
                                        hiddenSourceChannelID = channel.channelID
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                            guard dragSessionNonce == currentSession else { return }
                                            draggedChannelID = nil
                                            hiddenSourceChannelID = nil
                                        }
                                        return NSItemProvider(object: channel.channelID as NSString)
                                    } preview: {
                                        ChannelTileView(
                                            channel: channel,
                                            isLatestUnwatched: false,
                                            theme: theme,
                                            onOpenDetail: {}
                                        )
                                        .opacity(1)
                                        .scaleEffect(1)
                                        .background(theme.background)
                                        .compositingGroup()
                                    }
                                    .onDrop(of: [.text], delegate: ChannelDropDelegate(
                                        channel: channel,
                                        viewModel: viewModel,
                                        modelContext: modelContext,
                                        draggedChannelID: $draggedChannelID,
                                        hiddenSourceChannelID: $hiddenSourceChannelID,
                                        dragSessionNonce: $dragSessionNonce,
                                        settlingChannelID: $settlingChannelID
                                    ))
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                            .padding(.top, MinSpacing.TitleType.contentTopSpacing)
                            .padding(.bottom, 48)
                            .onDrop(of: [.text], delegate: ChannelGridDropCleanupDelegate(
                                draggedChannelID: $draggedChannelID,
                                hiddenSourceChannelID: $hiddenSourceChannelID,
                                dragSessionNonce: $dragSessionNonce,
                                settlingChannelID: $settlingChannelID
                            ))
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.videos) { video in
                                    VideoRowView(
                                        video: video,
                                        channelTitle: channelTitleByID[video.channelID] ?? "Unknown channel",
                                        theme: theme,
                                        onOpenDetail: { onVideoSelected(video) },
                                        onPlay: { onVideoPlaySelected(video) }
                                    )
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                            .padding(.top, MinSpacing.TitleType.contentTopSpacing)
                            .padding(.bottom, 48)
                        }
                    }
                    .padding(.top, MinSpacing.TitleType.scrollTopPadding)
                }
                .coordinateSpace(name: "feedScroll")
                .refreshable {
                    await viewModel.refresh(modelContext: modelContext)
                }
            }
        }
        .task {
            if viewModel.channels.isEmpty {
                viewModel.loadCachedData(modelContext: modelContext)
            }
            await viewModel.refresh(modelContext: modelContext)
        }
        .onChange(of: filterShorts, initial: true) { _, newValue in
            viewModel.filterShorts = newValue
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let stale = viewModel.lastRefreshedAt.map { Date.now.timeIntervalSince($0) > 300 } ?? true
            guard stale else { return }
            Task {
                await viewModel.refresh(modelContext: modelContext, reloadSubscriptions: false)
            }
        }
    }

}

private struct VideoRowView: View {
    let video: YTVideo
    let channelTitle: String
    let theme: AppTheme
    let onOpenDetail: () -> Void
    let onPlay: () -> Void
    private var publishedText: String {
        SubscriptionsFeedView.compactRelativeTimestamp(from: video.publishedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), initialBlurRadius: 24) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile, style: .continuous)
                            .fill(theme.surface.opacity(0.8))
                    }

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.65))
                        .clipShape(Circle())
                        .padding(6)
                }
                .frame(width: 146, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title.decodedHTMLEntities)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                    Text("\(publishedText)   \(channelTitle)")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpenDetail() }

            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 8)
    }
}

private struct ChannelTileView: View {
    let channel: YTChannel
    let isLatestUnwatched: Bool
    let theme: AppTheme
    let onOpenDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: URL(string: channel.thumbnailURL), initialBlurRadius: 24) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(theme.surface.opacity(0.85))
                }

                if isLatestUnwatched {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 14, height: 14)
                        .padding(7)
                        .accessibilityLabel("Unwatched latest video")
                }
            }
            .contentShape(Rectangle())
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile, style: .continuous))
            .onTapGesture {
                onOpenDetail()
            }
            .accessibilityLabel(channel.title.decodedHTMLEntities)

        }
    }
}

private struct ChannelDropDelegate: DropDelegate {
    let channel: YTChannel
    let viewModel: SubscriptionsFeedViewModel
    let modelContext: ModelContext
    @Binding var draggedChannelID: String?
    @Binding var hiddenSourceChannelID: String?
    @Binding var dragSessionNonce: Int
    @Binding var settlingChannelID: String?

    func performDrop(info: DropInfo) -> Bool {
        let droppedID = draggedChannelID
        dragSessionNonce += 1
        draggedChannelID = nil
        hiddenSourceChannelID = nil
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            settlingChannelID = droppedID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                settlingChannelID = nil
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedChannelID,
              draggedChannelID != channel.channelID,
              let toIndex = viewModel.orderedChannels.firstIndex(where: { $0.channelID == channel.channelID }) else {
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.moveChannel(withID: draggedChannelID, toIndex: toIndex, modelContext: modelContext)
        }
    }
}

private struct ChannelGridDropCleanupDelegate: DropDelegate {
    @Binding var draggedChannelID: String?
    @Binding var hiddenSourceChannelID: String?
    @Binding var dragSessionNonce: Int
    @Binding var settlingChannelID: String?

    func performDrop(info: DropInfo) -> Bool {
        let droppedID = draggedChannelID
        dragSessionNonce += 1
        draggedChannelID = nil
        hiddenSourceChannelID = nil
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            settlingChannelID = droppedID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                settlingChannelID = nil
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

