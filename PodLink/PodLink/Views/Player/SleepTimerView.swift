import SwiftUI

struct SleepTimerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(\.dismiss) private var dismiss

    let durations = [5, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            List {
                if let remaining = playbackService.state.sleepTimerRemainingMinutes {
                    Section {
                        HStack {
                            Label("Timer Active", systemImage: "moon.zzz.fill")
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Spacer()
                            Text("\(remaining) min remaining")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Button("Cancel Timer", role: .destructive) {
                            playbackService.cancelSleepTimer()
                            dismiss()
                        }
                    }
                }

                Section("Set Timer") {
                    ForEach(durations, id: \.self) { minutes in
                        Button {
                            playbackService.setSleepTimer(minutes: minutes)
                            dismiss()
                        } label: {
                            HStack {
                                Text(formatDuration(minutes))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "moon")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours) hour\(hours > 1 ? "s" : "")"
        }
        return "\(minutes) minutes"
    }
}
