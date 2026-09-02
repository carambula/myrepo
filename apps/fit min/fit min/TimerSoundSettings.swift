enum TimerSoundSettingsKey {
    static let enabled = "fitMin.timerSoundsEnabled"
    static let volume = "fitMin.timerSoundVolume"
    static let tone = "fitMin.timerSoundTone"
    static let celebrationSound = "fitMin.celebrationSound"
}

enum TimerSoundVolume: String, CaseIterable, Identifiable {
    case quiet
    case standard
    case loud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet:
            return "Quiet"
        case .standard:
            return "Standard"
        case .loud:
            return "Loud"
        }
    }

    var multiplier: Float {
        switch self {
        case .quiet:
            return 0.22
        case .standard:
            return 0.65
        case .loud:
            return 1.0
        }
    }
}

enum TimerSoundTone: String, CaseIterable, Identifiable {
    case deep
    case balanced
    case bright
    case clicks
    case ticks
    case tickTock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deep:
            return "Deep"
        case .balanced:
            return "Balanced"
        case .bright:
            return "Bright"
        case .clicks:
            return "Clicks"
        case .ticks:
            return "Ticks"
        case .tickTock:
            return "Tick Tock"
        }
    }

    var tickFrequency: Double {
        switch self {
        case .deep:
            return 380
        case .balanced:
            return 520
        case .bright:
            return 700
        case .clicks:
            return 2_200
        case .ticks:
            return 1_100
        case .tickTock:
            return 760
        }
    }

    var tockFrequency: Double {
        switch self {
        case .deep:
            return 300
        case .balanced:
            return 420
        case .bright:
            return 560
        case .clicks:
            return 1_600
        case .ticks:
            return 850
        case .tickTock:
            return 460
        }
    }

    var boopFrequency: Double {
        switch self {
        case .deep:
            return 1_040
        case .balanced:
            return 1_400
        case .bright:
            return 1_800
        case .clicks:
            return 3_200
        case .ticks:
            return 2_100
        case .tickTock:
            return 1_550
        }
    }

    var waveform: TimerSoundWaveform {
        switch self {
        case .deep, .balanced, .bright:
            return .sine
        case .clicks:
            return .click
        case .ticks:
            return .tick
        case .tickTock:
            return .wood
        }
    }
}

enum TimerSoundWaveform {
    case sine
    case click
    case tick
    case wood
}

enum TimerCelebrationSound: String, CaseIterable, Identifiable {
    case threeBeeps
    case jubilee
    case coin
    case fanfare
    case sparkle
    case bells

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeBeeps:
            return "Three Beeps"
        case .jubilee:
            return "Jubilee"
        case .coin:
            return "Coin"
        case .fanfare:
            return "Fanfare"
        case .sparkle:
            return "Sparkle"
        case .bells:
            return "Bells"
        }
    }

    var notes: [TimerCelebrationNote] {
        switch self {
        case .threeBeeps:
            return [
                TimerCelebrationNote(frequency: 520, duration: 0.055, delayAfter: 0.055, waveform: .sine),
                TimerCelebrationNote(frequency: 520, duration: 0.055, delayAfter: 0.055, waveform: .sine),
                TimerCelebrationNote(frequency: 520, duration: 0.055, delayAfter: 0, waveform: .sine),
            ]
        case .jubilee:
            return [
                TimerCelebrationNote(frequency: 784, duration: 0.075, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 988, duration: 0.075, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 1_175, duration: 0.075, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 1_568, duration: 0.14, delayAfter: 0, waveform: .sine),
            ]
        case .coin:
            return [
                TimerCelebrationNote(frequency: 988, duration: 0.055, delayAfter: 0.025, waveform: .tick),
                TimerCelebrationNote(frequency: 1_318, duration: 0.14, delayAfter: 0, waveform: .sine),
            ]
        case .fanfare:
            return [
                TimerCelebrationNote(frequency: 523, duration: 0.08, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 659, duration: 0.08, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 784, duration: 0.08, delayAfter: 0.035, waveform: .sine),
                TimerCelebrationNote(frequency: 1_047, duration: 0.18, delayAfter: 0, waveform: .sine),
            ]
        case .sparkle:
            return [
                TimerCelebrationNote(frequency: 1_400, duration: 0.035, delayAfter: 0.025, waveform: .click),
                TimerCelebrationNote(frequency: 1_760, duration: 0.035, delayAfter: 0.025, waveform: .click),
                TimerCelebrationNote(frequency: 2_100, duration: 0.04, delayAfter: 0.025, waveform: .click),
                TimerCelebrationNote(frequency: 2_600, duration: 0.08, delayAfter: 0, waveform: .sine),
            ]
        case .bells:
            return [
                TimerCelebrationNote(frequency: 660, duration: 0.16, delayAfter: 0.02, waveform: .wood),
                TimerCelebrationNote(frequency: 880, duration: 0.18, delayAfter: 0.02, waveform: .wood),
                TimerCelebrationNote(frequency: 1_320, duration: 0.22, delayAfter: 0, waveform: .sine),
            ]
        }
    }
}

struct TimerCelebrationNote {
    let frequency: Double
    let duration: Double
    let delayAfter: Double
    let waveform: TimerSoundWaveform
}

enum TimerCelebrationAnimation: String, CaseIterable, Identifiable {
    case clockWave
    case dancingLines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clockWave:
            return "Clock Wave"
        case .dancingLines:
            return "Dancing Lines"
        }
    }
}
