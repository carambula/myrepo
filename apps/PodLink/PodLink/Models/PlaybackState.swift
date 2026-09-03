import Foundation
import Observation

@Observable
class PlaybackState {
    var currentEpisode: Episode?
    var currentPodcast: Podcast?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var queue: [Episode] = []
    var isVideoMode: Bool = false
    var isPiPActive: Bool = false
    var sleepTimerEnd: Date?
    var isBuffering: Bool = false

    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedRemainingTime: String {
        "-\(formatTime(remainingTime))"
    }

    var sleepTimerRemainingMinutes: Int? {
        guard let end = sleepTimerEnd else { return nil }
        let remaining = end.timeIntervalSinceNow
        return remaining > 0 ? Int(remaining / 60) + 1 : nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
