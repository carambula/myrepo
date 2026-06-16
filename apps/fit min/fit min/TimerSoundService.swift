import AudioToolbox
import Foundation

final class TimerSoundService {
    static let shared = TimerSoundService()

    private init() {}

    func play(_ cue: TimerSoundCue) {
        let key = "fitMin.timerSoundsEnabled"
        guard UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key) else { return }
        switch cue {
        case .tick:
            AudioServicesPlaySystemSound(1104)
        case .boop:
            AudioServicesPlaySystemSound(1057)
        }
    }
}
