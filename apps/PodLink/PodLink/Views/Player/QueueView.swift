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
                            let ep = EpisodePlaybackStore.merge(episode)
                            HStack(alignment: .center) {
                                Text(ep.title)
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .foregroundColor(ep.isEffectivelyFinished ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                                    .lineLimit(2)
                                Spacer()
                                if ep.duration > 0 {
                                    HStack(spacing: 4) {
                                        if ep.isInProgress {
                                            Capsule()
                                                .fill(Color(.tertiarySystemFill))
                                                .frame(width: 24, height: 2)
                                                .overlay(alignment: .leading) {
                                                    Capsule()
                                                        .fill(themeManager.currentTheme.accentColor)
                                                        .frame(width: max(2, 24 * ep.listProgressVisualFraction), height: 2)
                                                }
                                        }
                                        Text(ep.formattedDuration)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
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
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !playbackService.state.queue.isEmpty {
                        Button {
                            playbackService.clearQueue()
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.liquidGlassCompact)
                        .foregroundStyle(themeManager.currentTheme.accentColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
}
