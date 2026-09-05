import SwiftUI

struct OfflineView: View {
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DownloadRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Downloaded Episodes",
                        systemImage: "arrow.down.circle",
                        description: Text("Download episodes to listen without a connection.")
                    )
                } else {
                    List {
                        Section {
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
                        } header: {
                            Text(storageHeader)
                        }
                        .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
                    }
                    .podLinkSettingsListSurface()
                }
            }
            .navigationTitle("Offline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                            .viewControlIconStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
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
        }
        .onAppear(perform: refreshRecords)
        .onReceive(NotificationCenter.default.publisher(for: .downloadedEpisodesDidChange)) { _ in
            refreshRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { note in
            refreshRecordEpisode(id: note.object as? String)
        }
        .bottomSheetPullToDismiss()
    }

    private var storageHeader: String {
        let count = records.count
        let bytes = downloadManager.totalStorageBytes()
        return "\(count) episodes   \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
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
