import SwiftUI

struct DownloadedEpisodesView: View {
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DownloadRecord] = []

    var body: some View {
        List {
            if records.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Downloads Yet",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloaded episodes appear here.")
                    )
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            } else {
                Section(storageHeader) {
                    ForEach(records) { record in
                        row(for: record)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    downloadManager.deleteDownload(for: record.episodeID)
                                    refreshRecords()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            }
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Downloaded Episodes")
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
            if !records.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        downloadManager.clearAllDownloads()
                        refreshRecords()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
        .onAppear(perform: refreshRecords)
        .onReceive(NotificationCenter.default.publisher(for: .downloadedEpisodesDidChange)) { _ in
            refreshRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { note in
            refreshRecordEpisode(id: note.object as? String)
        }
    }

    private var storageHeader: String {
        let bytes = downloadManager.totalStorageBytes()
        return "\(records.count) episodes   \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }

    @ViewBuilder
    private func row(for record: DownloadRecord) -> some View {
        let resolvedPodcast = resolvePodcast(for: record)
        EpisodeRowView(
            episode: record.episode,
            podcast: resolvedPodcast,
            onTap: {
                Task { await playbackService.play(episode: record.episode, podcast: resolvedPodcast) }
            },
            onShowDetails: nil
        )
    }

    private func resolvePodcast(for record: DownloadRecord) -> Podcast {
        if let podcast = record.podcast {
            return podcast
        }
        if let followed = Podcast.loadFollowedPodcasts().first(where: {
            $0.id == record.episode.podcastID || $0.feedURL.absoluteString == record.episode.podcastID
        }) {
            return followed
        }
        let feedURL = URL(string: record.episode.podcastID) ?? URL(fileURLWithPath: "/")
        return Podcast(title: "Podcast", author: "", feedURL: feedURL)
    }

    private func refreshRecords() {
        records = downloadManager.downloadedRecords()
    }

    private func refreshRecordEpisode(id: String?) {
        guard let id,
              let idx = records.firstIndex(where: { $0.episodeID == id }) else { return }
        records[idx].episode = EpisodePlaybackStore.merge(records[idx].episode)
    }
}
