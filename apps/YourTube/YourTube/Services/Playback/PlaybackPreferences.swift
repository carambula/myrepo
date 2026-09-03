import Foundation

enum BackgroundPlaybackBehavior: String, CaseIterable {
    case continuePlaying
    case pausePlayback

    var title: String {
        switch self {
        case .continuePlaying:
            return "Continue playing"
        case .pausePlayback:
            return "Pause playback"
        }
    }
}

enum PlaybackTimeLimit: String, CaseIterable {
    case off
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .fifteenMinutes:
            return "15 minutes"
        case .thirtyMinutes:
            return "30 minutes"
        case .oneHour:
            return "1 hour"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        }
    }
}
