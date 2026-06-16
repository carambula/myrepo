import Foundation
import SwiftData

enum IntervalType: String, CaseIterable, Identifiable, Codable {
    case fixed
    case ladder
    case pyramid
    case wave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: return "Fixed"
        case .ladder: return "Ladder"
        case .pyramid: return "Pyramid"
        case .wave: return "Wave"
        }
    }
}

enum RestType: String, CaseIterable, Identifiable, Codable {
    case fixed
    case proportional
    case progressive
    case regressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: return "Fixed"
        case .proportional: return "Proportional"
        case .progressive: return "Progressive"
        case .regressive: return "Regressive"
        }
    }

    func isAvailable(for intervalType: IntervalType) -> Bool {
        switch self {
        case .fixed, .proportional:
            return true
        case .progressive, .regressive:
            return intervalType == .ladder
        }
    }
}

enum IntervalSegmentKind: String, Codable {
    case work
    case rest
}

struct IntervalSegment: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: IntervalSegmentKind
    let durationSeconds: Int
    let repIndex: Int

    init(id: UUID = UUID(), kind: IntervalSegmentKind, durationSeconds: Int, repIndex: Int) {
        self.id = id
        self.kind = kind
        self.durationSeconds = max(1, durationSeconds)
        self.repIndex = repIndex
    }
}

struct SetTimerConfiguration: Equatable, Codable {
    var intervalType: IntervalType = .fixed
    var restType: RestType = .fixed
    var reps: Int = 3
    var workSeconds: Int = 45
    var alternateWorkSeconds: Int = 60
    var restSeconds: Int = 15
    var workStepSeconds: Int = 15
    var restStepSeconds: Int = 5
    var proportionalRestPercent: Int = 33

    var normalized: SetTimerConfiguration {
        var copy = self
        copy.reps = min(max(copy.reps, 1), 100)
        copy.workSeconds = max(copy.workSeconds, 1)
        copy.alternateWorkSeconds = max(copy.alternateWorkSeconds, 1)
        copy.restSeconds = max(copy.restSeconds, 1)
        copy.workStepSeconds = max(copy.workStepSeconds, 1)
        copy.restStepSeconds = max(copy.restStepSeconds, 1)
        copy.proportionalRestPercent = min(max(copy.proportionalRestPercent, 1), 300)
        if !copy.restType.isAvailable(for: copy.intervalType) {
            copy.restType = .fixed
        }
        return copy
    }
}

@Model
final class SetTimer {
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var completedCount: Int
    var customTitle: String
    var intervalTypeRawValue: String
    var restTypeRawValue: String
    var reps: Int
    var workSeconds: Int
    var alternateWorkSeconds: Int
    var restSeconds: Int
    var workStepSeconds: Int
    var restStepSeconds: Int
    var proportionalRestPercent: Int
    var customSegmentsData: Data?

    init(
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        completedCount: Int = 0,
        customTitle: String = "",
        configuration: SetTimerConfiguration = SetTimerConfiguration(),
        customSegments: [IntervalSegment]? = nil
    ) {
        let configuration = configuration.normalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.completedCount = completedCount
        self.customTitle = customTitle
        self.intervalTypeRawValue = configuration.intervalType.rawValue
        self.restTypeRawValue = configuration.restType.rawValue
        self.reps = configuration.reps
        self.workSeconds = configuration.workSeconds
        self.alternateWorkSeconds = configuration.alternateWorkSeconds
        self.restSeconds = configuration.restSeconds
        self.workStepSeconds = configuration.workStepSeconds
        self.restStepSeconds = configuration.restStepSeconds
        self.proportionalRestPercent = configuration.proportionalRestPercent
        self.customSegmentsData = customSegments.flatMap { try? JSONEncoder().encode($0) }
    }

    var intervalType: IntervalType {
        get { IntervalType(rawValue: intervalTypeRawValue) ?? .fixed }
        set { intervalTypeRawValue = newValue.rawValue }
    }

    var restType: RestType {
        get { RestType(rawValue: restTypeRawValue) ?? .fixed }
        set { restTypeRawValue = newValue.rawValue }
    }

    var configuration: SetTimerConfiguration {
        get {
            SetTimerConfiguration(
                intervalType: intervalType,
                restType: restType,
                reps: reps,
                workSeconds: workSeconds,
                alternateWorkSeconds: alternateWorkSeconds,
                restSeconds: restSeconds,
                workStepSeconds: workStepSeconds,
                restStepSeconds: restStepSeconds,
                proportionalRestPercent: proportionalRestPercent
            ).normalized
        }
        set {
            let configuration = newValue.normalized
            intervalType = configuration.intervalType
            restType = configuration.restType
            reps = configuration.reps
            workSeconds = configuration.workSeconds
            alternateWorkSeconds = configuration.alternateWorkSeconds
            restSeconds = configuration.restSeconds
            workStepSeconds = configuration.workStepSeconds
            restStepSeconds = configuration.restStepSeconds
            proportionalRestPercent = configuration.proportionalRestPercent
            updatedAt = Date()
        }
    }

    var schedule: [IntervalSegment] {
        if let customSegmentsData,
           let customSegments = try? JSONDecoder().decode([IntervalSegment].self, from: customSegmentsData),
           !customSegments.isEmpty {
            return customSegments
        }
        return SetTimerScheduleBuilder.segments(for: configuration)
    }

    var totalDurationSeconds: Int {
        schedule.reduce(0) { $0 + $1.durationSeconds }
    }

    var displayTitle: String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SetTimerTitleFormatter.title(for: configuration) : trimmed
    }

    var blockStyleLabel: String {
        SetTimerTitleFormatter.blockTitle(for: schedule)
    }

    func markUsed(at date: Date = Date()) {
        lastUsedAt = date
        updatedAt = date
    }

    func markCompleted(at date: Date = Date()) {
        completedCount += 1
        lastUsedAt = date
        updatedAt = date
    }

    func apply(configuration: SetTimerConfiguration, customTitle: String) {
        self.configuration = configuration
        self.customTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        customSegmentsData = nil
        updatedAt = Date()
    }
}

enum SetTimerScheduleBuilder {
    static func segments(for configuration: SetTimerConfiguration) -> [IntervalSegment] {
        let configuration = configuration.normalized
        var segments: [IntervalSegment] = []

        for repIndex in 0..<configuration.reps {
            let workDuration = workDuration(forRepAt: repIndex, configuration: configuration)
            segments.append(IntervalSegment(kind: .work, durationSeconds: workDuration, repIndex: repIndex))

            guard repIndex < configuration.reps - 1 else { continue }
            let restDuration = restDuration(
                afterRepAt: repIndex,
                precedingWorkDuration: workDuration,
                configuration: configuration
            )
            segments.append(IntervalSegment(kind: .rest, durationSeconds: restDuration, repIndex: repIndex))
        }

        return segments
    }

    static func extendedSegments(from segments: [IntervalSegment], configuration: SetTimerConfiguration) -> [IntervalSegment] {
        let workCount = segments.filter { $0.kind == .work }.count
        let restDuration = restDuration(
            afterRepAt: max(workCount - 1, 0),
            precedingWorkDuration: segments.last(where: { $0.kind == .work })?.durationSeconds ?? configuration.workSeconds,
            configuration: configuration
        )
        let nextWork = workDuration(forRepAt: workCount, configuration: configuration)
        return segments
            + [IntervalSegment(kind: .rest, durationSeconds: restDuration, repIndex: max(workCount - 1, 0))]
            + [IntervalSegment(kind: .work, durationSeconds: nextWork, repIndex: workCount)]
    }

    static func totalDuration(for configuration: SetTimerConfiguration) -> Int {
        segments(for: configuration).reduce(0) { $0 + $1.durationSeconds }
    }

    private static func workDuration(forRepAt repIndex: Int, configuration: SetTimerConfiguration) -> Int {
        switch configuration.intervalType {
        case .fixed:
            return configuration.workSeconds
        case .ladder:
            return configuration.workSeconds + repIndex * configuration.workStepSeconds
        case .pyramid:
            let midpoint = max(0, (configuration.reps - 1) / 2)
            let mirroredIndex = min(repIndex, max(0, configuration.reps - 1 - repIndex))
            let stepIndex = min(mirroredIndex, midpoint)
            return configuration.workSeconds + stepIndex * configuration.workStepSeconds
        case .wave:
            return repIndex.isMultiple(of: 2) ? configuration.workSeconds : configuration.alternateWorkSeconds
        }
    }

    private static func restDuration(
        afterRepAt repIndex: Int,
        precedingWorkDuration: Int,
        configuration: SetTimerConfiguration
    ) -> Int {
        switch configuration.restType {
        case .fixed:
            return configuration.restSeconds
        case .proportional:
            return max(1, Int((Double(precedingWorkDuration) * Double(configuration.proportionalRestPercent) / 100).rounded()))
        case .progressive:
            return configuration.intervalType == .ladder
                ? configuration.restSeconds + repIndex * configuration.restStepSeconds
                : configuration.restSeconds
        case .regressive:
            return configuration.intervalType == .ladder
                ? max(1, configuration.restSeconds - repIndex * configuration.restStepSeconds)
                : configuration.restSeconds
        }
    }
}

enum SetTimerTitleFormatter {
    static func blockTitle(for segments: [IntervalSegment]) -> String {
        let workSegments = segments.filter { $0.kind == .work }
        var blocks: [String] = []

        for work in workSegments {
            if let rest = segments.first(where: { $0.kind == .rest && $0.repIndex == work.repIndex }) {
                blocks.append("\(blockDurationToken(work.durationSeconds))/\(blockDurationToken(rest.durationSeconds))")
            } else {
                blocks.append(blockDurationToken(work.durationSeconds))
            }
        }

        return blocks.joined(separator: " → ")
    }

    private static func blockDurationToken(_ seconds: Int) -> String {
        "\(seconds)s"
    }

    static func title(for configuration: SetTimerConfiguration) -> String {
        let configuration = configuration.normalized
        let segments = SetTimerScheduleBuilder.segments(for: configuration)
        let workDurations = segments.filter { $0.kind == .work }.map(\.durationSeconds)
        let restDurations = segments.filter { $0.kind == .rest }.map(\.durationSeconds)

        if Set(workDurations).count == 1, Set(restDurations).count <= 1 {
            let work = durationToken(workDurations.first ?? configuration.workSeconds)
            let rest = durationToken(restDurations.first ?? configuration.restSeconds)
            return "\(configuration.reps) × \(work) / \(rest)"
        }

        var blocks: [String] = []
        for repIndex in 0..<workDurations.count {
            let work = durationToken(workDurations[repIndex])
            if repIndex < restDurations.count {
                blocks.append("\(work) / \(durationToken(restDurations[repIndex]))")
            } else {
                blocks.append(work)
            }
        }
        return blocks.joined(separator: " → ")
    }

    static func durationToken(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainder)s"
    }

    static func clockDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours == 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

struct TimerSecondMark: Identifiable, Equatable {
    let id: Int
    let segmentIndex: Int
    let segmentKind: IntervalSegmentKind
    let repIndex: Int
    let secondInSegment: Int

    static func marks(for segments: [IntervalSegment]) -> [TimerSecondMark] {
        var absoluteSecond = 0
        var marks: [TimerSecondMark] = []
        for (segmentIndex, segment) in segments.enumerated() {
            for second in 0..<segment.durationSeconds {
                marks.append(
                    TimerSecondMark(
                        id: absoluteSecond,
                        segmentIndex: segmentIndex,
                        segmentKind: segment.kind,
                        repIndex: segment.repIndex,
                        secondInSegment: second
                    )
                )
                absoluteSecond += 1
            }
        }
        return marks
    }
}

enum TimerSoundCue: Equatable {
    case tick
    case boop
}

enum TimerSoundCueResolver {
    static func cue(forCompletedElapsedSecond elapsedSecond: Int, segments: [IntervalSegment]) -> TimerSoundCue? {
        guard elapsedSecond > 0 else { return nil }
        let completedSecond = elapsedSecond - 1
        var boundary = 0
        for segment in segments {
            let nextBoundary = boundary + segment.durationSeconds
            if completedSecond < nextBoundary {
                let remainingIncludingCurrent = nextBoundary - completedSecond
                return remainingIncludingCurrent <= 4 ? .boop : .tick
            }
            boundary = nextBoundary
        }
        return nil
    }
}
