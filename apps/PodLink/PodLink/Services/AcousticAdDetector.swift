import Foundation
import AVFoundation
import Accelerate

// MARK: - Phase 3: Acoustic Ad Detection (L3)
//
// Produced DAI ads have measurable acoustic differences from host audio:
// 1. Louder: ads compressed to -16 LUFS, podcasts often -19 to -23
// 2. More compressed: lower dynamic range (RMS variance)
// 3. Silence gaps: 0.3-1.0s of near-silence around insertions (splicing artifact)
//
// Runs on the downloaded file, background thread, never during playback.
// A 1-hour episode analyzes in <2 seconds.

enum AcousticAdDetector {

    /// Analyze an audio file for ad-like acoustic signatures.
    /// - Returns: Segments with `source: .acoustic`, confidence 0.5-0.7
    static func detect(in audioURL: URL) async throws -> [AdSegment] {
        let windows = try await analyzeWindows(in: audioURL)
        var segments: [AdSegment] = []

        // Find loudness jumps: RMS increases >6dB sustained for 15-120s
        segments += findLoudnessJumps(windows: windows)

        // Find over-compressed regions: ads are heavily limited even when
        // loudness-normalized. Sustained low dynamic range without a loudness
        // jump catches level-matched DAI spots.
        segments += findCompressedRegions(windows: windows)

        // Silence gaps are boundary markers, not segments themselves.
        // They're used to refine the loudness-jump boundaries.
        let gaps = findSilenceGaps(windows: windows)
        segments = refineWithSilenceGaps(segments: segments, gaps: gaps)

        return segments
    }

    // MARK: - Window analysis

    private struct AudioWindow {
        let startTime: TimeInterval
        let rmsDB: Double      // 20*log10(rms), -inf to 0
        let peakDB: Double
        let dynamicRange: Double // peakDB - rmsDB, lower = more compressed
    }

    private static func analyzeWindows(in audioURL: URL) async throws -> [AudioWindow] {
        try await Task.detached(priority: .utility) {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let format = audioFile.processingFormat
            let sampleRate = format.sampleRate
            let windowDuration: TimeInterval = 1.0
            let windowFrames = AVAudioFrameCount(sampleRate * windowDuration)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: windowFrames
            ) else {
                throw AcousticError.bufferAllocationFailed
            }

            var windows: [AudioWindow] = []
            var currentTime: TimeInterval = 0

            while audioFile.framePosition < audioFile.length {
                try audioFile.read(into: buffer)
                let frameLength = Int(buffer.frameLength)
                guard frameLength > 0,
                      let channelData = buffer.floatChannelData else { break }

                // Use first channel (mono or left)
                let samples = channelData[0]
                var rms: Float = 0
                vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))

                var peak: Float = 0
                vDSP_maxmgv(samples, 1, &peak, vDSP_Length(frameLength))

                let rmsDB = rms > 0 ? 20 * log10(rms) : -100
                let peakDB = peak > 0 ? 20 * log10(peak) : -100

                windows.append(AudioWindow(
                    startTime: currentTime,
                    rmsDB: Double(rmsDB),
                    peakDB: Double(peakDB),
                    dynamicRange: Double(peakDB - rmsDB)
                ))
                currentTime += windowDuration
            }
            return windows
        }.value
    }

    // MARK: - Loudness jumps

    private static func findLoudnessJumps(windows: [AudioWindow]) -> [AdSegment] {
        guard windows.count > 30 else { return [] }

        // Baseline: median RMS of the whole episode (robust to ads)
        let sortedRMS = windows.map(\.rmsDB).sorted()
        let baseline = sortedRMS[sortedRMS.count / 2]

        var segments: [AdSegment] = []
        var runStart: Int?
        let threshold = baseline + 6.0 // 6dB louder than median

        for (i, w) in windows.enumerated() {
            let isLoud = w.rmsDB > threshold && w.dynamicRange < 12 // loud AND compressed
            if isLoud && runStart == nil {
                runStart = i
            } else if !isLoud, let start = runStart {
                let duration = Double(i - start) // seconds (1s windows)
                if duration >= 15 && duration <= 180 {
                    segments.append(AdSegment(
                        id: "acoustic-\(start)",
                        startTime: windows[start].startTime,
                        endTime: windows[i].startTime,
                        kind: windows[start].startTime < 60 ? .preRoll : .midRoll,
                        confidence: 0.6, source: .acoustic
                    ))
                }
                runStart = nil
            }
        }
        // Trailing run
        if let start = runStart {
            let duration = Double(windows.count - start)
            if duration >= 15 && duration <= 180 {
                segments.append(AdSegment(
                    id: "acoustic-\(start)",
                    startTime: windows[start].startTime,
                    endTime: windows.last!.startTime + 1,
                    kind: .midRoll,
                    confidence: 0.55, source: .acoustic
                ))
            }
        }
        return segments
    }

    // MARK: - Silence gaps

    /// Compression-only detection for loudness-normalized ads (DAI).
    /// Produced spots are heavily limited: sustained dynamic range < 9dB for
    /// 20-120s, even when their RMS matches the show. Lower confidence than
    /// loudness jumps — never auto-skips, only feeds smart skip.
    private static func findCompressedRegions(windows: [AudioWindow]) -> [AdSegment] {
        guard windows.count > 30 else { return [] }

        var segments: [AdSegment] = []
        var runStart: Int?

        for (i, w) in windows.enumerated() {
            // Ignore near-silence (gaps, fades) — not compression
            let isCompressed = w.rmsDB > -40 && w.dynamicRange < 9
            if isCompressed && runStart == nil {
                runStart = i
            } else if !isCompressed, let start = runStart {
                let duration = Double(i - start)
                if duration >= 20 && duration <= 120 {
                    segments.append(AdSegment(
                        id: "acoustic-comp-\(start)",
                        startTime: windows[start].startTime,
                        endTime: windows[i].startTime,
                        kind: windows[start].startTime < 60 ? .preRoll : .midRoll,
                        confidence: 0.5, source: .acoustic
                    ))
                }
                runStart = nil
            }
        }
        // Trailing run
        if let start = runStart {
            let duration = Double(windows.count - start)
            if duration >= 20 && duration <= 120 {
                segments.append(AdSegment(
                    id: "acoustic-comp-\(start)",
                    startTime: windows[start].startTime,
                    endTime: windows.last!.startTime,
                    kind: .midRoll,
                    confidence: 0.5, source: .acoustic
                ))
            }
        }
        return segments
    }

    private static func findSilenceGaps(windows: [AudioWindow]) -> [TimeInterval] {
        windows.filter { $0.rmsDB < -50 }.map(\.startTime)
    }

    private static func refineWithSilenceGaps(
        segments: [AdSegment],
        gaps: [TimeInterval]
    ) -> [AdSegment] {
        // Snap segment boundaries to nearby silence gaps (±2s)
        // This tightens the edges where the splice happened.
        segments.map { segment in
            var s = segment
            if let before = gaps.last(where: { $0 < s.startTime && s.startTime - $0 < 2 }) {
                s = AdSegment(
                    id: s.id, startTime: before, endTime: s.endTime,
                    kind: s.kind, confidence: min(1.0, s.confidence + 0.05), source: s.source
                )
            }
            if let after = gaps.first(where: { $0 > s.endTime && $0 - s.endTime < 2 }) {
                s = AdSegment(
                    id: s.id, startTime: s.startTime, endTime: after,
                    kind: s.kind, confidence: min(1.0, s.confidence + 0.05), source: s.source
                )
            }
            return s
        }
    }
}

enum AcousticError: Error {
    case bufferAllocationFailed
    case fileReadFailed
}
