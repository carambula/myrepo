import SwiftUI

struct QueueView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = playbackService.state.currentEpisode {
                    Section("Now Playing") {
                        Label(current.title, systemImage: "waveform")
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                }

                Section("Up Next") {
                    if playbackService.state.queue.isEmpty {
                        Text("Queue is empty")
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else {
                        ForEach(playbackService.state.queue) { episode in
                            HStack {
                                Text(episode.title)
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .lineLimit(2)
                                Spacer()
                                Text(episode.formattedDuration)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .onDelete { indices in
                            for index in indices {
                                let episode = playbackService.state.queue[index]
                                playbackService.removeFromQueue(episode)
                            }
                        }
                        .onMove { source, destination in
                            playbackService.state.queue.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !playbackService.state.queue.isEmpty {
                        Button("Clear") {
                            playbackService.clearQueue()
                        }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
        }
    }
}
