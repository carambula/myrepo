import AVFAudio
import SwiftUI

enum PlaybackAudioSession {
    private static var installedObservers = false

    static func configureForBackgroundVideo() {
        installObserversIfNeeded()
        activatePlaybackSession()
    }

    static func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .active || phase == .background else { return }
        activatePlaybackSession()
    }

    private static func activatePlaybackSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try audioSession.setActive(true)
        } catch {
            #if DEBUG
            print("PlaybackAudioSession configuration failed: \(error.localizedDescription)")
            #endif
        }
    }

    private static func installObserversIfNeeded() {
        guard !installedObservers else { return }
        installedObservers = true

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType)
            else { return }

            // Re-activate when interruptions end so background playback can resume.
            if interruptionType == .ended {
                activatePlaybackSession()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { _ in
            activatePlaybackSession()
        }
    }
}
