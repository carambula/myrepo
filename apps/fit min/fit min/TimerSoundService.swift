import AVFoundation
import Foundation

final class TimerSoundService {
    static let shared = TimerSoundService()

    private var tickPlayer: AVAudioPlayer?
    private var tockPlayer: AVAudioPlayer?
    private var boopPlayer: AVAudioPlayer?
    private let backgroundPlayer: AVAudioPlayer?
    private var loadedTone: TimerSoundTone?
    private var celebrationPlayers: [AVAudioPlayer] = []
    private var tickCount = 0

    private init() {
        Self.configureAudioSession()
        backgroundPlayer = Self.makeBackgroundPlayer()
        reloadPlayersIfNeeded()
    }

    func prewarm() {
        Self.configureAudioSession()
        reloadPlayersIfNeeded()
        tickPlayer?.prepareToPlay()
        tockPlayer?.prepareToPlay()
        boopPlayer?.prepareToPlay()
        backgroundPlayer?.prepareToPlay()
    }

    func beginTimerPlayback() {
        guard Self.soundsEnabled else { return }
        Self.configureAudioSession()
        tickCount = 0
        guard let backgroundPlayer, !backgroundPlayer.isPlaying else { return }
        backgroundPlayer.currentTime = 0
        backgroundPlayer.play()
    }

    func endTimerPlayback() {
        backgroundPlayer?.stop()
        backgroundPlayer?.currentTime = 0
    }

    func play(_ cue: TimerSoundCue) {
        guard Self.soundsEnabled else { return }
        Self.configureAudioSession()
        reloadPlayersIfNeeded()

        let player: AVAudioPlayer?
        let volume = Self.selectedVolume.multiplier
        switch cue {
        case .tick:
            if Self.selectedTone == .tickTock, tickCount.isMultiple(of: 2) == false {
                player = tockPlayer
            } else {
                player = tickPlayer
            }
            tickCount += 1
        case .boop:
            player = boopPlayer
        }
        player?.volume = volume
        player?.currentTime = 0
        player?.play()
    }

    func playCompletion() {
        guard Self.soundsEnabled else { return }
        Self.configureAudioSession()
        let notes = Self.selectedCelebrationSound.notes
        let volume = Self.selectedVolume.multiplier
        Task { [weak self, notes] in
            await MainActor.run {
                self?.celebrationPlayers.removeAll()
            }

            for note in notes {
                await MainActor.run {
                    guard let self,
                          let player = Self.makePlayer(
                            frequency: note.frequency,
                            duration: note.duration,
                            waveform: note.waveform
                          ) else { return }
                    player.volume = volume
                    self.celebrationPlayers.append(player)
                    player.play()
                }
                let delay = note.duration + note.delayAfter
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                self?.celebrationPlayers.removeAll()
            }
        }
    }

    private static var soundsEnabled: Bool {
        let key = TimerSoundSettingsKey.enabled
        return UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    private static var selectedVolume: TimerSoundVolume {
        let rawValue = UserDefaults.standard.string(forKey: TimerSoundSettingsKey.volume) ?? TimerSoundVolume.standard.rawValue
        return TimerSoundVolume(rawValue: rawValue) ?? .standard
    }

    private static var selectedTone: TimerSoundTone {
        let rawValue = UserDefaults.standard.string(forKey: TimerSoundSettingsKey.tone) ?? TimerSoundTone.balanced.rawValue
        return TimerSoundTone(rawValue: rawValue) ?? .balanced
    }

    private static var selectedCelebrationSound: TimerCelebrationSound {
        let rawValue = UserDefaults.standard.string(forKey: TimerSoundSettingsKey.celebrationSound) ?? TimerCelebrationSound.threeBeeps.rawValue
        return TimerCelebrationSound(rawValue: rawValue) ?? .threeBeeps
    }

    private func reloadPlayersIfNeeded() {
        let tone = Self.selectedTone
        guard tone != loadedTone else { return }
        tickPlayer = Self.makePlayer(frequency: tone.tickFrequency, duration: tickDuration(for: tone), waveform: tone.waveform)
        tockPlayer = Self.makePlayer(frequency: tone.tockFrequency, duration: tickDuration(for: tone), waveform: tone.waveform)
        boopPlayer = Self.makePlayer(frequency: tone.boopFrequency, duration: 0.09, waveform: .sine)
        loadedTone = tone
    }

    private func tickDuration(for tone: TimerSoundTone) -> Double {
        switch tone.waveform {
        case .click:
            return 0.018
        case .tick, .wood:
            return 0.055
        case .sine:
            return 0.045
        }
    }

    private static func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Timer sound audio session failed: \(error)")
        }
        #endif
    }

    private static func makePlayer(frequency: Double, duration: Double, waveform: TimerSoundWaveform) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(data: wavData(frequency: frequency, duration: duration, waveform: waveform))
            player.prepareToPlay()
            return player
        } catch {
            print("Timer sound player failed: \(error)")
            return nil
        }
    }

    private static func makeBackgroundPlayer() -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(data: wavData(frequency: 20, duration: 1.0, waveform: .sine))
            player.volume = 0.001
            player.numberOfLoops = -1
            player.prepareToPlay()
            return player
        } catch {
            print("Timer background audio player failed: \(error)")
            return nil
        }
    }

    private static func wavData(frequency: Double, duration: Double, waveform: TimerSoundWaveform) -> Data {
        let sampleRate = 44_100
        let channelCount = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let frameCount = Int(Double(sampleRate) * duration)
        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample
        let dataByteCount = frameCount * blockAlign

        var data = Data()
        data.appendString("RIFF")
        data.appendUInt32(UInt32(36 + dataByteCount))
        data.appendString("WAVE")
        data.appendString("fmt ")
        data.appendUInt32(16)
        data.appendUInt16(1)
        data.appendUInt16(UInt16(channelCount))
        data.appendUInt32(UInt32(sampleRate))
        data.appendUInt32(UInt32(byteRate))
        data.appendUInt16(UInt16(blockAlign))
        data.appendUInt16(UInt16(bitsPerSample))
        data.appendString("data")
        data.appendUInt32(UInt32(dataByteCount))

        for frame in 0..<frameCount {
            let t = Double(frame) / Double(sampleRate)
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let sample = sampleValue(
                frequency: frequency,
                time: t,
                progress: progress,
                frame: frame,
                waveform: waveform
            )
            data.appendInt16(Int16(sample * Double(Int16.max)))
        }

        return data
    }

    private static func sampleValue(
        frequency: Double,
        time: Double,
        progress: Double,
        frame: Int,
        waveform: TimerSoundWaveform
    ) -> Double {
        switch waveform {
        case .sine:
            let envelope = min(1, progress / 0.12) * min(1, (1 - progress) / 0.18)
            return sin(2 * Double.pi * frequency * time) * envelope * 0.9
        case .click:
            let envelope = pow(1 - progress, 7)
            let noiseSeed = sin(Double(frame) * 12.9898) * 43_758.5453
            let noise = (noiseSeed - floor(noiseSeed)) * 2 - 1
            return noise * envelope * 0.95
        case .tick:
            let envelope = pow(1 - progress, 4)
            let carrier = sin(2 * Double.pi * frequency * time)
            let transient = sin(2 * Double.pi * frequency * 2.5 * time)
            return (carrier * 0.55 + transient * 0.45) * envelope * 0.95
        case .wood:
            let envelope = pow(1 - progress, 5)
            let carrier = sin(2 * Double.pi * frequency * time)
            let hollow = sin(2 * Double.pi * frequency * 0.5 * time)
            return (carrier * 0.7 + hollow * 0.3) * envelope * 0.9
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<UInt16>.size))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size))
    }

    mutating func appendInt16(_ value: Int16) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<Int16>.size))
    }
}
