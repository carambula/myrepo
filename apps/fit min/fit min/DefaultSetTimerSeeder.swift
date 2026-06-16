import Foundation
import SwiftData

enum DefaultSetTimerSeeder {
    private static let didSeedKey = "fitMin.didSeedDefaultTimers"

    static func seedIfNeeded(existingTimers: [SetTimer], modelContext: ModelContext) {
        guard existingTimers.isEmpty else { return }
        guard !UserDefaults.standard.bool(forKey: didSeedKey) else { return }

        let now = Date()
        for (index, preset) in presets.enumerated() {
            let date = now.addingTimeInterval(Double(-index))
            modelContext.insert(
                SetTimer(
                    createdAt: date,
                    updatedAt: date,
                    customTitle: preset.title,
                    configuration: preset.configuration,
                    customSegments: preset.segments
                )
            )
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    static let presets: [DefaultSetTimerPreset] = [
        .fixed(title: "Tabata Sprint", reps: 4, work: 20, rest: 10),
        .fixed(title: "Classic HIIT", reps: 4, work: 30, rest: 30),
        .fixed(title: "Muscle Burner", reps: 4, work: 45, rest: 15),

        .ladder(title: "Cardio Build", work: [30, 45, 60], rest: [15, 15]),
        .ladder(title: "Endurance Climb", work: [45, 60, 75, 90], rest: [15, 15, 15]),
        .ladder(title: "Proportional Climb", work: [30, 60, 90], rest: [15, 30]),

        .custom(title: "Power Drop", work: [60, 45, 30], rest: [30, 30]),
        .custom(title: "Fatigue Crusher", work: [90, 60, 30], rest: [30, 20]),
        .custom(title: "Speed Finish", work: [45, 30, 15], rest: [15, 15]),

        .pyramid(title: "Classic Peak", work: [30, 45, 60, 45, 30], rest: [15, 15, 15, 15]),
        .pyramid(title: "Short Blitz", work: [20, 40, 20], rest: [10, 20]),
        .pyramid(title: "Heavy Endurance", work: [45, 60, 75, 60, 45], rest: [15, 15, 15, 15]),

        .wave(title: "Heart Rate Shock", work: [30, 60, 30, 60], rest: [15, 30, 15]),
        .wave(title: "Sprint Waves", work: [15, 30, 15, 30], rest: [45, 30, 45]),
        .wave(title: "High-Low Wave", work: [45, 15, 45, 15], rest: [15, 15, 15]),
    ]
}

struct DefaultSetTimerPreset {
    let title: String
    let configuration: SetTimerConfiguration
    let segments: [IntervalSegment]?

    static func fixed(title: String, reps: Int, work: Int, rest: Int) -> DefaultSetTimerPreset {
        DefaultSetTimerPreset(
            title: title,
            configuration: SetTimerConfiguration(
                intervalType: .fixed,
                restType: .fixed,
                reps: reps,
                workSeconds: work,
                restSeconds: rest
            ),
            segments: nil
        )
    }

    static func ladder(title: String, work: [Int], rest: [Int]) -> DefaultSetTimerPreset {
        let step = max(1, (work.dropFirst().first ?? work.first ?? 1) - (work.first ?? 1))
        return DefaultSetTimerPreset(
            title: title,
            configuration: SetTimerConfiguration(
                intervalType: .ladder,
                restType: Set(rest).count == 1 ? .fixed : .proportional,
                reps: work.count,
                workSeconds: work.first ?? 1,
                restSeconds: rest.first ?? 1,
                workStepSeconds: step,
                proportionalRestPercent: 50
            ),
            segments: segments(work: work, rest: rest)
        )
    }

    static func pyramid(title: String, work: [Int], rest: [Int]) -> DefaultSetTimerPreset {
        DefaultSetTimerPreset(
            title: title,
            configuration: SetTimerConfiguration(
                intervalType: .pyramid,
                restType: Set(rest).count == 1 ? .fixed : .proportional,
                reps: work.count,
                workSeconds: work.first ?? 1,
                restSeconds: rest.first ?? 1,
                workStepSeconds: abs((work.dropFirst().first ?? work.first ?? 1) - (work.first ?? 1)),
                proportionalRestPercent: 50
            ),
            segments: segments(work: work, rest: rest)
        )
    }

    static func wave(title: String, work: [Int], rest: [Int]) -> DefaultSetTimerPreset {
        DefaultSetTimerPreset(
            title: title,
            configuration: SetTimerConfiguration(
                intervalType: .wave,
                restType: Set(rest).count == 1 ? .fixed : .proportional,
                reps: work.count,
                workSeconds: work.first ?? 1,
                alternateWorkSeconds: work.dropFirst().first ?? work.first ?? 1,
                restSeconds: rest.first ?? 1,
                proportionalRestPercent: 50
            ),
            segments: segments(work: work, rest: rest)
        )
    }

    static func custom(title: String, work: [Int], rest: [Int]) -> DefaultSetTimerPreset {
        DefaultSetTimerPreset(
            title: title,
            configuration: SetTimerConfiguration(
                intervalType: .ladder,
                restType: Set(rest).count == 1 ? .fixed : .regressive,
                reps: work.count,
                workSeconds: work.first ?? 1,
                restSeconds: rest.first ?? 1,
                workStepSeconds: abs((work.dropFirst().first ?? work.first ?? 1) - (work.first ?? 1)),
                restStepSeconds: abs((rest.dropFirst().first ?? rest.first ?? 1) - (rest.first ?? 1))
            ),
            segments: segments(work: work, rest: rest)
        )
    }

    private static func segments(work: [Int], rest: [Int]) -> [IntervalSegment] {
        var segments: [IntervalSegment] = []
        for index in work.indices {
            segments.append(IntervalSegment(kind: .work, durationSeconds: work[index], repIndex: index))
            if index < rest.count {
                segments.append(IntervalSegment(kind: .rest, durationSeconds: rest[index], repIndex: index))
            }
        }
        return segments
    }
}
