import SwiftUI
import SwiftData

struct SubscriptionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \YTVideo.publishedAt, order: .reverse) private var videos: [YTVideo]
    @Query(sort: \YTChannel.title, order: .forward) private var channels: [YTChannel]
    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool
    let theme: AppTheme
    let onSelectVideo: (YTVideo) -> Void
    private let searchControlHeight: CGFloat = DesignSystem.Controls.controlHeight

    private var matchedVideos: [YTVideo] {
        guard !query.isEmpty else { return videos }
        return videos.filter { $0.title.decodedHTMLEntities.localizedCaseInsensitiveContains(query) }
    }

    private var matchedChannels: [YTChannel] {
        guard !query.isEmpty else { return channels }
        return channels.filter { $0.title.decodedHTMLEntities.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !matchedChannels.isEmpty {
                    Section("Channels") {
                        ForEach(matchedChannels) { channel in
                            HStack {
                                Image(systemName: "person.crop.square")
                                    .foregroundStyle(theme.accent)
                                Text(channel.title.decodedHTMLEntities)
                                    .foregroundStyle(theme.text)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Videos") {
                    ForEach(matchedVideos) { video in
                        Button {
                            onSelectVideo(video)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title.decodedHTMLEntities)
                                    .foregroundStyle(theme.text)
                                    .lineLimit(2)
                                Text(video.publishedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .yourTubeSettingsSurface(using: theme)
            .tint(theme.accent)
            .safeAreaInset(edge: .bottom) {
                searchBottomControls
            }
            .onChange(of: query) {
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                modelContext.insert(SearchHistoryEntry(query: query))
                try? modelContext.save()
            }
            .onAppear {
                Task { @MainActor in
                    await Task.yield()
                    isSearchFieldFocused = true
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .bottomSheetPullToDismiss()
    }

    private var searchBottomControls: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: DesignSystem.Icon.search)
                    .foregroundStyle(theme.secondaryText)
                TextField("Search subscriptions", text: $query)
                    .font(DesignSystem.Typography.bodyMedium)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .frame(height: searchControlHeight)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.divider.opacity(0.5), lineWidth: 1)
            }

            Button {
                isSearchFieldFocused = false
                dismiss()
            } label: {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: searchControlHeight, height: searchControlHeight)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(theme.divider.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Search")
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.clear)
    }
}
